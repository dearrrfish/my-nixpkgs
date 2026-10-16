"""Private runtime boundaries, recovery, ownership and normalization vectors."""

import copy
import importlib.util
import json
import os
from pathlib import Path
import sys
import tempfile
import unittest
from unittest.mock import patch

HELPERS = Path(__file__).resolve().parents[1] / "modules/home-manager/askhuman"
sys.path.insert(0, str(HELPERS))
spec = importlib.util.spec_from_file_location(
    "askhuman_runtime", HELPERS / "runtime.py"
)
runtime = importlib.util.module_from_spec(spec)
spec.loader.exec_module(runtime)


class RuntimeTests(unittest.TestCase):
    def setUp(self):
        self.directory = tempfile.TemporaryDirectory()
        self.addCleanup(self.directory.cleanup)
        self.home = Path(self.directory.name) / "home"
        self.home.mkdir()
        self.state = self.home / "state"
        self.manifest = {
            "enabled": True,
            "settings": {},
            "secretFiles": {},
            "integrations": {},
            "executable": "/package/bin/AskHuman",
        }

    def config(self, value):
        path = self.home / ".askhuman/config.json"
        path.parent.mkdir(exist_ok=True)
        path.write_text(json.dumps(value))
        return path

    def test_empty_and_dry_run_zero_writes_before_secret_open(self):
        runtime.run(self.manifest, self.home, self.state)
        self.assertEqual(list(self.home.iterdir()), [])
        self.manifest["secretFiles"] = {"channels.slack.botToken": "/missing/source"}
        with patch.object(runtime, "source_path", side_effect=AssertionError("opened")):
            runtime.run(self.manifest, self.home, self.state, dry_run=True)
        self.assertEqual(list(self.home.iterdir()), [])

    def test_missing_secret_preserves_config_and_no_lock(self):
        path = self.config({"unknown": True})
        old = path.read_bytes()
        self.manifest["secretFiles"] = {
            "channels.slack.botToken": str(self.home / "missing")
        }
        with self.assertRaises(OSError):
            runtime.run(self.manifest, self.home, self.state)
        self.assertEqual(path.read_bytes(), old)
        self.assertFalse(self.state.exists())

    def test_store_symlink_source_rejected(self):
        source = self.home / "source"
        source.symlink_to("/nix/store")
        with self.assertRaises(runtime.Error):
            runtime.source_path(str(source))

    def test_cli_home_explicit_and_override_removed_stderr_sanitized(self):
        with (
            patch.dict(os.environ, {"ASKHUMAN_HOME": "/wrong", "HOME": "/wrong"}),
            patch.object(runtime.subprocess, "run") as cli,
        ):
            runtime.run_cli("/bin/AskHuman", ["config", "--help"], self.home)
        kwargs = cli.call_args.kwargs
        self.assertNotIn("ASKHUMAN_HOME", kwargs["env"])
        self.assertEqual(kwargs["env"]["HOME"], str(self.home))
        self.assertEqual(kwargs["stderr"], runtime.subprocess.DEVNULL)

    def test_secret_cli_rewrite_and_crash_recovers_original_structure(self):
        original = {
            "unknown": {"keep": 1},
            "general": {"theme": "light"},
            "channels": {"slack": {"appToken": "old-canary"}},
        }
        config = self.config(original)
        token = self.home / "token"
        token.write_text("new-canary")
        self.manifest["settings"] = {"general": {"theme": "dark"}}
        self.manifest["secretFiles"] = {"channels.telegram.botToken": str(token)}
        calls = []

        def cli(executable, args, home):
            calls.append(args)
            # Model upstream full-schema save plus migration of another credential.
            config.write_text(
                json.dumps(
                    {
                        "general": {"theme": "dark", "menuBarIcon": "on"},
                        "channels": {
                            "telegram": {"botToken": "new-canary"},
                            "slack": {"appToken": "keychain:slack"},
                        },
                    }
                )
            )

        def crash(name):
            if name == "secret-cli-complete":
                raise RuntimeError("simulated crash")

        with (
            patch.object(runtime, "run_cli", side_effect=cli),
            patch.object(runtime, "_checkpoint", side_effect=crash),
        ):
            with self.assertRaises(RuntimeError):
                runtime.run(self.manifest, self.home, self.state)
        pending = self.state / "secret-pending.json"
        self.assertTrue(pending.exists())
        self.assertEqual(pending.stat().st_mode & 0o777, 0o600)
        self.assertEqual(self.state.stat().st_mode & 0o777, 0o700)
        disabled = dict(
            self.manifest, enabled=False, settings={}, secretFiles={}, executable=None
        )
        with patch.object(runtime, "run_cli", side_effect=cli):
            runtime.run(disabled, self.home, self.state)
        result = json.loads(config.read_text())
        self.assertEqual(result["general"], {"theme": "light"})
        self.assertEqual(result["unknown"], original["unknown"])
        self.assertEqual(result["channels"]["slack"]["appToken"], "keychain:slack")
        self.assertEqual(result["channels"]["telegram"]["botToken"], "new-canary")
        self.assertFalse(pending.exists())
        self.assertNotIn("canary", (self.state / "ledger.json").read_text())
        self.assertGreaterEqual(len(calls), 2)

    def test_secret_pending_conflict_fails_before_cli_or_ordinary_cleanup(self):
        config = self.config({"general": {"theme": "user-edit"}, "unknown": 1})
        runtime.ordinary._private_dir(self.state)
        token = self.home / "token"
        token.write_text("secret")
        runtime.ordinary.atomic_json(
            self.state / "secret-pending.json",
            {
                "version": 1,
                "home": str(self.home),
                "executable": "/bin/AskHuman",
                "original": {"general": {"theme": "dark"}, "unknown": 1},
                "requests": {"channels.slack.botToken": str(token)},
            },
        )
        before = config.read_bytes()
        with patch.object(
            runtime, "run_cli", side_effect=AssertionError("must not run")
        ):
            with self.assertRaisesRegex(runtime.Error, "changed"):
                runtime.run(self.manifest, self.home, self.state)
        self.assertEqual(config.read_bytes(), before)
        self.assertTrue((self.state / "secret-pending.json").exists())

    def test_pending_ordinary_missing_config_preserves_evidence_before_secrets(self):
        runtime.ordinary._private_dir(self.state)
        runtime.ordinary.atomic_json(
            self.state / "pending.json",
            {
                "version": 1,
                "ledger": {"version": 1, "leaves": [], "containers": []},
                "transitions": [],
                "containers": [],
            },
        )
        with patch.object(
            runtime, "run_cli", side_effect=AssertionError("must not run")
        ):
            with self.assertRaisesRegex(runtime.Error, "missing"):
                runtime.run(self.manifest, self.home, self.state)
        self.assertTrue((self.state / "pending.json").exists())

    def test_upstream_permission_hash_reference_vector(self):
        # Exact upstream agent_permission.rs trusted_hash_includes_status_message_like_codex.
        handler = {
            "command": '"/Users/wutian/.local/bin/AskHuman" __permission-hook codex',
            "timeout": 25 * 60 * 60,
            "statusMessage": "Waiting for AskHuman permission approval",
        }
        self.assertEqual(
            runtime.trusted_hash("PermissionRequest", {}, handler),
            "sha256:7ef2b2088c8e2c086cd1fb9ab238dfdc4f502d5da25e3b54dbab63ab74299d50",
        )

    def test_failed_secret_keeps_snapshot_without_replaying_cli_error(self):
        self.config({"unknown": 2})
        token = self.home / "token"
        token.write_text("canary")
        self.manifest["secretFiles"] = {"channels.slack.botToken": str(token)}
        with patch.object(
            runtime.subprocess,
            "run",
            side_effect=runtime.subprocess.CalledProcessError(
                1, "cli", stderr=b"canary"
            ),
        ):
            with self.assertRaisesRegex(runtime.Error, "partial") as error:
                runtime.run(self.manifest, self.home, self.state)
        self.assertNotIn("canary", str(error.exception))
        self.assertTrue((self.state / "secret-pending.json").exists())

    def test_native_backup_expansion_and_unknown_data(self):
        runtime.ordinary._private_dir(self.state)
        a = self.home / "a.json"
        a.write_bytes(b"private-original")
        runtime.backup_native([a], self.state)
        a.write_bytes(b"user-later")
        absent = self.home / "absent"
        runtime.backup_native([a, absent], self.state)
        saved = json.loads((self.state / "native-backups.json").read_text())["paths"]
        self.assertEqual(
            runtime.base64.b64decode(saved[str(a)]["content"]), b"private-original"
        )
        self.assertFalse(saved[str(absent)]["exists"])

    def test_matrix_rejects_unsupported_modes_and_capabilities(self):
        for agent, policy in (
            ("grok", {"mode": "cli"}),
            ("pi", {"mode": "mcp"}),
            ("cursor", {"mode": "cli", "permission": True}),
        ):
            with self.subTest(agent=agent), self.assertRaises(runtime.Error):
                runtime.run(
                    dict(self.manifest, integrations={agent: policy}),
                    self.home,
                    self.state,
                )
        self.assertFalse(self.state.exists())

    def test_only_executable_token_in_owned_hook_is_rewritten(self):
        command = '"/private/.AskHuman-wrapped" __agent-hook codex activity'
        self.assertEqual(
            runtime.normalize_command(command, "/public/AskHuman"),
            "/public/AskHuman __agent-hook codex activity",
        )
        user = 'echo "user mentions /private/.AskHuman-wrapped __agent-hook"'
        self.assertEqual(runtime.normalize_command(user, "/public/AskHuman"), user)

    def test_hash_vector_and_matcher_status_timeout_preservation(self):
        group = {"matcher": "startup"}
        handler = {
            "type": "command",
            "command": "AskHuman __agent-hook codex start",
            "timeout": 0,
            "statusMessage": "running",
            "async": False,
        }
        import hashlib

        identity = {
            "event_name": "session_start",
            "matcher": "startup",
            "hooks": [
                {
                    "async": False,
                    "command": handler["command"],
                    "statusMessage": "running",
                    "timeout": 1,
                    "type": "command",
                }
            ],
        }
        expected = (
            "sha256:"
            + hashlib.sha256(
                json.dumps(identity, sort_keys=True, separators=(",", ":")).encode()
            ).hexdigest()
        )
        before = copy.deepcopy(handler)
        self.assertEqual(runtime.trusted_hash("SessionStart", group, handler), expected)
        self.assertEqual(handler, before)


if __name__ == "__main__":
    unittest.main()
