{ inputs, ... }:
{
  imports = [
    inputs.treefmt-nix.flakeModule
  ];

  perSystem = {
    treefmt = {
      projectRootFile = "flake.nix";
      programs = {
        ruff-format.enable = true;
        taplo.enable = true;
        deadnix.enable = true;
        jsonfmt.enable = true;
        nixfmt.enable = true;
        statix.enable = true;
        yamlfmt.enable = true;
        mdformat.enable = true;
      };
      settings = {
        on-unmatched = "fatal";
      };
    };
  };
}
