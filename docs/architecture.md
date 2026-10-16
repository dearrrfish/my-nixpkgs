# Architecture

This repository publishes packages and consumer modules from one flake. The
three module systems have separate import roots:

| Directory | Module system | Purpose |
| --- | --- | --- |
| `flake/` | flake-parts | Outputs, package discovery, overlay, formatter, checks and docs |
| `modules/nixos/` | NixOS | Reusable system modules |
| `modules/home-manager/` | Home Manager | Reusable user modules |
| `pkgs/by-name/` | `callPackage` derivations | Packages shared by flake outputs and modules |
| `tests/` | Nix evaluations and isolated Python fixtures | Public API and activation checks |

`flake.nix` imports only `flake/` through import-tree. Consumer modules must never
be placed under that tree: their options belong to NixOS or HM rather than
flake-parts. `flake/exports.nix` explicitly registers public module names;
consumer aggregation roots explicitly list imports.

## Public outputs

- `packages.<system>` retains slash keys such as `"as/askhuman"`.
- `overlays.default` exposes the same package set under `pkgs.local`.
- `homeManagerModules.askhuman` imports the first program module.
- `homeManagerModules.default` imports all provided HM modules, disabled by default.
- `nixosModules.default` is currently an empty aggregation root.
- `checks.<system>` contains module evaluation, runtime and documentation checks.

Supported flake systems remain `x86_64-linux`, `aarch64-linux` and
`aarch64-darwin`. A package can support fewer systems. Evaluation on another
system does not establish that its package builds or its GUI runs there.

## Dependencies and package defaults

Home Manager is pinned as a flake input for module evaluation and documentation,
following the existing Nixpkgs input. Consumer modules do not import this test
input or require a consumer to follow it. Consumers provide their own HM/Nixpkgs.

The AskHuman default package calls the existing derivation with the consumer's
`pkgs`. This avoids duplicated package definitions and an obligatory overlay.
It does not guarantee store-path identity with the flake package when the
consumer uses a different Nixpkgs revision. `package` remains overridable and
platform availability follows the selected package's metadata.

## Adding a module

1. Add a conventional module under the appropriate consumer root. Keep enable
   options disabled by default, expose package overrides where appropriate and
   avoid repository-specific host helpers.
1. Add its named export in `flake/exports.nix` and explicit import in that
   family's `default.nix`.
1. Add real evaluation fixtures to `tests/module-eval.nix`: disabled, enabled,
   composition, package override and meaningful invalid inputs. Test runtime
   effects in disposable fixtures when activation changes mutable state.
1. Document options, platform coverage, ownership and cleanup. Keep credentials
   outside store-generated values.
1. Wire checks in `flake/checks.nix`; add a system-specific execution job only
   when its platform is available. Keep modules out of `packages`, whose keys
   are consumed by package-update automation.

## AskHuman state boundaries

The HM module declares application policy; AskHuman owns its writable config
and other runtime files. A private settings ledger records only managed ordinary
leaves and their original values. Secret provisioning uses a separate private
recovery snapshot, which can contain credentials. Native agent integrations
have explicit opt-in ownership and private backups; their upstream rules/hooks
bundle has a different cleanup lifecycle from ordinary settings.

See the [module guide](modules/askhuman.md) for exact user-visible semantics and
[migration instructions](migration.md) before removing a previously active
module.
