"""Exercise the workflow's hash discovery under Bash errexit and pipefail."""

import base64
from pathlib import Path
import shlex
import subprocess
import tempfile
import textwrap
import unittest


WORKFLOW = Path(__file__).resolve().parents[1] / ".github/workflows/update.yml"
FAKE = "sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA="
HASH = "sha256-" + base64.b64encode(bytes(range(32))).decode()
DRV = "/nix/store/test.drv"


def mismatch(drv=DRV, value=HASH, specified=FAKE):
    return (
        f"error: hash mismatch in fixed-output derivation '{drv}':\n"
        f"         specified: {specified}\n"
        f"            got:    {value}\n"
    )


class HashDiscoveryTests(unittest.TestCase):
    def run_discovery(self, output, status=102, eval_status=0):
        workflow = WORKFLOW.read_text()
        function = textwrap.dedent(
            "          discover_hash() {"
            + workflow.split("          discover_hash() {", 1)[1].split(
                "          SRC_HASH=", 1
            )[0]
        )
        mock = f"""
        nix() {{
          if [[ "$1" == eval ]]; then
            printf '%s' {shlex.quote(DRV)}
            return {eval_status}
          fi
          printf '%s' {shlex.quote(output)} >&2
          return {status}
        }}
        """
        return subprocess.run(
            [
                "bash",
                "--noprofile",
                "--norc",
                "-c",
                "set -euo pipefail\n"
                + mock
                + function
                + '\nvalue=$(discover_hash target)\nprintf "%s" "$value"',
            ],
            text=True,
            capture_output=True,
        )

    def test_expected_mismatch_survives_errexit(self):
        result = self.run_discovery(mismatch())
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(result.stdout, HASH)

    def test_typographic_quotes_from_nix_diagnostics(self):
        output = mismatch().replace(f"'{DRV}'", f"‘{DRV}’")
        result = self.run_discovery(output)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(result.stdout, HASH)

    def test_long_build_log_uses_a_file_descriptor(self):
        workflow = WORKFLOW.read_text()
        function = textwrap.dedent(
            "          discover_hash() {"
            + workflow.split("          discover_hash() {", 1)[1].split(
                "          SRC_HASH=", 1
            )[0]
        )
        mock = (
            'nix() { if [[ "$1" == eval ]]; then printf %s '
            + shlex.quote(DRV)
            + "; else python3 -c \"print('x' * 200000)\" >&2; "
            + "printf %s "
            + shlex.quote(mismatch())
            + " >&2; return 102; fi; }\n"
        )
        result = subprocess.run(
            [
                "bash",
                "--noprofile",
                "--norc",
                "-c",
                "set -euo pipefail\n"
                + mock
                + function
                + '\nvalue=$(discover_hash target)\nprintf "%s" "$value"',
            ],
            text=True,
            capture_output=True,
        )
        self.assertEqual(result.returncode, 0, result.stderr[-1000:])
        self.assertEqual(result.stdout, HASH)

    def test_invalid_failures_never_return_a_hash(self):
        for output, status, eval_status in [
            ("network failed", 1, 0),
            ("", 102, 0),
            (mismatch("/nix/store/dependency.drv"), 102, 0),
            (mismatch() + mismatch(), 102, 0),
            (mismatch(value="sha256-AA=="), 102, 0),
            (mismatch(value=FAKE), 102, 0),
            (mismatch(specified=HASH), 102, 0),
            ("", 0, 0),
            (mismatch(), 0, 0),
            (mismatch(), 102, 1),
        ]:
            with self.subTest(output=output, status=status, eval_status=eval_status):
                result = self.run_discovery(output, status, eval_status)
                self.assertNotEqual(result.returncode, 0)
                self.assertEqual(result.stdout, "")

    def test_lockfile_changes_force_discovery_despite_cached_builds(self):
        workflow = WORKFLOW.read_text()
        block = workflow.split("          # A cached FOD", 1)[1].split(
            "          # Validate the full application", 1
        )[0]
        block = textwrap.dedent("          # A cached FOD" + block)
        for pnpm_changed, cargo_changed in [
            (False, False),
            (True, False),
            (False, True),
            (True, True),
        ]:
            with self.subTest(pnpm=pnpm_changed, cargo=cargo_changed):
                with tempfile.TemporaryDirectory(
                    prefix="update-lockfile-test-"
                ) as directory:
                    root = Path(directory)
                    old, new = root / "old", root / "new"
                    for source in (old, new):
                        (source / "src-tauri").mkdir(parents=True)
                        (source / "pnpm-lock.yaml").write_text("old pnpm")
                        (source / "src-tauri/Cargo.lock").write_text("old cargo")
                    if pnpm_changed:
                        (new / "pnpm-lock.yaml").write_text("new pnpm")
                    if cargo_changed:
                        (new / "src-tauri/Cargo.lock").write_text("new cargo")
                    package = root / "package.nix"
                    package.write_text(
                        'fetcherVersion = 3;\n hash = "old-pnpm";\ncargoHash = "old-cargo";\n'
                    )
                    setup = (
                        "set -euo pipefail\n"
                        f"OLD_SRC={shlex.quote(str(old))}\n"
                        f"NEW_SRC={shlex.quote(str(new))}\n"
                        f"PKG_FILE={shlex.quote(str(package))}\n"
                        # Every build succeeds, simulating an existing old FOD cache.
                        "nix() { return 0; }\n"
                        "discover_hash() { printf '%s\\n' \"$1\" >&2; printf '%s' "
                        + shlex.quote(HASH)
                        + "; }\n"
                    )
                    result = subprocess.run(
                        ["bash", "--noprofile", "--norc", "-c", setup + block],
                        text=True,
                        capture_output=True,
                    )
                    self.assertEqual(result.returncode, 0, result.stderr)
                    self.assertEqual(
                        '"as/askhuman-my".pnpmDeps' in result.stderr, pnpm_changed
                    )
                    self.assertEqual(
                        '"as/askhuman-my".cargoDeps' in result.stderr, cargo_changed
                    )
                    content = package.read_text()
                    self.assertNotIn("lib.fakeHash", content)
                    self.assertEqual("old-pnpm" not in content, pnpm_changed)
                    self.assertEqual("old-cargo" not in content, cargo_changed)

    def test_full_build_and_smoke_failure_prevent_commit(self):
        workflow = WORKFLOW.read_text()
        block = textwrap.dedent(
            "          # Validate the full application"
            + workflow.split("          # Validate the full application", 1)[1].split(
                "      - name: Push changes", 1
            )[0]
        )
        for build_status, smoke_status in [(1, 0), (0, 1), (0, 0)]:
            with self.subTest(build=build_status, smoke=smoke_status):
                with tempfile.TemporaryDirectory(
                    prefix="update-smoke-test-"
                ) as directory:
                    root = Path(directory)
                    (root / "bin").mkdir()
                    cli = root / "bin/AskHuman"
                    cli.write_text("#!/usr/bin/env bash\n" + f"exit {smoke_status}\n")
                    cli.chmod(0o755)
                    marker = root / "git-calls"
                    setup = (
                        "set -euo pipefail\nPKG_FILE=fixture\nOLD_VER=old\nNEW_VER=new\n"
                        + "nix() { printf '%s' "
                        + shlex.quote(str(root))
                        + f"; return {build_status}; }}\n"
                        + "git() { printf '%s\\n' \"$*\" >> "
                        + shlex.quote(str(marker))
                        + "; }\n"
                    )
                    result = subprocess.run(
                        ["bash", "--noprofile", "--norc", "-c", setup + block],
                        text=True,
                        capture_output=True,
                    )
                    success = build_status == smoke_status == 0
                    self.assertEqual(result.returncode == 0, success, result.stderr)
                    self.assertEqual(marker.exists(), success)
                    if success:
                        self.assertIn("commit", marker.read_text())

    def test_all_fetchers_use_hash_discovery(self):
        workflow = WORKFLOW.read_text()
        for variable, attribute in [
            ("SRC_HASH", "src"),
            ("PNPM_HASH", "pnpmDeps"),
            ("CARGO_HASH", "cargoDeps"),
        ]:
            self.assertIn(
                f"{variable}=$(discover_hash '.#packages.x86_64-linux.\"as/askhuman-my\".{attribute}')",
                workflow,
            )


if __name__ == "__main__":
    unittest.main()
