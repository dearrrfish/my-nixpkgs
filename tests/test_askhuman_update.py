"""隔离运行真实升级步骤，验证 hash 失败和旧 FOD 缓存不会导致错误提交。"""

import base64
import os
from pathlib import Path
import shlex
import subprocess
import sys
import tempfile
import textwrap
import unittest


WORKFLOW = Path(__file__).resolve().parents[1] / ".github/workflows/update.yml"
HASH = "sha256-" + base64.b64encode(bytes(range(32))).decode()

MOCK_NIX = r"""
import os
from pathlib import Path
import sys

args = sys.argv[1:]
root = Path(os.environ["FIXTURE_ROOT"])
with (root / "nix-calls").open("a") as log:
    log.write(" ".join(args) + "\n")
target = next(arg for arg in args if arg.startswith(".#"))
if args[0] == "eval":
    if target.endswith(".version"):
        print("0.15.1+my-" + "1" * 7, end="")
    elif target.endswith(".src.rev"):
        print("1" * 40, end="")
    else:
        attribute = target.rsplit(".", 1)[-1]
        if attribute == "cargoDeps":
            assert "--apply" in args and "vendorStaging" in args[-1]
            attribute = "cargo-staging"
        print("/nix/store/" + attribute + ".drv", end="")
    sys.exit(0)

package = root / "pkgs/by-name/as/askhuman-my/package.nix"
text = package.read_text()
attribute = target.rsplit(".", 1)[-1]
if attribute == "src" and 'rev = "' + "1" * 40 + '";' in text:
    print(root / "old")
    sys.exit(0)
fake = {
    "src": "fetchLFS = true;\n hash = lib.fakeHash;",
    "pnpmDeps": "fetcherVersion = 3;\n hash = lib.fakeHash;",
    "cargoDeps": "cargoHash = lib.fakeHash;",
}.get(attribute, "")
if fake and fake in text:
    failure = os.environ["FAILURE_MODE"].split(":")
    mode = failure[0]
    failure_target = failure[1] if len(failure) > 1 else "src"
    if attribute == failure_target and mode == "network":
        print("error: network connection failed", file=sys.stderr)
        sys.exit(1)
    value = "" if attribute == failure_target and mode == "empty" else os.environ["EXPECTED_HASH"]
    mismatch_target = "cargo-staging" if attribute == "cargoDeps" else attribute
    print(f"error: hash mismatch in fixed-output derivation '/nix/store/{mismatch_target}.drv':\n"
          "         specified: sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=\n"
          f"            got:    {value}", file=sys.stderr)
    sys.exit(102)
# 旧 hash 的依赖构建总是成功，模拟已存在的 PNPM/Cargo FOD 缓存。
if attribute == "src":
    print(root / "new")
elif attribute not in ("pnpmDeps", "cargoDeps"):
    print(root / "out")
"""


class AskHumanUpgradeTests(unittest.TestCase):
    def run_upgrade(self, mode="mismatch", changed=True):
        workflow = WORKFLOW.read_text()
        block = workflow.split(
            "      - name: Update as/askhuman-my from dearrrfish/AskHuman my-nixpkgs branch\n",
            1,
        )[1].split("      - name: Push changes", 1)[0]
        script = textwrap.dedent(block.split("        run: |\n", 1)[1])
        with tempfile.TemporaryDirectory(prefix="askhuman-upgrade-test-") as directory:
            root = Path(directory)
            package = root / "pkgs/by-name/as/askhuman-my/package.nix"
            package.parent.mkdir(parents=True)
            package.write_text(
                'baseVersion = "0.15.1";\nrev = "' + "1" * 40 + '";\n'
                'fetchLFS = true;\n hash = "old-src";\n'
                'fetcherVersion = 3;\n hash = "old-pnpm";\n'
                'cargoHash = "old-cargo";\n'
            )
            for revision in ("old", "new"):
                source = root / revision
                (source / "src-tauri").mkdir(parents=True)
                value = revision if changed else "same"
                (source / "pnpm-lock.yaml").write_text(value)
                (source / "src-tauri/Cargo.lock").write_text(value)
            (root / "out/bin").mkdir(parents=True)
            cli = root / "out/bin/AskHuman"
            cli.write_text(
                '#!/usr/bin/env bash\nprintf "%s\\n" "$*" >> "$FIXTURE_ROOT/smoke-calls"\n'
            )
            cli.chmod(0o755)
            mock = root / "mock_nix.py"
            mock.write_text(textwrap.dedent(MOCK_NIX))
            setup = (
                "nix() { "
                + shlex.quote(sys.executable)
                + " -I "
                + shlex.quote(str(mock))
                + ' "$@"; }\n'
                'git() { if [[ "$1" == ls-remote ]]; then printf "%s\\n" '
                + shlex.quote("2" * 40 + "\trefs/heads/my-nixpkgs")
                + '; else printf "%s\\n" "$*" >> "$FIXTURE_ROOT/git-calls"; fi; }\n'
                + "curl() { printf '%s' '{\"version\":\"0.16.0\"}'; }\n"
            )
            result = subprocess.run(
                ["bash", "--noprofile", "--norc", "-c", setup + script],
                cwd=root,
                env={
                    **os.environ,
                    "FIXTURE_ROOT": str(root),
                    "FAILURE_MODE": mode,
                    "EXPECTED_HASH": HASH,
                },
                text=True,
                capture_output=True,
            )
            return (
                result,
                package.read_text(),
                {
                    name: (root / name).read_text() if (root / name).exists() else ""
                    for name in ("nix-calls", "git-calls", "smoke-calls")
                },
            )

    def test_expected_mismatches_refresh_all_hashes_before_commit(self):
        result, package, calls = self.run_upgrade()
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(package.count(HASH), 3)
        self.assertNotIn("lib.fakeHash", package)
        self.assertIn("commit", calls["git-calls"])
        self.assertEqual(calls["smoke-calls"].splitlines(), ["--version", "--help"])

    def test_empty_hash_and_network_failure_never_commit(self):
        for mode in (
            "empty:src",
            "network:src",
            "empty:pnpmDeps",
            "network:pnpmDeps",
            "empty:cargoDeps",
            "network:cargoDeps",
        ):
            with self.subTest(mode=mode):
                result, package, calls = self.run_upgrade(mode)
                self.assertNotEqual(result.returncode, 0)
                self.assertIn("without a unique fake-hash mismatch", result.stderr)
                self.assertNotIn('hash = "";', package)
                self.assertEqual(calls["git-calls"], "")
                self.assertEqual(calls["smoke-calls"], "")

    def test_old_cached_dependencies_do_not_mask_changed_lockfiles(self):
        result, package, calls = self.run_upgrade(changed=True)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertNotIn("old-pnpm", package)
        self.assertNotIn("old-cargo", package)
        self.assertIn("/nix/store/pnpmDeps.drv", result.stderr)
        self.assertIn("/nix/store/cargo-staging.drv", result.stderr)

    def test_unchanged_lockfiles_reuse_dependency_hashes(self):
        result, package, calls = self.run_upgrade(changed=False)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("old-pnpm", package)
        self.assertIn("old-cargo", package)
        self.assertNotIn("/nix/store/pnpmDeps.drv", result.stderr)
        self.assertNotIn("/nix/store/cargo-staging.drv", result.stderr)
        self.assertIn("commit", calls["git-calls"])


if __name__ == "__main__":
    unittest.main()
