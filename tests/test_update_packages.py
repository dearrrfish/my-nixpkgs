"""Run the package update loop with isolated Git and release API fixtures."""

import json
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import textwrap
import unittest


GITHUB = Path(__file__).resolve().parents[1] / ".github"
WORKFLOW = GITHUB / "workflows/update.yml"
DIGEST = "sha256:" + "ab" * 32


def release(tag, *assets, prerelease=False, draft=False):
    return {
        "tag_name": tag,
        "prerelease": prerelease,
        "draft": draft,
        "assets": [
            {"name": name, "state": "uploaded", "digest": DIGEST} for name in assets
        ],
    }


def desktop_release(version, prefix, *arches, prerelease=False):
    return release(
        f"v{version}",
        *(f"{prefix}-{version}-{arch}.deb" for arch in arches),
        prerelease=prerelease,
    )


class PackageUpdateTests(unittest.TestCase):
    def run_update(
        self,
        package,
        release=None,
        fail=False,
        dirty=False,
        pins=None,
        build_fail=False,
    ):
        workflow = WORKFLOW.read_text()
        block = workflow.split("        id: packages\n", 1)[1]
        block = block.split("        run: |\n", 1)[1].split("      - name:", 1)[0]
        script = textwrap.dedent(block)
        with tempfile.TemporaryDirectory(prefix="update-packages-test-") as directory:
            root = Path(directory)
            package_file = root / "pkgs/by-name" / package / "package.nix"
            package_file.parent.mkdir(parents=True)
            package_file.write_text("original\n")
            if pins:
                package_file = package_file.with_name("release.json")
                package_file.write_text(json.dumps({"version": pins, "hashes": {}}))
            scripts = root / ".github/scripts"
            scripts.mkdir(parents=True)
            shutil.copy(GITHUB / "scripts/select-release.py", scripts)
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
                'if [[ "$1 $2" == "eval --raw" ]]; then echo 0.17.1; exit 0; fi\n'
                'if [[ "$1" == eval ]]; then printf \'["%s"]\' "$TEST_PACKAGE"; exit 0; fi\n'
                'printf "%s\\n" "$*" >> "$PWD/calls"\n'
                'if [[ "$1" == build ]]; then exit "$TEST_BUILD_FAIL"; fi\n'
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
                    "TEST_BUILD_FAIL": str(int(build_fail)),
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
        content, output, _ = self.run_update("ma/magpie", fail=True)
        self.assertEqual(content, "original\n")
        self.assertEqual(output, "failed=1\n")

    def test_dirty_package_is_preserved(self):
        content, output, calls = self.run_update("ma/magpie", dirty=True)
        self.assertEqual(content, "user change\n")
        self.assertEqual(output, "failed=1\n")
        self.assertEqual(calls, "")

    def test_updates_use_locked_toolchain(self):
        _, output, calls = self.run_update("ma/magpie")
        self.assertEqual(output, "failed=0\n")
        self.assertIn("run --inputs-from . nixpkgs#nix-update -- --flake", calls)
        self.assertIn("ma/magpie --commit --build", calls)

    def test_askhuman_uses_numeric_stable_version_with_linux_asset(self):
        def askhuman(version, **flags):
            return release(
                f"v{version}",
                f"AskHuman-x86_64-unknown-linux-gnu-v{version}.tar.gz",
                **flags,
            )

        _, output, calls = self.run_update(
            "as/askhuman",
            release=[
                [
                    release("ios-testflight-21"),
                    askhuman("0.99.0", draft=True),
                    askhuman("0.98.0", prerelease=True),
                    release("v0.97.0"),
                    askhuman("0.17.9"),
                ],
                [askhuman("0.17.10")],
            ],
        )
        self.assertEqual(output, "failed=0\n")
        self.assertIn("--version=0.17.10", calls)
        self.assertIn(".#checks.x86_64-linux.askhuman-activation", calls)

    def test_askhuman_activation_failure_restores_package(self):
        content, output, calls = self.run_update(
            "as/askhuman",
            release=[
                [release("v0.17.3", "AskHuman-x86_64-unknown-linux-gnu-v0.17.3.tar.gz")]
            ],
            build_fail=True,
        )
        self.assertEqual(content, "original\n")
        self.assertEqual(output, "failed=1\n")
        self.assertIn(".#checks.x86_64-linux.askhuman-activation", calls)

    def test_desktop_channels_update_both_architectures(self):
        releases = [
            [
                desktop_release("2.0.25-next", "DSH-NEXT", "amd64"),
                desktop_release("2.0.24-next", "DSH-NEXT", "amd64", "arm64"),
                desktop_release(
                    "2.0.24-beta.1",
                    "DSH-Desktop-Beta",
                    "amd64",
                    "arm64",
                    prerelease=True,
                ),
            ],
            [desktop_release("2.0.18", "DSH-Desktop", "amd64", "arm64")],
        ]
        for suffix, current, expected in [
            ("", "2.0.18", "2.0.18"),
            ("-next", "2.0.23-next", "2.0.24-next"),
            ("-beta", "2.0.23-beta.1", "2.0.24-beta.1"),
        ]:
            with self.subTest(suffix=suffix):
                content, output, calls = self.run_update(
                    "ds/dsh-desktop" + suffix, release=releases, pins=current
                )
                self.assertEqual(output, "failed=0\n")
                if current == expected:
                    self.assertEqual(calls, "")
                else:
                    self.assertIn(".tests.runtime-smoke", calls)
                pins = json.loads(content)
                self.assertEqual(pins["version"], expected)
                self.assertEqual(
                    set(pins["hashes"]),
                    {"amd64", "arm64"} if current != expected else set(),
                )

    def test_desktop_smoke_failure_restores_both_pins(self):
        content, output, calls = self.run_update(
            "ds/dsh-desktop-next",
            release=[[desktop_release("2.0.24-next", "DSH-NEXT", "amd64", "arm64")]],
            pins="2.0.23-next",
            build_fail=True,
        )
        self.assertEqual(json.loads(content), {"version": "2.0.23-next", "hashes": {}})
        self.assertEqual(output, "failed=1\n")
        self.assertIn(".tests.runtime-smoke", calls)

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
