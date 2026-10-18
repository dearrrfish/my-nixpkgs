{
  lib,
  stdenvNoCC,
  fetchurl,
  autoPatchelfHook,
  wrapGAppsHook4,
  webkitgtk_4_1,
  gtk3,
  glib,
  cairo,
  pango,
  gdk-pixbuf,
  librsvg,
  openssl,
  libayatana-appindicator,
}:
stdenvNoCC.mkDerivation (finalAttrs: {
  pname = "askhuman";
  version = "0.15.0";

  src = fetchurl {
    url = "https://github.com/Naituw/AskHuman/releases/download/v${finalAttrs.version}/AskHuman-x86_64-unknown-linux-gnu-v${finalAttrs.version}.tar.gz";
    hash = "sha256-7RQICW7a5OkwxiY+CXbysOe4lzh+5D7NW3pOjPx9jLw=";
  };

  sourceRoot = ".";

  nativeBuildInputs = [
    autoPatchelfHook
    wrapGAppsHook4
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

  # The tray backend loads AppIndicator with dlopen, so retain its runtime path.
  runtimeDependencies = [ libayatana-appindicator ];

  installPhase = ''
    runHook preInstall

    install -Dm755 AskHuman $out/bin/AskHuman

    runHook postInstall
  '';

  preFixup = ''
    gappsWrapperArgs+=(
      --set WEBKIT_DISABLE_DMABUF_RENDERER 1
    )
  '';

  meta = {
    description = "Human-in-the-loop interaction tool for AI agents";
    homepage = "https://github.com/Naituw/AskHuman";
    license = lib.licenses.mit;
    platforms = [ "x86_64-linux" ];
    mainProgram = "AskHuman";
  };
})
