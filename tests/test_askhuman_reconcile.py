import importlib.util
import json
import os
from pathlib import Path
import stat
import tempfile
import unittest
from unittest.mock import patch

SPEC = importlib.util.spec_from_file_location(
    "askhuman_reconcile",
    Path(__file__).parents[1] / "modules/home-manager/askhuman/reconcile.py",
)
r = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(r)


class Crash(BaseException):
    pass


class ReconcileTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.home = Path(self.tmp.name) / "home"
        self.home.mkdir()
        self.state = self.home / "state"
        self.config = self.home / ".askhuman/config.json"

    def write(self, value, path=None):
        path = path or self.config
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(json.dumps(value))

    def read(self, path=None):
        return json.loads((path or self.config).read_text())

    def apply(self, settings=None, enabled=True, **kwargs):
        return r.reconcile(
            {"enabled": enabled, "settings": settings or {}},
            self.home,
            self.state,
            **kwargs,
        )

    def test_sparse_restore_preserves_unknown_and_credentials(self):
        initial = {
            "general": {"theme": "dark", "unknown": [1, 2]},
            "channels": {"telegram": {"botToken": "CANARY"}},
            "other": 99,
        }
        self.write(initial)
        self.apply(
            {
                "general": {
                    "theme": "light",
                    "popupPrewarm": False,
                    "historyLimit": 0,
                    "language": "",
                }
            }
        )
        changed = self.read()
        self.assertEqual(changed["general"]["historyLimit"], 0)
        self.assertIs(changed["general"]["popupPrewarm"], False)
        self.assertEqual(changed["channels"], initial["channels"])
        self.assertNotIn("CANARY", (self.state / "ledger.json").read_text())
        self.apply(enabled=False)
        self.assertEqual(self.read(), initial)

    def test_retains_original_across_changes_and_releases_external_edits(self):
        self.write({"general": {"theme": "original"}})
        self.apply({"general": {"theme": "dark"}})
        self.apply({"general": {"theme": "light"}})
        self.assertEqual(
            self.read(self.state / "ledger.json")["leaves"][0]["original"]["value"],
            "original",
        )
        self.write({"general": {"theme": "user"}})
        self.apply(enabled=False)
        self.assertEqual(self.read(), {"general": {"theme": "user"}})
        self.assertEqual(self.read(self.state / "ledger.json")["leaves"], [])

    def test_only_created_empty_containers_removed(self):
        self.write({"general": {}})
        self.apply({"general": {"theme": "dark"}, "experimental": {"enabled": True}})
        self.apply(enabled=False)
        self.assertEqual(self.read(), {"general": {}})

    def test_created_container_with_unknown_edit_preserved(self):
        self.apply({"general": {"theme": "dark"}})
        self.write({"general": {"theme": "dark", "unknown": 1}})
        self.apply(enabled=False)
        self.assertEqual(self.read(), {"general": {"unknown": 1}})

    def test_absent_managed_leaf_is_user_edit_on_release(self):
        self.write({"general": {"theme": "original"}})
        self.apply({"general": {"theme": "dark"}})
        self.write({"general": {}})
        self.apply(enabled=False)
        self.assertEqual(self.read(), {"general": {}})

    def test_empty_disabled_and_dryrun_create_nothing(self):
        for enabled in (True, False):
            self.apply(enabled=enabled)
        self.apply({"general": {"theme": "dark"}}, dry_run=True)
        self.assertEqual(list(self.home.iterdir()), [])

    def test_noop_still_records_ownership_and_original(self):
        self.write({"general": {"theme": "dark"}})
        self.apply({"general": {"theme": "dark"}})
        ledger = self.read(self.state / "ledger.json")
        self.assertEqual(
            ledger["leaves"][0]["original"], {"exists": True, "value": "dark"}
        )
        before = {
            p: p.stat().st_mtime_ns for p in (self.config, self.state / "ledger.json")
        }
        self.apply({"general": {"theme": "dark"}})
        self.assertEqual(before, {p: p.stat().st_mtime_ns for p in before})

    def test_legacy_first_use_preserves_legacy(self):
        legacy = self.home / ".humaninloop/config.json"
        initial = {"general": {"theme": "old"}, "unknown": {"x": 1}}
        self.write(initial, legacy)
        self.apply({"general": {"theme": "new"}})
        self.assertEqual(self.read(legacy), initial)
        self.apply(enabled=False)
        self.assertEqual(self.read(), initial)

    def test_permissions_existing_and_new(self):
        self.write({})
        os.chmod(self.config, 0o644)
        self.apply({"general": {"theme": "dark"}})
        for directory in (self.state, self.config.parent):
            self.assertEqual(stat.S_IMODE(directory.stat().st_mode), 0o700)
        for path in (self.config, self.state / "ledger.json", self.state / "lock"):
            self.assertEqual(stat.S_IMODE(path.stat().st_mode), 0o600)

    def test_malformed_nonobject_and_structure_conflict_preserved(self):
        for raw in ("{", "[]", '{"general":4}', '{"general":{"theme":{}}}'):
            with self.subTest(raw=raw):
                self.config.parent.mkdir(exist_ok=True)
                self.config.write_text(raw)
                with self.assertRaises(r.ReconcileError):
                    self.apply({"general": {"theme": "dark"}})
                self.assertEqual(self.config.read_text(), raw)

    def test_reject_symlink_file_and_ancestor(self):
        other = self.home / "other"
        other.mkdir()
        self.config.parent.symlink_to(other, target_is_directory=True)
        with self.assertRaises(r.ReconcileError):
            self.apply({"general": {"theme": "dark"}})
        self.config.parent.unlink()
        self.config.parent.mkdir()
        (other / "config").write_text("{}")
        self.config.symlink_to(other / "config")
        with self.assertRaises(r.ReconcileError):
            self.apply({"general": {"theme": "dark"}})
        self.assertEqual((other / "config").read_text(), "{}")

    def test_invalid_manifest_and_secret_rejected_without_mutation(self):
        for manifest in (
            {"enabled": 1, "settings": {}},
            {"enabled": True, "settings": {"x": None}},
            {
                "enabled": True,
                "settings": {"channels": {"slack": {"botToken": "secret"}}},
            },
        ):
            with self.assertRaises(r.ReconcileError):
                r.reconcile(manifest, self.home, self.state)
        self.assertEqual(list(self.home.iterdir()), [])

    def test_missing_config_with_ledger_fails(self):
        self.apply({"general": {"theme": "dark"}})
        self.config.unlink()
        with self.assertRaises(r.ReconcileError):
            self.apply(enabled=False)
        self.assertFalse(self.config.exists())

    def test_false_zero_are_distinct_for_conditional_restore(self):
        self.write({"general": {"x": "old"}})
        self.apply({"general": {"x": False}})
        self.write({"general": {"x": 0}})
        self.apply(enabled=False)
        self.assertEqual(self.read()["general"]["x"], 0)

    def crash(self, boundary):
        def checkpoint(name):
            if name == boundary:
                raise Crash()

        with patch.object(r, "_checkpoint", checkpoint):
            with self.assertRaises(Crash):
                self.apply({"general": {"theme": "new"}})

    def test_all_durable_boundaries_recover_and_disabled_restores(self):
        for boundary in (
            "pending-durable",
            "config-durable",
            "ledger-durable",
            "pending-unlinked",
            "pending-removal-durable",
        ):
            with self.subTest(boundary=boundary):
                # Separate state per fault, all writes within a disposable fixture.
                self.state = self.home / boundary
                self.write({"general": {"theme": "original"}, "unknown": 1})
                self.crash(boundary)
                current = self.read()
                current["unknown"] = 2
                self.write(current)
                self.apply(enabled=False)
                self.assertEqual(
                    self.read(), {"general": {"theme": "original"}, "unknown": 2}
                )
                self.assertFalse((self.state / "pending.json").exists())
                self.apply(enabled=False)

    def test_pending_missing_or_contradictory_config_keeps_evidence(self):
        self.write({"general": {"theme": "old"}})
        self.crash("pending-durable")
        pending = (self.state / "pending.json").read_bytes()
        self.config.unlink()
        with self.assertRaises(r.ReconcileError):
            self.apply(enabled=False)
        self.assertEqual((self.state / "pending.json").read_bytes(), pending)
        self.write({"general": {"theme": "external"}})
        with self.assertRaises(r.ReconcileError):
            self.apply(enabled=False)
        self.assertEqual((self.state / "pending.json").read_bytes(), pending)
        self.assertEqual(self.read()["general"]["theme"], "external")

    def test_dryrun_preserves_pending_and_every_byte(self):
        self.write({"general": {"theme": "old"}})
        self.crash("pending-durable")
        before = {p: p.read_bytes() for p in self.home.rglob("*") if p.is_file()}
        self.apply(enabled=False, dry_run=True)
        self.assertEqual(
            before, {p: p.read_bytes() for p in self.home.rglob("*") if p.is_file()}
        )

    def test_fsync_order_and_atomic_failure_boundaries(self):
        # Every atomic write fsyncs its file before rename and directory after.
        events = []
        real_fsync, real_replace = os.fsync, os.replace

        def fsync(fd):
            events.append(
                "dirsync" if stat.S_ISDIR(os.fstat(fd).st_mode) else "filesync"
            )
            real_fsync(fd)

        def replace(src, dst):
            events.append("rename:" + Path(dst).name)
            real_replace(src, dst)

        self.write({"general": {"theme": "old"}})
        with patch.object(r.os, "fsync", fsync), patch.object(r.os, "replace", replace):
            self.apply({"general": {"theme": "new"}})
        self.assertEqual(
            events,
            [
                "filesync",
                "rename:pending.json",
                "dirsync",
                "filesync",
                "rename:config.json",
                "dirsync",
                "filesync",
                "rename:ledger.json",
                "dirsync",
                "dirsync",
            ],
        )

    def test_interrupt_each_fsync_and_rename_step(self):
        for operation, count in (("fsync", 7), ("replace", 3)):
            for stop in range(1, count + 1):
                with self.subTest(operation=operation, stop=stop):
                    self.state = self.home / (operation + str(stop))
                    self.write({"general": {"theme": "original"}})
                    original = getattr(r.os, operation)
                    calls = 0

                    def interrupt(*args, **kwargs):
                        nonlocal calls
                        calls += 1
                        if calls == stop:
                            raise Crash()
                        return original(*args, **kwargs)

                    with patch.object(r.os, operation, interrupt):
                        with self.assertRaises(Crash):
                            self.apply({"general": {"theme": "new"}})
                    self.apply(enabled=False)
                    self.assertEqual(self.read(), {"general": {"theme": "original"}})
                    self.assertFalse((self.state / "pending.json").exists())

    def test_continuing_ownership_reasserts_missing_leaf(self):
        self.write({"general": {"theme": "original"}})
        self.apply({"general": {"theme": "new"}})
        self.write({"general": {}})
        self.apply({"general": {"theme": "new"}})
        self.assertEqual(self.read()["general"]["theme"], "new")
        self.apply(enabled=False)
        self.assertEqual(self.read()["general"]["theme"], "original")

    def test_concurrent_unknown_edit_is_detected_then_preserved_on_recovery(self):
        self.write({"general": {"theme": "original"}})

        def modify(name):
            if name == "pending-durable":
                self.write({"general": {"theme": "original"}, "unknown": 42})

        with patch.object(r, "_checkpoint", modify):
            with self.assertRaises(r.ReconcileError):
                self.apply({"general": {"theme": "new"}})
        self.apply(enabled=False)
        self.assertEqual(self.read(), {"general": {"theme": "original"}, "unknown": 42})

    def test_unknown_ledger_version_preserved(self):
        self.write({}, self.state / "ledger.json")
        before = (self.state / "ledger.json").read_bytes()
        with self.assertRaises(r.ReconcileError):
            self.apply(enabled=False)
        self.assertEqual((self.state / "ledger.json").read_bytes(), before)
        self.assertFalse((self.state / "lock").exists())

    def test_shared_lock_api(self):
        with r.module_lock(self.state):
            self.apply({"general": {"theme": "dark"}}, locked=True)
        self.assertEqual(self.read(), {"general": {"theme": "dark"}})


if __name__ == "__main__":
    unittest.main()
