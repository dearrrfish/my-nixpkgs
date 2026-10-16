# AskHuman Home Manager module

Import `homeManagerModules.askhuman` and configure `programs.askhuman`. The default
package is AskHuman 0.14.5 for `x86_64-linux`. A compatible `package` override can
be used on another supported platform. Importing a disabled module does not
require the Linux package.

```nix
{
  imports = [ inputs.my-nixpkgs.homeManagerModules.askhuman ];
  programs.askhuman = {
    enable = true;
    settings = {
      general.theme = "dark";
      general.historyLimit = 200;
      channels.popup.enabled = true;
    };
  };
}
```

See the generated [complete option reference](askhuman-options.md). The interface
tracks the [v0.14.5 configuration model](https://github.com/Naituw/AskHuman/blob/a8c7f8e89353ef044c3c99da58399342f1b0ba0f/src-tauri/src/config.rs)
and its Codex Desktop and Cursor Desktop submodels. All 51 ordinary leaves are typed; the five
credential leaves use a separate runtime-source interface.

## Settings ownership

Every `settings` leaf defaults to `null`, meaning unmanaged. Explicit `false`,
`0` and `""` are declarations. Normal Nix module merging, `lib.mkDefault` and
`lib.mkForce` apply. Unknown settings and credentials are rejected as Nix options
rather than being silently added to store-generated JSON.

The application config stays at `~/.askhuman/config.json` as a normal writable
file. Activation changes only declared ordinary leaves, preserving undeclared
and unknown fields. An empty declaration creates no config. The module records
the original value when first taking ownership and reasserts declared values
on later activation. GUI edits to a managed field last until the next
activation.

When a declaration is removed, its original value is restored only if the
current value still equals the module's last applied value. A later user edit is
preserved. An originally absent field becomes absent again, so AskHuman uses its
own default. A private ownership ledger under
`$XDG_STATE_HOME/my-nixpkgs/askhuman` makes these transitions possible.

Activation rejects malformed JSON, unsafe symlinks and conflicting structures.
Its private recovery records support retry after interrupted writes; conflicting
managed edits or a missing configuration during recovery require manual review.
Keep recovery files private and preserve them when diagnosing an error. A module
lock serializes this module's activations; it cannot lock out the GUI. Close
AskHuman's settings editor while applying a generation.

Home Manager dry-run performs no config, credential, integration or daemon
mutation. Activation does not launch or restart the GUI/daemon. Avoid
`ASKHUMAN_HOME` for production relocation: upstream treats it as a Dev Instance
and changes keychain behavior.

## Runtime credentials

Deploy secrets separately, for example with your existing secrets manager, and
pass absolute path strings:

```nix
programs.askhuman = {
  enable = true;
  settings.channels.telegram = {
    enabled = true;
    chatId = "123456";
  };
  secretFiles.channels.telegram.botToken = "/run/secrets/askhuman-telegram";
};
```

The other supported sources are DingTalk `clientSecret`, Feishu `appSecret`,
and Slack `botToken`/`appToken`. Do not use Nix path literals, `builtins.readFile`,
secret-valued settings or secret-valued integration environment variables. Those
would place credentials in the Nix store. Store-backed source paths, including
resolved symlinks into the store, are rejected.

Provisioning uses upstream `config set KEY --from-file PATH`; contents are
trimmed. AskHuman attempts OS credential storage and can fall back to owner-only
plaintext in `config.json` when the keychain is unavailable. This interface keeps
secret contents out of Nix evaluation; it does not promise keychain-only storage.

Upstream secret writes serialize its complete config model. The adapter protects
the raw ordinary/unknown structure with a private recovery transaction and merges
back only the five credential outcomes. Such temporary recovery snapshots can
contain existing plaintext credentials. They remain outside the store and logs
and are discarded after successful recovery/commit. Keychain writes are not
atomic with configuration recovery: partial provisioning can occur, and retry
reapplies the declaration. Omission preserves the credential; removal does not
delete or restore keychain values.

## Native agent integrations

All integrations default disabled. Enabling one authorizes upstream's complete
managed rules/hooks/MCP bundle, which modifies the agent's user files:

```nix
programs.askhuman.integrations.codex = {
  enable = true;
  mode = "mcp";
  permission = true;
  stop = true;
  lifecycle = true;
  mcpEnvironment = {
    WEBKIT_DISABLE_DMABUF_RENDERER = "1";
  };
};
```

| Agent | Modes | Optional capability declarations |
| --- | --- | --- |
| Codex | `cli`, `mcp` | `permission`, `stop`, `lifecycle` |
| Claude | `cli`, `mcp` | `permission`, `stop`, `lifecycle`, `askQuestion` |
| Cursor | `cli`, `mcp` | `stop`, `lifecycle` |
| Grok | `mcp` | `lifecycle` |
| Pi | `cli` | `stop`, `lifecycle` |

Capability leaves default to `null`: retain the upstream preference, including
upstream defaults that may enable a capability. `false` explicitly disables a
supported capability. Removing a preference stops reassertion and leaves its
last native value. Claude `askQuestion` controls interception of its built-in
AskUserQuestion tool. Codex `mcpEnvironment` is for non-secret values and is only
valid with enabled Codex MCP integration.

The adapter keeps private pre-mutation backups, including paths introduced by
later mode/capability changes and paths that were absent. It normalizes
AskHuman-owned generated commands to the selected package's public launcher,
including affected Codex hook trust hashes. It preserves unrelated entries.
Native target files must be writable regular files; resolve competing HM/store
symlink ownership before enabling native mutation.

Disabling an integration stops future reconciliation and leaves artifacts in
place. Deliberate uninstall uses `AskHuman agents mode AGENT none` before
removing management. That command removes the upstream-managed bundle. Review
[cleanup and recovery](../migration.md) before switching modes or removing the
module. Neither HM rollback nor the ordinary settings ledger reverses native
agent edits or keychain changes automatically.

## Linux and /dotnix compatibility

The package wrapper already supplies `WEBKIT_DISABLE_DMABUF_RENDERER=1`. Set
`compatibility.webKitSessionEnvironment = true` if you also need that setting
throughout the graphical session. Native generated commands are normalized to
the public launcher so they retain package wrapper setup.

The host policy used in `/dotnix` can be expressed explicitly:

```nix
programs.askhuman = {
  enable = true;
  compatibility.webKitSessionEnvironment = true;
  settings = {
    general.popupPrewarm = false;
    general.menuBarIcon = "off";
    channels.popup.windowMode = "independent";
  };
};
```

These remain opt-in policy choices. The module does not guess a Wayland socket,
DISPLAY, D-Bus address or monitor scale. Supply known non-secret values through
Codex MCP environment when needed. A running daemon can retain older session
environment; review and restart it manually from the intended graphical session.

For an already enabled HM Hyprland configuration, opt into
`compatibility.hyprland.enable = true` to add the AskHuman floating-window rule.
The base module does not enable or depend on a compositor. Use a static
`settings.general.theme` declaration or keep your desktop-specific theme-switch
hook in the consumer; avoid two owners for the same theme field.

<!-- VERIFY: Validate production keychain availability and graphical popup behavior in the consumer session. Tests use an isolated home and an unavailable credential service. -->

## Calling AskHuman from a theme-switch hook

If your desktop switcher supplies a resolved theme, install a small consumer-side
command and have the switcher call `set-askhuman-theme light` or
`set-askhuman-theme dark` after switching. This HM fragment uses the selected
package's public wrapper and leaves the theme outside module ownership:

```nix
{ config, pkgs, ... }:
{
  programs.askhuman = {
    enable = true;
    settings.general.theme = null;
  };

  home.packages = [
    (pkgs.writeShellApplication {
      name = "set-askhuman-theme";
      text = ''
        if [ "$#" -ne 1 ]; then
          echo 'usage: set-askhuman-theme system|light|dark' >&2
          exit 2
        fi
        case "$1" in
          system|light|dark)
            exec ${config.programs.askhuman.package}/bin/AskHuman config set general.theme "$1"
            ;;
          *)
            echo 'expected system, light or dark' >&2
            exit 2
            ;;
        esac
      '';
    })
  ];
}
```

Remove any other managed `settings.general.theme` declaration when using this
hook. This command deliberately invokes the upstream config CLI: it serializes
the full known schema and can discard unknown future fields. Use a static typed
HM declaration when you need the module's preservation/recovery guarantees.
The command runs only when the consumer invokes it; it is not an activation hook
and does not run during HM activation. Upstream 0.14.5 can start its daemon
on macOS when Cursor Desktop control is configured.

## Cursor Desktop control in 0.14.5

`settings.cursorDesktop.suppressBackgroundCompletionFollowUp` is a nullable
boolean for upstream's macOS-only background-completion control. It is unmanaged
by default. Its application behavior requires a compatible macOS package and is
not covered by Linux GUI acceptance.

Upstream Cursor mode changes can start a daemon when this control is enabled or
bridge cleanup is pending. On macOS, the HM adapter refuses native Cursor
reconciliation in those states rather than starting that daemon during
activation. Resolve the desktop control and any pending bridge cleanup manually
in the intended graphical session before enabling native reconciliation. Static
settings management and other native agents are unaffected.
