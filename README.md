# my-nixpkgs

Custom packages, an overlay, and reusable NixOS and Home Manager modules, built
with flake-parts.

## Packages and overlay

Add the flake to your inputs:

```nix
inputs.my-nixpkgs.url = "github:dearrrfish/my-nixpkgs";
```

Package names include their two-character shard:

```sh
nix build 'github:dearrrfish/my-nixpkgs#as/askhuman'
```

The default overlay keeps these same names under `pkgs.local`:

```nix
{
  nixpkgs.overlays = [ inputs.my-nixpkgs.overlays.default ];
  environment.systemPackages = [ pkgs.local."as/askhuman" ];
}
```

Inspect available outputs with `nix flake show --json`. AskHuman's packaged binary
currently supports `x86_64-linux`; other packages have their own platform limits.

## Home Manager

Import a named module into your Home Manager configuration:

```nix
{
  imports = [ inputs.my-nixpkgs.homeManagerModules.askhuman ];
  programs.askhuman = {
    enable = true;
    settings.general.theme = "dark";
  };
}
```

The module uses your Home Manager package set and the repository's AskHuman
package definition. No overlay is required. Override `programs.askhuman.package`
when using another compatible package. `homeManagerModules.default` imports all
provided HM modules; individual programs remain disabled until enabled.

AskHuman settings stay writable. Only declared fields are managed; removing a
field conditionally restores its previous value. Agent integrations and runtime
secret files are independent opt-ins with additional home-state effects. Read
[the module guide](docs/modules/askhuman.md) before enabling them.

## NixOS modules

`nixosModules.default` is the explicit aggregation entry point for future system
modules. It currently imports no system modules and does not configure an
AskHuman system service. AskHuman is managed through Home Manager.

## Development

- [Architecture and adding modules](docs/architecture.md)
- [AskHuman module guide](docs/modules/askhuman.md)
- [AskHuman option reference](docs/modules/askhuman-options.md)
- [Migration and rollback](docs/migration.md)
- [AskHuman Linux troubleshooting](docs/askhuman.md)

Packages live in `pkgs/by-name/<shard>/<name>/package.nix`, using explicit
`callPackage` dependencies. `flake/` contains flake-parts infrastructure;
`modules/` contains consumer modules. See [AGENTS.md](AGENTS.md) for contribution
and verification conventions.
