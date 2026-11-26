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
nix build 'github:dearrrfish/my-nixpkgs#fr/freecontrol2'
```

The default overlay keeps these same names under `pkgs.local`:

```nix
{
  nixpkgs.overlays = [ inputs.my-nixpkgs.overlays.default ];
  environment.systemPackages = [ pkgs.local."fr/freecontrol2" ];
}
```

Inspect available outputs with `nix flake show --json`. Individual packages have
their own platform limits.

### DSH Desktop channels

The Stable, Next, and Beta packages are `ds/dsh-desktop`, `ds/dsh-desktop-next`,
and `ds/dsh-desktop-beta`. Each supports `x86_64-linux` and `aarch64-linux` and
installs a launcher named after the package without its shard prefix.

Stable and Next share `~/.dsh` by default. Beta uses `~/.dsh-beta`. Profiles in
the same data directory share sessions, accounts, and credentials. Back up
`~/.dsh` before switching between Stable and Next.

## Home Manager and NixOS modules

`homeManagerModules.default` and `nixosModules.default` are the explicit
aggregation entry points for reusable Home Manager and NixOS modules.

`programs.askhuman` and the AskHuman package have moved to the upstream
`AskHuman` flake (`homeManagerModules.askhuman` and `packages.<system>.default`);
see [Migration and rollback](docs/migration.md).

## Development

- [Architecture and adding modules](docs/architecture.md)
- [Migration and rollback](docs/migration.md)

Packages live in `pkgs/by-name/<shard>/<name>/package.nix`, using explicit
`callPackage` dependencies. `flake/` contains flake-parts infrastructure;
`modules/` contains consumer modules. See [AGENTS.md](AGENTS.md) for contribution
and verification conventions.
