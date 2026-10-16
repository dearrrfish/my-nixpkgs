"""Execute generated activation and the packaged CLI only in disposable fixtures."""

import importlib.util
import json
import os
from pathlib import Path
import subprocess
import tempfile
import unittest


ROOT = Path(__file__).resolve().parents[1]
EXECUTABLE = os.environ.get("ASKHUMAN_EXECUTABLE")
SCRIPT = os.environ.get("ASKHUMAN_ACTIVATION_SCRIPT")


def load_runtime():
    import sys

    helper_dir = str(ROOT / "modules/home-manager/askhuman")
    if helper_dir not in sys.path:
        sys.path.insert(0, helper_dir)
    spec = importlib.util.spec_from_file_location(
        "askhuman_runtime", Path(helper_dir) / "runtime.py"
    )
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def isolated_env(home):
    # No desktop or live credential-service connection is inherited.
    return {
        "HOME": str(home),
        "XDG_CONFIG_HOME": str(home / ".config"),
        "XDG_STATE_HOME": str(home / ".local/state"),
        "XDG_CACHE_HOME": str(home / ".cache"),
        "XDG_RUNTIME_DIR": str(home / "runtime"),
        "CODEX_HOME": str(home / ".codex"),
        "DBUS_SESSION_BUS_ADDRESS": "unix:path=/nonexistent-askhuman-test-bus",
        "PATH": os.environ.get("PATH", "/no-path"),
    }


@unittest.skipUnless(
    SCRIPT, "generated activation is executed by the Nix sandbox check"
)
class GeneratedActivation(unittest.TestCase):
    def test_activation_and_native_dry_run_guards(self):
        home = Path(os.environ["ASKHUMAN_ACTIVATION_HOME"])
        state = Path(os.environ["ASKHUMAN_ACTIVATION_STATE"])
        self.assertEqual(str(home), "/build/askhuman-activation-home")
        self.assertFalse(
            home.exists(), "activation fixture must start in a fresh Nix sandbox"
        )
        env = isolated_env(home)
        for dry in ({"DRY_RUN": "1"}, {"DRY_RUN": ""}, {"DRY_RUN_CMD": "echo"}):
            result = subprocess.run(
                ["bash", SCRIPT], env=env | dry, capture_output=True, text=True
            )
            self.assertEqual(result.returncode, 0, result.stderr)
            self.assertFalse(home.exists(), "dry-run created HOME/config/state")
        result = subprocess.run(
            ["bash", SCRIPT], env=env, capture_output=True, text=True
        )
        self.assertEqual(result.returncode, 0, result.stderr)
        config = home / ".askhuman/config.json"
        self.assertEqual(json.loads(config.read_text())["general"]["theme"], "dark")
        self.assertTrue((state / "ledger.json").is_file())
        first = config.read_bytes()
        repeat = subprocess.run(
            ["bash", SCRIPT], env=env, capture_output=True, text=True
        )
        self.assertEqual(repeat.returncode, 0, repeat.stderr)
        self.assertEqual(config.read_bytes(), first)
        self.assertFalse((home / ".codex").exists())
        self.assertFalse((home / ".claude").exists())
        self.assertEqual(config.stat().st_mode & 0o777, 0o600)
        # The same installed runtime entry point handles a disabled generation.
        runtime = load_runtime()
        manifest = {
            "enabled": False,
            "settings": {},
            "secretFiles": {},
            "integrations": {},
            "executable": None,
        }
        runtime.run(manifest, home, state)
        self.assertNotIn("general", json.loads(config.read_text()))


@unittest.skipUnless(EXECUTABLE, "real-package tests run on x86_64-linux")
class PackagedCLI(unittest.TestCase):
    def test_safe_management_help(self):
        with tempfile.TemporaryDirectory() as directory:
            home = Path(directory)
            for args in (["--help"], ["config", "--help"]):
                result = subprocess.run(
                    [EXECUTABLE, *args], env=isolated_env(home), capture_output=True
                )
                self.assertEqual(result.returncode, 0, result.stderr.decode())
            self.assertFalse((home / ".askhuman").exists())

    def test_real_secret_provisioning_and_restore(self):
        runtime = load_runtime()
        with tempfile.TemporaryDirectory() as directory:
            home = Path(directory)
            app = home / ".askhuman"
            app.mkdir(mode=0o700)
            config = app / "config.json"
            original = {
                "futureField": {"kept": True},
                "general": {"theme": "light"},
                "channels": {"slack": {"appToken": "existing-runtime-fixture"}},
            }
            config.write_text(json.dumps(original))
            token = home / "token"
            canary = "runtime-" + os.urandom(24).hex()
            token.write_text(canary + "\n")
            token.chmod(0o600)
            manifest = {
                "enabled": True,
                "settings": {"general": {"theme": "dark"}},
                "secretFiles": {"channels.telegram.botToken": str(token)},
                "integrations": {},
                "executable": EXECUTABLE,
            }
            from unittest.mock import patch

            with patch.dict(os.environ, isolated_env(home), clear=True):
                runtime.run(manifest, home, home / "state")
                result = json.loads(config.read_text())
                self.assertEqual(result["futureField"], original["futureField"])
                self.assertEqual(result["general"], {"theme": "dark"})
                self.assertEqual(result["channels"]["telegram"]["botToken"], canary)
                self.assertEqual(
                    result["channels"]["slack"]["appToken"], "existing-runtime-fixture"
                )
                self.assertNotIn("permissions", result)
                self.assertNotIn("cursorDesktop", result)
                for file in (home / "state").rglob("*"):
                    if file.is_file():
                        self.assertNotIn(canary.encode(), file.read_bytes(), str(file))
                runtime.run(
                    manifest
                    | {
                        "enabled": False,
                        "settings": {},
                        "secretFiles": {},
                        "executable": None,
                    },
                    home,
                    home / "state",
                )
                self.assertEqual(
                    json.loads(config.read_text())["general"], {"theme": "light"}
                )
                self.assertEqual(
                    json.loads(config.read_text())["channels"]["telegram"]["botToken"],
                    canary,
                )

    def test_real_native_modes_use_public_launcher(self):
        runtime = load_runtime()
        modes = {
            "codex": ("cli", "mcp"),
            "claude": ("cli", "mcp"),
            "cursor": ("cli", "mcp"),
            "grok": ("mcp",),
            "pi": ("cli",),
        }
        from unittest.mock import patch

        for agent, choices in modes.items():
            with self.subTest(agent=agent), tempfile.TemporaryDirectory() as directory:
                home = Path(directory)
                state = home / "state"
                env = isolated_env(home)
                for mode in choices:
                    entry = {"mode": mode, "lifecycle": True, "env": {}}
                    if agent in ("codex", "claude"):
                        entry["permission"] = True
                    if agent != "grok":
                        entry["stop"] = True
                    if agent == "claude":
                        entry["askQuestion"] = False
                    manifest = {
                        "enabled": True,
                        "settings": {},
                        "secretFiles": {},
                        "integrations": {agent: entry},
                        "executable": EXECUTABLE,
                    }
                    with patch.dict(os.environ, env, clear=True):
                        runtime.run(manifest, home, state)
                        runtime.run(manifest, home, state)
                    # No generated private ELF launcher survives in native artifacts.
                    files = [
                        file
                        for file in home.rglob("*")
                        if file.is_file() and state not in file.parents
                    ]
                    for file in files:
                        self.assertNotIn(
                            b".AskHuman-wrapped", file.read_bytes(), str(file)
                        )
                    self.assertTrue(
                        any(EXECUTABLE.encode() in file.read_bytes() for file in files)
                    )
                # Explicit upstream cleanup, in the same disposable home.
                cleanup = subprocess.run(
                    [EXECUTABLE, "agents", "mode", agent, "none"],
                    env=env,
                    capture_output=True,
                )
                self.assertEqual(cleanup.returncode, 0, cleanup.stderr.decode())


if __name__ == "__main__":
    unittest.main()
