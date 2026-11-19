{ callPackage, lib }:
callPackage ../dsh-desktop/mk-dsh-desktop.nix {
  pname = "dsh-desktop-beta";
  assetPrefix = "DSH-Desktop-Beta";
  upstreamDir = "DSH Desktop Beta";
  pins = lib.importJSON ./release.json;
}
