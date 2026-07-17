# AskHuman Linux integration notes

## WebKitGTK popup crash workaround

The released Linux binary needs this runtime setting for WebKitGTK popups on
some Wayland systems:

```text
WEBKIT_DISABLE_DMABUF_RENDERER=1
```

`pkgs/by-name/as/askhuman/package.nix` adds it through `wrapGAppsHook4`, so
normal launches through `AskHuman` inherit the setting.

## Generated MCP integrations

AskHuman v0.9.4 writes Codex MCP and hook commands using Rust
`current_exe()`. After a Nix wrapper `exec`s the real binary,
`current_exe()` resolves to its private `.AskHuman-wrapped` ELF rather than
the public `AskHuman` launcher. Generated integrations therefore bypass the
Nix wrapper and can reproduce the WebKitGTK crash.

Until AskHuman provides a stable, wrapper-aware integration executable path,
configure the consuming agent explicitly. For Codex, set the MCP server
environment and prefix managed AskHuman hooks:

```toml
[mcp_servers.askhuman]
env = { WEBKIT_DISABLE_DMABUF_RENDERER = "1" }
```

```text
WEBKIT_DISABLE_DMABUF_RENDERER=1 /path/to/.AskHuman-wrapped __subagent-hook codex
WEBKIT_DISABLE_DMABUF_RENDERER=1 /path/to/.AskHuman-wrapped __permission-hook codex
```

AskHuman may regenerate these managed entries, so reapply the environment
workaround after running `AskHuman agents update codex`.

## Upstream resolution

AskHuman should generate integration commands from a stable launcher path (or
an explicit environment-provided executable path), instead of `current_exe()`.
That would allow Nix wrappers to remain in the generated MCP and hook paths.
