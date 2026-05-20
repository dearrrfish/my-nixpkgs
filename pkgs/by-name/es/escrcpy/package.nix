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
  libglvnd,
  libGL,
  mesa,
  nspr,
  nss,
  pango,
  systemd,
  scrcpy,
  android-tools,
  gnirehtet,
}:

let
  version = "2.11.1";
  sources = {
    x86_64-linux = {
      url = "https://github.com/viarotel-org/escrcpy/releases/download/v${version}/Escrcpy-${version}-linux-amd64.deb";
      hash = "sha256-7mxOS8IqGMWzJNijC/yo5qajJ4gm1c81tYud8/HOmqc=";
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
    libglvnd
    libGL
    mesa
    nspr
    nss
    pango
    systemd
    scrcpy
    android-tools
    gnirehtet
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

  preFixup = ''
    gappsWrapperArgs+=(
      --prefix LD_LIBRARY_PATH : "${lib.makeLibraryPath [ libGL libglvnd mesa ]}"
    )
  '';

  postInstall = ''
    # Replace bundled binaries with Nixpkgs versions
    # The architecture-specific directory is linux-x64 or linux-arm64
    for dir in $out/share/escrcpy/resources/extra/linux-*; do
      # linux/ directory only contains tray icons, skip it
      [ "$(basename "$dir")" = "linux" ] && continue

      if [ -d "$dir/scrcpy" ]; then
        rm -f "$dir/scrcpy/scrcpy"
        ln -s ${scrcpy}/bin/scrcpy "$dir/scrcpy/scrcpy"
        rm -f "$dir/scrcpy/adb"
        ln -s ${android-tools}/bin/adb "$dir/scrcpy/adb"
      fi

      if [ -d "$dir/gnirehtet" ]; then
        rm -f "$dir/gnirehtet/gnirehtet"
        ln -s ${gnirehtet}/bin/gnirehtet "$dir/gnirehtet/gnirehtet"
      fi
    done

    # Replace bundled scrcpy-server in common directory
    COMMON_RESOURCES=$out/share/escrcpy/resources/extra/common
    if [ -d "$COMMON_RESOURCES/scrcpy" ]; then
      rm -f "$COMMON_RESOURCES/scrcpy/scrcpy-server"
      ln -s ${scrcpy}/share/scrcpy/scrcpy-server "$COMMON_RESOURCES/scrcpy/scrcpy-server"
    fi
    if [ -d "$COMMON_RESOURCES/wscrcpy" ]; then
      rm -f "$COMMON_RESOURCES/wscrcpy/scrcpy-server"
      ln -s ${scrcpy}/share/scrcpy/scrcpy-server "$COMMON_RESOURCES/wscrcpy/scrcpy-server"
    fi
  '';

  meta = with lib; {
    description = "Graphical interface for scrcpy built with Electron";
    homepage = "https://github.com/viarotel-org/escrcpy";
    license = licenses.gpl3Only;
    maintainers = [ ];
    platforms = [
      "x86_64-linux"
      "aarch64-linux"
    ];
    mainProgram = "escrcpy";
  };
}
