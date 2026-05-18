{
  lib,
  stdenv,
  fetchurl,
  autoPatchelfHook,
  dpkg,
  wrapGAppsHook3,
  alsa-lib,
  at-spi2-atk,
  atk,
  cairo,
  cups,
  dbus,
  expat,
  fontconfig,
  freetype,
  gdk-pixbuf,
  glib,
  gtk3,
  libX11,
  libXScrnSaver,
  libXcomposite,
  libXcursor,
  libXdamage,
  libXext,
  libXfixes,
  libXi,
  libXrandr,
  libXrender,
  libXtst,
  libdrm,
  libnotify,
  libsecret,
  libuuid,
  libxcb,
  libxkbcommon,
  mesa,
  nspr,
  nss,
  pango,
  systemd,
}:

let
  version = "2.10.2";
  sources = {
    x86_64-linux = {
      url = "https://github.com/viarotel-org/escrcpy/releases/download/v${version}/Escrcpy-${version}-linux-amd64.deb";
      hash = "sha256-K6ieDMumPRaj40D85uPqozBhUyHUGLIYt8H2kF/6Rd0=";
    };
    aarch64-linux = {
      url = "https://github.com/viarotel-org/escrcpy/releases/download/v${version}/Escrcpy-${version}-linux-arm64.deb";
      hash = "sha256-FTI+6Sz6962VdLXuZxveHX/5ZWv7a0I0d3AnhSt+Qeo=";
    };
  };
  srcConfig =
    sources.${stdenv.hostPlatform.system}
      or (throw "Unsupported system: ${stdenv.hostPlatform.system}");
in
stdenv.mkDerivation {
  pname = "escrcpy";
  inherit version;

  src = fetchurl {
    inherit (srcConfig) url hash;
  };

  nativeBuildInputs = [
    autoPatchelfHook
    dpkg
    wrapGAppsHook3
  ];

  buildInputs = [
    alsa-lib
    at-spi2-atk
    atk
    cairo
    cups
    dbus
    expat
    fontconfig
    freetype
    gdk-pixbuf
    glib
    gtk3
    libX11
    libXScrnSaver
    libXcomposite
    libXcursor
    libXdamage
    libXext
    libXfixes
    libXi
    libXrandr
    libXrender
    libXtst
    libdrm
    libnotify
    libsecret
    libuuid
    libxcb
    libxkbcommon
    mesa
    nspr
    nss
    pango
    systemd
  ];

  dontBuild = true;
  dontConfigure = true;

  unpackPhase = ''
    runHook preUnpack
    dpkg-deb -x $src .
    runHook postUnpack
  '';

  installPhase = ''
    runHook preInstall

    mkdir -p $out/bin $out/share/escrcpy
    cp -av opt/Escrcpy/. $out/share/escrcpy/
    cp -av usr/share/. $out/share/

    ln -s $out/share/escrcpy/escrcpy $out/bin/escrcpy

    # Fix the desktop file
    substituteInPlace $out/share/applications/escrcpy.desktop \
      --replace "/opt/Escrcpy/escrcpy" "escrcpy"

    runHook postInstall
  '';

  meta = with lib; {
    description = "A graphical interface for scrcpy built with Electron";
    homepage = "https://github.com/viarotel-org/escrcpy";
    license = licenses.gpl3Only;
    platforms = [
      "x86_64-linux"
      "aarch64-linux"
    ];
    mainProgram = "escrcpy";
  };
}
