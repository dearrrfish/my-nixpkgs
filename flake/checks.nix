{ inputs, ... }:
{
  perSystem =
    {
      pkgs,
      system,
      ...
    }:
    {
      checks.module-eval = import ../tests/module-eval.nix { inherit inputs pkgs system; };
    };
}
