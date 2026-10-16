"""Sparse, recoverable AskHuman ordinary settings management (stdlib only)."""

import argparse
import contextlib
import copy
import fcntl
import json
import math
import os
from pathlib import Path
import stat
import tempfile


class ReconcileError(Exception):
    """A sanitized configuration or transaction error."""


def safe_path(path):
    path = Path(path).absolute()
    for part in reversed((path, *path.parents)):
        try:
            mode = part.lstat().st_mode
        except FileNotFoundError:
            continue
        if stat.S_ISLNK(mode):
            raise ReconcileError("Unsafe symbolic link in managed path")
        if part != path and not stat.S_ISDIR(mode):
            raise ReconcileError("Managed path ancestor is not a directory")
    return path


def _sync_dir(path):
    fd = os.open(str(safe_path(path)), os.O_RDONLY | os.O_DIRECTORY)
    try:
        os.fsync(fd)
    finally:
        os.close(fd)


def _private_dir(path):
    path = safe_path(path)
    path.mkdir(mode=0o700, parents=True, exist_ok=True)
    os.chmod(path, 0o700)
    return path


def atomic_json(path, value, mode=0o600):
    """Replace JSON durably; caller creates the private parent directory."""
    path = safe_path(path)
    if path.exists() and not path.is_file():
        raise ReconcileError("Managed JSON path is not a regular file")
    data = (
        json.dumps(value, ensure_ascii=False, allow_nan=False, indent=2) + "\n"
    ).encode()
    fd, temporary = tempfile.mkstemp(prefix=".askhuman-", dir=path.parent)
    try:
        os.fchmod(fd, mode)
        with os.fdopen(fd, "wb") as stream:
            stream.write(data)
            stream.flush()
            os.fsync(stream.fileno())
        safe_path(path)
        os.replace(temporary, path)
        _sync_dir(path.parent)
    finally:
        if os.path.exists(temporary):
            os.unlink(temporary)


@contextlib.contextmanager
def module_lock(state_dir):
    """Shared activation lock. Only call after the no-work/dry-run guards."""
    state_dir = _private_dir(state_dir)
    path = safe_path(state_dir / "lock")
    fd = os.open(path, os.O_CREAT | os.O_RDWR | os.O_NOFOLLOW, 0o600)
    try:
        if not stat.S_ISREG(os.fstat(fd).st_mode):
            raise ReconcileError("Module lock must be a regular file")
        os.fchmod(fd, 0o600)
        fcntl.flock(fd, fcntl.LOCK_EX)
        yield
    finally:
        os.close(fd)


def _read(path):
    path = safe_path(path)
    try:
        if path.exists() and not path.is_file():
            raise ReconcileError("Managed JSON path is not a regular file")
        raw = path.read_bytes()
    except FileNotFoundError:
        return None, None
    try:
        value = json.loads(
            raw, parse_constant=lambda _: (_ for _ in ()).throw(ValueError())
        )
    except (ValueError, UnicodeError):
        raise ReconcileError(
            "Malformed managed JSON; original file preserved"
        ) from None
    if not isinstance(value, dict):
        raise ReconcileError("Managed JSON must be an object")
    return value, raw


def _leaves(value, path=()):
    result = {}
    for key, item in value.items():
        if not isinstance(key, str) or not key:
            raise ReconcileError("Settings keys must be nonempty strings")
        current = path + (key,)
        if isinstance(item, dict):
            result.update(_leaves(item, current))
        elif item is None or not isinstance(item, (str, bool, int, float, list)):
            raise ReconcileError("Settings require non-null JSON values")
        else:

            def valid(node):
                if node is None:
                    return False
                if isinstance(node, float):
                    return math.isfinite(node)
                if isinstance(node, list):
                    return all(valid(x) for x in node)
                return isinstance(node, (str, bool, int))

            if not valid(item):
                raise ReconcileError("Invalid settings value")
            if current in SECRET_PATHS:
                raise ReconcileError(
                    "Secret settings cannot be managed as ordinary values"
                )
            result[current] = item
    return result


SECRET_PATHS = {
    ("channels", agent, key)
    for agent, key in (
        ("telegram", "botToken"),
        ("dingding", "clientSecret"),
        ("feishu", "appSecret"),
        ("slack", "botToken"),
        ("slack", "appToken"),
    )
}


def _get(config, path):
    node = config
    for key in path[:-1]:
        if key not in node:
            return {"exists": False}
        node = node[key]
        if not isinstance(node, dict):
            raise ReconcileError(
                "Settings container conflicts with existing JSON structure"
            )
    if path[-1] not in node:
        return {"exists": False}
    return {"exists": True, "value": copy.deepcopy(node[path[-1]])}


def _same(a, b):
    # Python considers False == 0; JSON ownership must distinguish them.
    return json.dumps(a, sort_keys=True, allow_nan=False) == json.dumps(
        b, sort_keys=True, allow_nan=False
    )


def _put(config, path, snapshot, created):
    node = config
    for index, key in enumerate(path[:-1]):
        if key not in node:
            if not snapshot["exists"]:
                return
            node[key] = {}
            created.add(path[: index + 1])
        if not isinstance(node[key], dict):
            raise ReconcileError(
                "Settings container conflicts with existing JSON structure"
            )
        node = node[key]
    if snapshot["exists"]:
        node[path[-1]] = copy.deepcopy(snapshot["value"])
    else:
        node.pop(path[-1], None)


def _prune(config, created):
    for path in sorted(created, key=len, reverse=True):
        snapshot = _get(config, path)
        if snapshot == {"exists": True, "value": {}}:
            _put(config, path, {"exists": False}, set())


def _ledger(value):
    if value is None:
        return {"version": 1, "leaves": [], "containers": []}
    try:
        if value["version"] != 1 or not isinstance(value["leaves"], list):
            raise ValueError()
        seen = set()
        for item in value["leaves"]:
            path = tuple(item["path"])
            if (
                not path
                or path in seen
                or not all(isinstance(x, str) and x for x in path)
            ):
                raise ValueError()
            seen.add(path)
            for snapshot in (item["original"], item["last"]):
                if type(snapshot["exists"]) is not bool or (
                    snapshot["exists"] and "value" not in snapshot
                ):
                    raise ValueError()
            if path in SECRET_PATHS:
                raise ValueError()
        for path in value["containers"]:
            if not path or not all(isinstance(x, str) and x for x in path):
                raise ValueError()
    except (KeyError, TypeError, ValueError):
        raise ReconcileError(
            "Invalid or unsupported ownership ledger; preserve state for recovery"
        ) from None
    return value


def _checkpoint(name):
    """Test seam for simulating process interruption at durable boundaries."""


def _remove_pending(path):
    safe_path(path).unlink()
    _checkpoint("pending-unlinked")
    _sync_dir(path.parent)
    _checkpoint("pending-removal-durable")


def _recover(config_path, ledger_path, pending_path):
    pending, _ = _read(pending_path)
    if pending is None:
        return
    try:
        if pending["version"] != 1:
            raise ValueError()
        new_ledger = _ledger(pending["ledger"])
        transitions = pending["transitions"]
        for item in transitions:
            if (
                not item["path"]
                or not isinstance(item["old"]["exists"], bool)
                or not isinstance(item["new"]["exists"], bool)
            ):
                raise ValueError()
    except (KeyError, TypeError, ValueError):
        raise ReconcileError(
            "Invalid pending transaction; recovery evidence preserved"
        ) from None
    config, raw = _read(config_path)
    if config is None:
        raise ReconcileError(
            "Config missing during pending recovery; evidence preserved"
        )
    updated = copy.deepcopy(config)
    created = {tuple(p) for p in pending["containers"]}
    for item in transitions:
        path = tuple(item["path"])
        current = _get(config, path)
        if not (_same(current, item["old"]) or _same(current, item["new"])):
            raise ReconcileError(
                "Managed setting changed during pending recovery; evidence preserved"
            )
        _put(updated, path, item["new"], created)
    _prune(updated, created)
    if _read(config_path)[1] != raw:
        raise ReconcileError("Config changed concurrently; retry activation")
    atomic_json(config_path, updated)
    atomic_json(ledger_path, new_ledger)
    _remove_pending(pending_path)


def reconcile(manifest, home, state_dir, dry_run=False, locked=False):
    """Apply ordinary settings; callers holding module_lock pass locked=True."""
    if (
        not isinstance(manifest, dict)
        or type(manifest.get("enabled")) is not bool
        or not isinstance(manifest.get("settings"), dict)
    ):
        raise ReconcileError("Invalid activation manifest")
    desired = _leaves(manifest["settings"]) if manifest["enabled"] else {}
    state_dir = safe_path(state_dir)
    home = safe_path(home)
    config_path = safe_path(home / ".askhuman" / "config.json")
    legacy_path = safe_path(home / ".humaninloop" / "config.json")
    ledger_path = safe_path(state_dir / "ledger.json")
    pending_path = safe_path(state_dir / "pending.json")
    ledger, _ = _read(ledger_path)
    pending, _ = _read(pending_path)
    if not desired and ledger is None and pending is None:
        return
    # Dry-run validates readable inputs but creates no locks, directories or files.
    config, _ = _read(config_path)
    if config is None:
        config, _ = _read(legacy_path)
    checked_ledger = _ledger(ledger)
    if pending is None:
        for path in set(desired) | {
            tuple(item["path"]) for item in checked_ledger["leaves"]
        }:
            current = _get(config or {}, path)
            if (
                path in desired
                and current["exists"]
                and isinstance(current["value"], dict)
            ):
                raise ReconcileError("Declared leaf conflicts with existing object")
    if dry_run:
        return
    if not locked:
        with module_lock(state_dir):
            return reconcile(manifest, home, state_dir, locked=True)
    _recover(config_path, ledger_path, pending_path)
    ledger = _ledger(_read(ledger_path)[0])
    config, raw = _read(config_path)
    source_path = config_path
    if config is None:
        if ledger["leaves"]:
            raise ReconcileError(
                "Config missing with ownership ledger; original state preserved"
            )
        config, raw = _read(legacy_path)
        source_path = legacy_path
        if config is None:
            config = {}
    updated = copy.deepcopy(config)
    created = {tuple(path) for path in ledger["containers"]}
    old_entries = {tuple(item["path"]): item for item in ledger["leaves"]}
    new_entries = []
    transitions = []
    for path in sorted(set(old_entries) | set(desired)):
        current = _get(config, path)
        old = old_entries.get(path)
        if path in desired:
            if current["exists"] and isinstance(current["value"], dict):
                raise ReconcileError("Declared leaf conflicts with existing object")
            target = {"exists": True, "value": desired[path]}
            original = old["original"] if old else current
            new_entries.append(
                {"path": list(path), "original": original, "last": target}
            )
        else:
            target = old["original"] if _same(current, old["last"]) else current
        _put(updated, path, target, created)
        transitions.append({"path": list(path), "old": current, "new": target})
    _prune(updated, created)
    new_ledger = {
        "version": 1,
        "leaves": new_entries,
        "containers": [
            list(path) for path in sorted(created) if _get(updated, path)["exists"]
        ],
    }
    # Includes ownership-only changes: equal JSON still needs durable snapshots.
    if _same(config, updated) and _same(ledger, new_ledger):
        return
    if _read(source_path)[1] != raw:
        raise ReconcileError("Config changed concurrently; retry activation")
    _private_dir(config_path.parent)
    transaction = {
        "version": 1,
        "ledger": new_ledger,
        "transitions": transitions,
        "containers": [list(path) for path in sorted(created)],
    }
    atomic_json(pending_path, transaction)
    _checkpoint("pending-durable")
    if _read(source_path)[1] != raw or (
        source_path != config_path and config_path.exists()
    ):
        raise ReconcileError("Config changed concurrently; pending evidence preserved")
    atomic_json(config_path, updated)
    _checkpoint("config-durable")
    atomic_json(ledger_path, new_ledger)
    _checkpoint("ledger-durable")
    _remove_pending(pending_path)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--manifest", required=True)
    parser.add_argument("--home", required=True)
    parser.add_argument("--state-dir", required=True)
    parser.add_argument("--dry-run", action="store_true")
    args = parser.parse_args()
    try:
        manifest, _ = _read(args.manifest)
        reconcile(manifest, args.home, args.state_dir, args.dry_run)
    except (ReconcileError, OSError, ValueError):
        parser.exit(
            1,
            "AskHuman settings reconciliation failed; private state retained for recovery.\n",
        )


if __name__ == "__main__":
    main()
