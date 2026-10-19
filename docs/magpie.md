# Magpie (`ma/magpie`)

`pkgs/by-name/ma/magpie/package.nix` builds [Magpie](https://github.com/yetone/magpie),
a unified tool and desktop GUI to manage models, subscriptions, and routing
across LLM coding agents.

```sh
# Build and run the default package
nix build 'path:.#"ma/magpie"'
nix run 'path:.#"ma/magpie"' -- --version
nix run 'path:.#"ma/magpie"' -- ls
```

## GUI vs CLI-only (`withGui = false`)

The derivation provides an optional `withGui` parameter:

- `withGui ? stdenv.hostPlatform.isLinux` (defaults to `true` on Linux, `false` elsewhere):
  - Builds the GTK 3 / WebKitGTK 4.1 desktop GUI (`CGO_ENABLED = 1`, `tags = [ "production" "gtk3" ]`).
  - Wraps the binary using `wrapGAppsHook3` with runtime environment defaults.
  - Installs the desktop application entry and hicolor icons.
- When `withGui = false`:
  - Builds a standalone, headless CLI binary (`CGO_ENABLED = 0`, `tags = [ "nogui" ]`).
  - Wraps the binary using `makeWrapper` with `MAGPIE_BUN`.
  - Can be built and evaluated across Unix platforms without graphical dependencies.

To override the package for a headless or server environment:

```nix
pkgs.local."ma/magpie".override { withGui = false; }
```

Or from the command line:

```sh
nix build 'path:.#"ma/magpie".passthru.tests.nogui'
```

## Wrapper behavior and executable normalization

The application binary is wrapped to provide runtime dependencies and environment variables:

- `MAGPIE_BUN`: points to the Nix-provided `bun` executable by default.
- `WEBKIT_DISABLE_DMABUF_RENDERER=1`: avoids WebKitGTK renderer issues under certain Wayland compositors (matching the AskHuman configuration).
- `PATH`: suffixed with `xdg-utils` so helper utilities such as `xdg-mime` and `update-desktop-database` function correctly.

Because Nix wrapper hooks rename the underlying ELF executable to `.magpie-wrapped`, standard Go calls to `os.Executable()` resolve to the wrapped binary rather than the public wrapper script. Re-invoking or registering `.magpie-wrapped` in background services (`daemon`), desktop session startup (`autostart`), desktop entries (`scheme_linux`), and OAuth callbacks would bypass the wrapper's environment setup. A `postPatch` step normalizes Nix wrapper executable paths (`/.magpie-wrapped` -> `/magpie`) across affected internal packages.

## Updating

`ma/magpie` tracks upstream release tags on GitHub. To update using `nix-update`:

```sh
nix run nixpkgs#nix-update -- --flake ma/magpie
```

Or manually:

1. Update `version` and the source archive `hash` in `pkgs/by-name/ma/magpie/package.nix`.
1. Temporarily set `vendorHash = lib.fakeHash;`.
1. Run `nix build 'path:.#"ma/magpie"'` and copy the reported hash into `vendorHash`.
1. Validate the build and flake checks:

```sh
nix build 'path:.#"ma/magpie"' --no-link
nix flake check path:. --print-build-logs
```

## Desktop acceptance

Headless checks verify compilation, the upstream Go test suite, CLI subcommands,
and wrapper normalization, but do not exercise an active Wayland/X11 graphical
session.

<!-- VERIFY: Check WebKitGTK window rendering, StatusNotifierItem tray icon, and magpie:// URL scheme dispatch on an actual Linux desktop session, and native builds on aarch64-linux / aarch64-darwin; only x86_64-linux headless builds and cross-system evaluations were run here. -->
