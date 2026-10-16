# Migration and recovery

## Repository layout

Internal flake-parts files moved from `modules/` to `flake/`. Replace private
imports of those old infrastructure paths if you used them. Public package
names, the overlay and `pkgs.local` remain unchanged; the correct AskHuman key is
`pkgs.local."as/askhuman"`.

Prefer the new public `homeManagerModules` and `nixosModules` outputs over private
paths. The NixOS root is currently empty; the first business module is HM
AskHuman.

## Existing AskHuman configuration

Keep a private backup of `~/.askhuman/config.json` and any native agent files
before first activation. Do not copy these files into this repository or the
Nix store. They can contain credentials and private agent history.

The module manages only explicitly declared ordinary fields. Existing
undeclared and unknown fields, history, todos and other runtime data are
preserved. Config files remain writable. Legacy `~/.humaninloop/config.json`
is a read fallback when the primary config does not exist; the legacy file is
not deleted. Malformed files and unsafe symlinks require manual repair rather
than being silently overwritten.

To remove ordinary settings management:

1. Keep the module imported and set `programs.askhuman.enable = false`.
1. Activate that intermediate HM generation. Keys still matching the last
   declared value restore their recorded original value; later GUI/user edits
   are retained.
1. Remove the import if desired.

Removing the import immediately, or switching to a generation predating the
module, cannot execute its cleanup hook. Keep the private ledger under
`$XDG_STATE_HOME/my-nixpkgs/askhuman` until cleanup/recovery is complete. With no
`XDG_STATE_HOME` override, HM normally uses `~/.local/state`.

## Native integrations and credentials

Setting an integration's `enable = false`, removing a native capability
preference, or disabling the program stops future reconciliation. It leaves
installed native integration files and preferences in place. To uninstall the
upstream-managed bundle deliberately, run the chosen package's public launcher
before disabling management, for example:

```sh
AskHuman agents mode codex none
```

This removes AskHuman-managed rules/hooks/MCP artifacts, not merely one MCP
entry. Review the target agent and existing integration before using it. Private
backups record preexisting files and absent paths; recover selectively so later
unrelated agent edits are not overwritten. HM generation rollback does not
restore native agent files or keychain entries.

Omitting a `secretFiles` source preserves the current credential. Delete a
credential explicitly with the upstream CLI only when intended; module rollback
does not roll back the keychain. A failed provisioning operation may have
already updated some credentials. Keep its private recovery evidence and retry
the same declaration after resolving the error. Never publish recovery files
or command output containing private data.

## Moving from /dotnix

Replace the host-specific `feature.ai.askhuman` package/enable declarations with
`programs.askhuman`. Keep desktop theme-switch integration in the consumer;
use `settings.general.theme` for a static declaration. The module guide maps the
WebKit, popup, native Codex and Hyprland customizations to portable settings.

Remove old activation hooks that mutate the same config or native agent files
after adopting this module. Run only one owner of each setting/integration.
This repository does not edit or activate `/dotnix` automatically.
