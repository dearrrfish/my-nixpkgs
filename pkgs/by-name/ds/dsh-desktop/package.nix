{ callPackage, lib }:
callPackage ./mk-dsh-desktop.nix {
  pname = "dsh-desktop";
  assetPrefix = "DSH-Desktop";
  upstreamDir = "DSH Desktop";
  pins = lib.importJSON ./release.json;
}
