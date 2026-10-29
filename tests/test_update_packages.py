"""Run the package update loop with isolated Git and release API fixtures."""

import json
import os
from pathlib import Path
import subprocess
import tempfile
import textwrap
import unittest


WORKFLOW = Path(__file__).resolve().parents[1] / ".github/workflows/update.yml"


class PackageUpdateTests(unittest.TestCase):
    def run_update(self, package, release=None, fail=False, dirty=False):
        workflow = WORKFLOW.read_text()
        block = workflow.split("        id: packages\n", 1)[1]
        block = block.split("        run: |\n", 1)[1].split("      - name:", 1)[0]
        script = textwrap.dedent(block)
        with tempfile.TemporaryDirectory(prefix="update-packages-test-") as directory:
            root = Path(directory)
            package_file = root / "pkgs/by-name" / package / "package.nix"
            package_file.parent.mkdir(parents=True)
            package_file.write_text("original\n")
            for args in [
                ["init", "--quiet"],
                ["config", "user.email", "test@example.invalid"],
                ["config", "user.name", "Test"],
                ["config", "commit.gpgsign", "false"],
                ["config", "core.hooksPath", "/dev/null"],
                ["add", "."],
                ["commit", "--quiet", "-m", "fixture"],
            ]:
                subprocess.run(
                    ["git", *args], cwd=root, check=True, capture_output=True
                )
            if dirty:
                package_file.write_text("user change\n")
            (root / "release.json").write_text(json.dumps(release))
            mock = root / "bin"
            mock.mkdir()
            (mock / "nix").write_text(
                "#!/usr/bin/env bash\n"
                'if [[ "$1" == eval ]]; then printf \'["%s"]\' "$TEST_PACKAGE"; exit 0; fi\n'
                'printf "%s\\n" "$*" >> "$PWD/calls"\n'
                'printf "partial update\\n" > "pkgs/by-name/$TEST_PACKAGE/package.nix"\n'
                'exit "$TEST_FAIL"\n'
            )
            (mock / "gh").write_text('#!/usr/bin/env bash\ncat "$PWD/release.json"\n')
            for executable in mock.iterdir():
                executable.chmod(0o755)
            output = root / "output"
            result = subprocess.run(
                ["bash", "--noprofile", "--norc", "-c", script],
                cwd=root,
                env={
                    **os.environ,
                    "PATH": f"{mock}:{os.environ['PATH']}",
                    "GITHUB_OUTPUT": str(output),
                    "TEST_PACKAGE": package,
                    "TEST_FAIL": str(int(fail)),
                },
                text=True,
                capture_output=True,
            )
            self.assertEqual(result.returncode, 0, result.stderr)
            return (
                package_file.read_text(),
                output.read_text(),
                (root / "calls").read_text() if (root / "calls").exists() else "",
            )

    def test_failed_update_restores_package_and_reports_failure(self):
        content, output, _ = self.run_update("ds/dsh-desktop", fail=True)
        self.assertEqual(content, "original\n")
        self.assertEqual(output, "failed=1\n")

    def test_dirty_package_is_preserved(self):
        content, output, calls = self.run_update("ds/dsh-desktop", dirty=True)
        self.assertEqual(content, "user change\n")
        self.assertEqual(output, "failed=1\n")
        self.assertEqual(calls, "")

    def test_desktop_updates_only_stable_tags(self):
        _, output, calls = self.run_update("ds/dsh-desktop")
        self.assertEqual(output, "failed=0\n")
        self.assertIn(r"--version-regex v([0-9]+\.[0-9]+\.[0-9]+)$", calls)

    def test_incomplete_release_is_deferred(self):
        content, output, calls = self.run_update(
            "cl/cli-proxy-api", release={"tag_name": "v8.0.47", "assets": []}
        )
        self.assertEqual(content, "original\n")
        self.assertEqual(output, "failed=0\n")
        self.assertEqual(calls, "")

    def test_complete_release_pins_selected_version(self):
        _, output, calls = self.run_update(
            "cl/cli-proxy-api",
            release={
                "tag_name": "v8.0.47",
                "assets": [
                    {
                        "name": "CLIProxyAPI_8.0.47_linux_amd64.tar.gz",
                        "state": "uploaded",
                    }
                ],
            },
        )
        self.assertEqual(output, "failed=0\n")
        self.assertIn("--version=8.0.47", calls)


if __name__ == "__main__":
    unittest.main()
