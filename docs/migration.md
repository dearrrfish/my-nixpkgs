# Migration and recovery

## Repository layout

Internal flake-parts files moved from `modules/` to `flake/`. Replace private
imports of those old infrastructure paths if you used them. Public package
names, the overlay and `pkgs.local` remain unchanged.

Prefer the public `homeManagerModules` and `nixosModules` outputs over private
paths.

## AskHuman moved to the upstream AskHuman flake

The `as/askhuman` package and `homeManagerModules.askhuman` module have moved to
the upstream `AskHuman` repository flake:

- Replace `inputs.my-nixpkgs.homeManagerModules.askhuman` with
  `inputs.askhuman.homeManagerModules.askhuman` (or
  `inputs.askhuman.homeManagerModules.default`).
- Replace `pkgs.local."as/askhuman"` / `pkgs.inputs.my-nixpkgs.as.askhuman` with
  `inputs.askhuman.packages.${pkgs.stdenv.hostPlatform.system}.default` (or omit
  `programs.askhuman.package` to use the module's default package).

During activation, the upstream AskHuman Home Manager module automatically
migrates existing settings ledgers from
`$XDG_STATE_HOME/my-nixpkgs/askhuman/managed-settings.json` to
`$XDG_STATE_HOME/askhuman/hm/managed-settings.json` when the new ledger does not
yet exist.
