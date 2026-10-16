# AskHuman Linux integration notes

For declarative installation, settings and native integrations, use the
[Home Manager module](modules/askhuman.md). The package currently provides the
upstream v0.14.4 Linux x86-64 binary.

## WebKitGTK popup environment

The package wraps `AskHuman` with the GTK runtime setup and
`WEBKIT_DISABLE_DMABUF_RENDERER=1`. This addresses a WebKitGTK popup issue on some
Wayland systems. Use the public `bin/AskHuman` launcher.

## Generated MCP and hook commands

Upstream v0.14.4 still generates multiple integration commands with Rust
`current_exe()`. After a Nix wrapper executes its ELF binary, that path resolves
to `.AskHuman-wrapped`, bypassing the public launcher's environment setup.

When native integration management is opted into the HM module, its adapter
normalizes AskHuman-owned generated executable references to the selected public
launcher and refreshes affected Codex hook trust hashes. Unrelated agent entries
are preserved. Running upstream integration updates outside HM can regenerate
private paths; reapply the HM generation to restore managed launchers.

For integrations managed elsewhere, explicitly supply the environment to MCP and
hooks, or use the public launcher through the owning agent configuration. Codex
MCP supports:

```toml
[mcp_servers.askhuman]
env = { WEBKIT_DISABLE_DMABUF_RENDERER = "1" }
```

The environment on MCP alone does not cover all generated hooks. The optional
HM `compatibility.webKitSessionEnvironment` setting also exports the workaround
to the graphical session. Application/daemon environment changes may require an
explicit restart from that session; HM activation does not restart it.

## Desktop acceptance

Headless checks verify configuration preservation, generated launchers and
integration artifacts. They do not prove popup rendering, display scale or
multi-monitor behavior. Review the popup on the actual desktop after adopting
the module. `/dotnix`'s independent popup mode and prewarm/tray choices are
available as explicit settings in the module guide.

<!-- VERIFY: Check popup rendering, display scale and Hyprland floating behavior on an actual desktop; only headless fixtures were run here. -->
