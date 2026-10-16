"""Private activation adapter for AskHuman v0.14.4 (never starts its daemon)."""

import argparse
import base64
import copy
import hashlib
import json
import os
from pathlib import Path
import re
import shlex
import stat
import subprocess
import tempfile

import reconcile as ordinary

Error = ordinary.ReconcileError
MATRIX = {
    "codex": ({"cli", "mcp"}, {"permission", "stop", "lifecycle"}),
    "claude": ({"cli", "mcp"}, {"permission", "stop", "lifecycle", "askQuestion"}),
    "cursor": ({"cli", "mcp"}, {"stop", "lifecycle"}),
    "grok": ({"mcp"}, {"lifecycle"}),
    "pi": ({"cli"}, {"stop", "lifecycle"}),
}
# Exact mutation inventory from upstream paths.rs and integration installers.
NATIVE = {
    "codex": [".codex/AGENTS.md", ".codex/config.toml", ".codex/hooks.json"],
    "claude": [
        ".claude/CLAUDE.md",
        ".claude/settings.json",
        ".claude.json",
        ".claude/hooks/askhuman-timeout.sh",
    ],
    "cursor": [
        ".cursor/hooks.json",
        ".cursor/mcp.json",
        ".cursor/rules/askhuman.mdc",
        ".cursor/hooks/askhuman-timeout.sh",
        ".cursor/hooks/humaninloop-timeout.sh",
    ],
    "grok": [
        ".grok/config.toml",
        ".grok/skills/interaction-protocol/SKILL.md",
        ".grok/hooks/askhuman-lifecycle.json",
    ],
    "pi": [".pi/agent/AGENTS.md", ".pi/agent/extensions/askhuman/index.ts"],
}
PREFERENCES = [
    "integration-state.json",
    "integrations.lock",
    "permission-preferences.json",
    "stop-preferences.json",
    "lifecycle-preferences.json",
    "ask-question-preferences.json",
]
MARKERS = {
    "__agent-hook",
    "__permission-hook",
    "__stop-hook",
    "__subagent-hook",
    "__context-recovery-hook",
    "__ask-question-hook",
}
LABELS = dict(
    zip(
        [
            "PermissionRequest",
            "SessionStart",
            "UserPromptSubmit",
            "PreToolUse",
            "PostToolUse",
            "PreCompact",
            "PostCompact",
            "SubagentStart",
            "SubagentStop",
            "Stop",
        ],
        [
            "permission_request",
            "session_start",
            "user_prompt_submit",
            "pre_tool_use",
            "post_tool_use",
            "pre_compact",
            "post_compact",
            "subagent_start",
            "subagent_stop",
            "stop",
        ],
    )
)
MATCHERS = {
    "PreToolUse",
    "PermissionRequest",
    "PostToolUse",
    "PreCompact",
    "PostCompact",
    "SessionStart",
    "SubagentStart",
    "SubagentStop",
}


def _checkpoint(name):
    """Fault injection seam; no environment-controlled production behavior."""


def write_bytes(path, data, mode=0o600):
    path = ordinary.safe_path(path)
    ordinary._private_dir(path.parent)
    fd, temporary = tempfile.mkstemp(prefix=".askhuman-", dir=path.parent)
    try:
        os.fchmod(fd, mode)
        with os.fdopen(fd, "wb") as stream:
            stream.write(data)
            stream.flush()
            os.fsync(stream.fileno())
        ordinary.safe_path(path)
        os.replace(temporary, path)
        ordinary._sync_dir(path.parent)
    finally:
        if os.path.exists(temporary):
            os.unlink(temporary)


def source_path(value):
    if not isinstance(value, str) or not Path(value).is_absolute():
        raise Error("Secret source must be an absolute runtime path")
    path = Path(value).resolve(strict=True)
    if path == Path("/nix/store") or Path("/nix/store") in path.parents:
        raise Error("Secret sources cannot reside in the Nix store")
    if not path.is_file():
        raise Error("Secret source must be a regular file")
    # Validate readability now, without retaining plaintext in adapter state.
    with path.open("rb"):
        pass
    return str(path)


def validate(manifest):
    if not isinstance(manifest, dict) or type(manifest.get("enabled")) is not bool:
        raise Error("Invalid activation manifest")
    ordinary._leaves(manifest.get("settings", {}))
    secrets = manifest.get("secretFiles", {}) if manifest["enabled"] else {}
    integrations = manifest.get("integrations", {}) if manifest["enabled"] else {}
    if not isinstance(secrets, dict) or not isinstance(integrations, dict):
        raise Error("Invalid activation manifest")
    for key in secrets:
        if tuple(key.split(".")) not in ordinary.SECRET_PATHS:
            raise Error("Unsupported secret setting")
    for agent, policy in integrations.items():
        if agent not in MATRIX or not isinstance(policy, dict):
            raise Error("Unsupported native integration")
        modes, capabilities = MATRIX[agent]
        if policy.get("mode") not in modes:
            raise Error("Unsupported native mode")
        for capability in set(policy) - {"mode", "env"}:
            if capability not in capabilities or (
                policy[capability] is not None and type(policy[capability]) is not bool
            ):
                raise Error("Unsupported native capability")
        env = policy.get("env", {})
        if not isinstance(env, dict) or (
            env and (agent != "codex" or policy["mode"] != "mcp")
        ):
            raise Error("Unsupported native environment")
        if any(
            not re.fullmatch(r"[A-Za-z_][A-Za-z0-9_]*", k)
            or not isinstance(v, str)
            or "\0" in v
            for k, v in env.items()
        ):
            raise Error("Invalid native environment")
    return secrets, integrations


def run_cli(executable, arguments, home):
    env = dict(os.environ)
    env.pop("ASKHUMAN_HOME", None)
    env.update(
        HOME=str(home),
        CODEX_HOME=str(home / ".codex"),
        XDG_CONFIG_HOME=str(home / ".config"),
    )
    try:
        subprocess.run(
            [executable, *arguments],
            env=env,
            stdin=subprocess.DEVNULL,
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL,
            check=True,
        )
    except (OSError, subprocess.CalledProcessError):
        raise Error(
            "AskHuman CLI failed; private recovery evidence retained; provisioning may be partial"
        ) from None


# Ordinary schema roots are closed in the pinned release. New fields outside this
# inventory are user data, never defaults synthesized by CLI serialization.
KNOWN = {
    "general": set(
        "theme language alwaysOnTop appearAnimation windowEffect speechLanguage speechShortcut popupSubmitKey collaborationStyle collaborationStyleCustomText historyLimit todoHistoryLimit popupSound menuBarIcon popupPrewarm daemonLifecycle".split()
    ),
    "codexDesktop": {"appPath", "codexHome", "launchPreference"},
    "agentTasks": {"enabled", "permissionPrompt"},
    "permissions": {"codexRelaxedShell"},
    "experimental": {"enabled", "verticalQuestions"},
    "channels": {
        "autoActivation",
        "autoEndWatch",
        "popup",
        "telegram",
        "dingding",
        "feishu",
        "slack",
    },
    "channels.popup": set(
        "enabled windowMode width height rememberSize previewWidth sidebarWidth".split()
    ),
    "channels.telegram": {"enabled", "chatId", "apiBaseUrl", "botToken"},
    "channels.dingding": set(
        "enabled clientId userId cardTemplateId confirmCardTemplateId permissionConfirmCardTemplateId inlineSmallText convertTextToDocx clientSecret".split()
    ),
    "channels.feishu": {"enabled", "appId", "openId", "baseUrl", "appSecret"},
    "channels.slack": {"enabled", "userId", "botToken", "appToken"},
}


def guard_secret_structure(original, current, prefix=()):
    """Detect contradictory ordinary edits; retain newly added unknown leaves.

    CLI removes unknown fields and adds schema defaults. Existing ordinary
    fields must keep their values; missing/changed known fields are conflicts.
    """
    merged = copy.deepcopy(original)
    known = KNOWN.get(
        ".".join(prefix),
        {key for key in KNOWN if "." not in key} if not prefix else set(),
    )
    for key, value in original.items():
        path = prefix + (key,)
        if path in ordinary.SECRET_PATHS:
            continue
        if key not in current:
            if key in known:
                raise Error("Ordinary configuration changed during secret recovery")
            continue
        if isinstance(value, dict) and isinstance(current[key], dict):
            merged[key] = guard_secret_structure(value, current[key], path)
        elif not ordinary._same(value, current[key]):
            raise Error("Ordinary configuration changed during secret recovery")
    for key in current.keys() - original.keys():
        if key not in known:
            merged[key] = copy.deepcopy(current[key])
    return merged


def recover_secrets(home, state):
    pending_path = state / "secret-pending.json"
    pending, _ = ordinary._read(pending_path)
    if pending is None:
        return
    try:
        if pending["version"] != 1 or pending["home"] != str(home):
            raise ValueError()
        raw = pending["original"]
        if not isinstance(raw, dict):
            raise ValueError()
        requests = pending["requests"]
        for key, value in requests.items():
            if tuple(key.split(".")) not in ordinary.SECRET_PATHS:
                raise ValueError()
            source_path(value)
    except (KeyError, TypeError, ValueError):
        raise Error("Invalid private secret recovery snapshot") from None
    current, _ = ordinary._read(home / ".askhuman/config.json")
    if current is None and pending.get("targetExists", False):
        raise Error("Config missing during secret recovery; private evidence retained")
    if current is not None:
        raw = guard_secret_structure(raw, current)
    for key, value in requests.items():
        run_cli(
            pending["executable"],
            ["config", "set", key, "--from-file", source_path(value)],
            home,
        )
        _checkpoint("secret-cli-complete")
    config_path = home / ".askhuman/config.json"
    outcome, raw_outcome = ordinary._read(config_path)
    if outcome is None:
        raise Error("Secret CLI did not produce configuration")
    merged = guard_secret_structure(raw, outcome)
    for path in ordinary.SECRET_PATHS:
        ordinary._put(merged, path, ordinary._get(outcome, path), set())
    if ordinary._read(config_path)[1] != raw_outcome:
        raise Error(
            "Config changed during secret provisioning; recovery evidence retained"
        )
    ordinary.atomic_json(config_path, merged)
    _checkpoint("secret-merge-durable")
    ordinary._remove_pending(pending_path)
    ordinary.atomic_json(
        state / "secret-completion.json", {"version": 1, "completed": True}
    )


def provision(secrets, executable, home, state):
    if not secrets:
        return
    config, _ = ordinary._read(home / ".askhuman/config.json")
    if config is None:
        config, _ = ordinary._read(home / ".humaninloop/config.json")
    ordinary.atomic_json(
        state / "secret-pending.json",
        {
            "version": 1,
            "home": str(home),
            "original": config or {},
            "requests": secrets,
            "executable": executable,
            "targetExists": (home / ".askhuman/config.json").exists(),
        },
    )
    _checkpoint("secret-snapshot-durable")
    recover_secrets(home, state)


def native_paths(integrations, home):
    paths = {home / relative for agent in integrations for relative in NATIVE[agent]}
    if integrations:
        paths.update(home / ".askhuman" / name for name in PREFERENCES)
    return sorted(paths)


def backup_native(paths, state):
    target = state / "native-backups.json"
    backups, _ = ordinary._read(target)
    backups = backups or {"version": 1, "paths": {}}
    if backups.get("version") != 1 or not isinstance(backups.get("paths"), dict):
        raise Error("Invalid native backup inventory")
    for path in paths:
        ordinary.safe_path(path)
        if path.exists() and not path.is_file():
            raise Error("Native artifact must be a regular file")
        if str(path) not in backups["paths"]:
            raw = path.read_bytes() if path.exists() else None
            backups["paths"][str(path)] = {
                "exists": raw is not None,
                "content": base64.b64encode(raw).decode() if raw is not None else None,
                "sha256": hashlib.sha256(raw).hexdigest() if raw is not None else None,
                "mode": stat.S_IMODE(path.stat().st_mode) if raw is not None else None,
            }
    ordinary.atomic_json(target, backups)


def normalize_command(command, executable):
    # Only the executable token of a direct, recognized upstream hook invocation.
    try:
        words = shlex.split(command)
    except ValueError:
        raise Error("Malformed native hook command") from None
    if len(words) < 2 or words[1] not in MARKERS:
        return command
    if Path(words[0]).name not in {"AskHuman", ".AskHuman-wrapped", "AskHuman-wrapped"}:
        raise Error("Unknown AskHuman hook executable")
    match = re.match(r"""^(?:"[^"\n]*"|'[^'\n]*'|[^\s]+)(\s+.*)$""", command, re.S)
    if match is None:
        raise Error("Malformed owned hook executable")
    return shlex.quote(executable) + match.group(1)


def normalize_hooks(value, executable):
    hooks = value.get("hooks", {})
    if not isinstance(hooks, dict):
        raise Error("Malformed native hooks")
    for groups in hooks.values():
        if not isinstance(groups, list):
            raise Error("Malformed native hook groups")
        for group in groups:
            if not isinstance(group, dict):
                raise Error("Malformed native hook group")
            handlers = group.get("hooks", [group])
            if not isinstance(handlers, list):
                raise Error("Malformed native handlers")
            for handler in handlers:
                if not isinstance(handler, dict):
                    raise Error("Malformed native handler")
                if isinstance(handler.get("command"), str):
                    handler["command"] = normalize_command(
                        handler["command"], executable
                    )


def trusted_hash(event, group, handler):
    normalized = {
        "type": "command",
        "command": handler["command"],
        "timeout": max(1, handler.get("timeout", 600)),
        "async": False,
    }
    if isinstance(handler.get("statusMessage"), str):
        normalized["statusMessage"] = handler["statusMessage"]
    identity = {"event_name": LABELS[event], "hooks": [normalized]}
    if event in MATCHERS and isinstance(group.get("matcher"), str):
        identity["matcher"] = group["matcher"]
    canonical = json.dumps(
        identity, sort_keys=True, separators=(",", ":"), ensure_ascii=False
    )
    return "sha256:" + hashlib.sha256(canonical.encode()).hexdigest()


def normalize_native(integrations, home, executable):
    import tomlkit

    json_paths = {
        home / relative
        for agent in integrations
        for relative in NATIVE[agent]
        if relative.endswith(".json")
    }
    codex_hooks = None
    for path in sorted(json_paths):
        value, _ = ordinary._read(path)
        if value is None:
            continue
        original = copy.deepcopy(value)
        normalize_hooks(value, executable)
        servers = value.get("mcpServers", {})
        if not isinstance(servers, dict):
            raise Error("Malformed native MCP servers")
        for key in ("askhuman", "AskHuman"):
            if key in servers:
                if not isinstance(servers[key], dict) or not isinstance(
                    servers[key].get("command"), str
                ):
                    raise Error("Malformed owned MCP server")
                servers[key]["command"] = executable
        if value != original:
            ordinary.atomic_json(path, value)
        if path == home / ".codex/hooks.json":
            codex_hooks = value
    for agent in ("codex", "grok"):
        if agent not in integrations:
            continue
        path = home / f".{agent}/config.toml"
        if not path.exists():
            continue
        document = tomlkit.parse(path.read_text())
        servers = document.get("mcp_servers", {})
        if "askhuman" in servers:
            if not isinstance(servers["askhuman"].get("command"), str):
                raise Error("Malformed owned TOML MCP server")
            servers["askhuman"]["command"] = executable
        if agent == "codex" and codex_hooks:
            state = document.setdefault("hooks", {}).setdefault("state", {})
            for event, groups in codex_hooks.get("hooks", {}).items():
                if event not in LABELS:
                    continue
                for gi, group in enumerate(groups):
                    for hi, handler in enumerate(group.get("hooks", [])):
                        command = handler.get("command", "")
                        words = shlex.split(command)
                        if len(words) < 2 or words[1] not in MARKERS:
                            continue
                        if (
                            handler.get("type") != "command"
                            or handler.get("async") is True
                        ):
                            raise Error("Unsupported owned Codex handler")
                        key = f"{home / '.codex/hooks.json'}:{LABELS[event]}:{gi}:{hi}"
                        state.setdefault(key, {})["trusted_hash"] = trusted_hash(
                            event, group, handler
                        )
        write_bytes(path, tomlkit.dumps(document).encode())
    if "pi" in integrations:
        path = home / ".pi/agent/extensions/askhuman/index.ts"
        text = path.read_text()
        match = re.search(
            r"(/\* ASKHUMAN_CONFIG_BEGIN \*/)(.*?)(/\* ASKHUMAN_CONFIG_END \*/)",
            text,
            re.S,
        )
        if not match or not text.startswith("// Generated and managed by AskHuman."):
            raise Error("Unknown owned Pi extension")
        config = json.loads(match[2])
        if config.get("version") != 1 or not isinstance(config.get("executable"), str):
            raise Error("Unsupported Pi extension configuration")
        config["executable"] = executable
        text = (
            text[: match.start(2)]
            + " "
            + json.dumps(config, ensure_ascii=False)
            + " "
            + text[match.end(2) :]
        )
        write_bytes(path, text.encode())


def activate(manifest, home, state, dry_run=False):
    secrets, integrations = validate(manifest)
    # Deliberately before source opens, native preflight and lock creation.
    if dry_run:
        return
    home, state = ordinary.safe_path(home), ordinary.safe_path(state)
    pending = any(
        (state / name).exists()
        for name in ("pending.json", "secret-pending.json", "ledger.json")
    )
    if (
        not manifest.get("settings")
        and not secrets
        and not integrations
        and not pending
    ):
        return
    if not pending:
        secrets = {key: source_path(value) for key, value in secrets.items()}
    executable = manifest.get("executable")
    if (secrets or integrations) and (
        not isinstance(executable, str) or not Path(executable).is_absolute()
    ):
        raise Error("Native operations require an absolute package executable")
    paths = native_paths(integrations, home)
    with ordinary.module_lock(state):
        ordinary._recover(
            home / ".askhuman/config.json",
            state / "ledger.json",
            state / "pending.json",
        )
        recover_secrets(home, state)
        secrets = {key: source_path(value) for key, value in secrets.items()}
        for path in paths:
            ordinary.safe_path(path)
            if path.exists():
                if path.suffix == ".json":
                    ordinary._read(path)
                elif path.suffix == ".toml":
                    import tomlkit

                    tomlkit.parse(path.read_text())
        ordinary.reconcile(manifest, home, state, locked=True)
        provision(secrets, executable, home, state)
        if not integrations:
            return
        backup_native(paths, state)
        claude = integrations.get("claude", {})
        if claude.get("askQuestion") is not None:
            preference = home / ".askhuman/ask-question-preferences.json"
            value, _ = ordinary._read(preference)
            value = value or {}
            value["claude"] = claude["askQuestion"]
            ordinary._private_dir(preference.parent)
            ordinary.atomic_json(preference, value)
        for agent, policy in integrations.items():
            args = ["agents", "mode", agent, policy["mode"]]
            for key, value in sorted(policy.get("env", {}).items()):
                args.extend(["--env", key + "=" + value])
            run_cli(executable, args, home)
            for capability in ("permission", "stop", "lifecycle"):
                if policy.get(capability) is not None:
                    run_cli(
                        executable,
                        [
                            "agents",
                            capability,
                            agent,
                            "on" if policy[capability] else "off",
                        ],
                        home,
                    )
        normalize_native(integrations, home, executable)


# Public adapter entry point consumed by activation fixture checks.
run = activate


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--manifest", required=True)
    parser.add_argument("--home", required=True)
    parser.add_argument("--state-dir", required=True)
    parser.add_argument("--dry-run", action="store_true")
    args = parser.parse_args()
    try:
        manifest, _ = ordinary._read(args.manifest)
        activate(manifest, args.home, args.state_dir, args.dry_run)
    except (Error, OSError, ValueError, TypeError, KeyError):
        parser.exit(
            1,
            "AskHuman activation failed; private state retained; secret provisioning may be partial.\n",
        )


if __name__ == "__main__":
    main()
