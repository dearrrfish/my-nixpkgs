{
  lib,
  stdenvNoCC,
  fetchurl,
  autoPatchelfHook,
  makeWrapper,
  webkitgtk_4_1,
  gtk3,
  glib,
  cairo,
  pango,
  gdk-pixbuf,
  librsvg,
  openssl,
}:
stdenvNoCC.mkDerivation (finalAttrs: {
  pname = "askhuman";
  version = "0.9.4";

  src = fetchurl {
    url = "https://github.com/Naituw/AskHuman/releases/download/v${finalAttrs.version}/AskHuman-x86_64-unknown-linux-gnu-v${finalAttrs.version}.tar.gz";
    hash = "sha256-uGg/LZkj9+bsA9maIXzLwaNZTOctH5mgePRUtXJ2468=";
  };

  sourceRoot = ".";

  nativeBuildInputs = [
    autoPatchelfHook
    makeWrapper
  ];
  buildInputs = [
    webkitgtk_4_1
    gtk3
    glib
    cairo
    pango
    gdk-pixbuf
    librsvg
    openssl
  ];

  installPhase = ''
    runHook preInstall

    install -Dm755 AskHuman $out/bin/AskHuman

    runHook postInstall
  '';

  postFixup = ''
    wrapProgram $out/bin/AskHuman \
      --prefix LD_LIBRARY_PATH : ${lib.makeLibraryPath finalAttrs.buildInputs}
  '';

  meta = {
    description = "Human-in-the-loop interaction tool for AI agents";
    homepage = "https://github.com/Naituw/AskHuman";
    license = lib.licenses.mit;
    platforms = [ "x86_64-linux" ];
    mainProgram = "AskHuman";
  };
})
