{ callPackage, lib }:
callPackage ../dsh-desktop/mk-dsh-desktop.nix {
  pname = "dsh-desktop-next";
  assetPrefix = "DSH-NEXT";
  upstreamDir = "DSH NEXT";
  pins = lib.importJSON ./release.json;
}
