{ inputs, lib, ... }:
{
  # nixpkgs 26.11 dropped x86_64-darwin; evaluating it now throws.
  systems = lib.remove "x86_64-darwin" (import inputs.systems);
}
