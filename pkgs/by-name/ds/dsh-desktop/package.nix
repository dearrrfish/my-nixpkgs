{
  lib,
  stdenv,
  fetchurl,
  runCommand,
  autoPatchelfHook,
  dpkg,
  wrapGAppsHook3,
  alsa-lib,
  at-spi2-atk,
  at-spi2-core,
  atk,
  bash,
  cairo,
  cups,
  dbus,
  expat,
  fontconfig,
  freetype,
  gdk-pixbuf,
  git,
  glib,
  gtk3,
  libGL,
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
  libayatana-appindicator,
  libdrm,
  libgbm,
  libglvnd,
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
  xdg-utils,
}:

let
  version = "2.0.18";
  sources = {
    x86_64-linux = {
      url = "https://github.com/anywhere-labs/dsh-desktop/releases/download/v${version}/DSH-Desktop-${version}-amd64.deb";
      hash = "sha256-VDaFUVZvrldhpD70uMvGJx+w9odhkNyeXvy3H0joIME=";
    };
    aarch64-linux = {
      url = "https://github.com/anywhere-labs/dsh-desktop/releases/download/v${version}/DSH-Desktop-${version}-arm64.deb";
      hash = "sha256-kE7sqGeMe/xz7YLDpqLdZggtGOyUspYMbK2//pXm8jg=";
    };
  };
  srcConfig =
    sources.${stdenv.hostPlatform.system}
      or (throw "Unsupported system: ${stdenv.hostPlatform.system}");
  foreignArch = if stdenv.hostPlatform.isx86_64 then "arm64" else "x64";
in
stdenv.mkDerivation (finalAttrs: {
  pname = "dsh-desktop";
  inherit version;

  # Package upstream's release Debian archive so we preserve the verified
  # Electron + vendored DeepSeek Harness runtime closure together with the
  # official desktop entry and multi-resolution Hicolor icons.
  src = fetchurl {
    inherit (srcConfig) url hash;
  };

  nativeBuildInputs = [
    autoPatchelfHook
    dpkg
    wrapGAppsHook3
  ];

  buildInputs = [
    stdenv.cc.cc.lib
    alsa-lib
    at-spi2-atk
    at-spi2-core
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
    libGL
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
    libgbm
    libglvnd
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

  # Electron and its tray/secret/notification backends load these libraries via
  # dlopen at runtime.
  runtimeDependencies = [
    libGL
    libayatana-appindicator
    libglvnd
    libnotify
    libsecret
    libuuid
    mesa
    systemd
  ];

  dontBuild = true;
  dontConfigure = true;

  unpackPhase = ''
    runHook preUnpack
    dpkg-deb -x "$src" .
    runHook postUnpack
  '';

  installPhase = ''
    runHook preInstall

    mkdir -p "$out/bin" "$out/share/dsh-desktop"
    cp -a "opt/DSH Desktop/." "$out/share/dsh-desktop/"
    cp -a usr/share/. "$out/share/"

    # Upstream's node_modules tree ships prebuilt native addons for both x64 and
    # arm64 as well as musl variants; remove foreign-architecture and musl
    # binaries before autoPatchelfHook scans $out.
    appNodeModules="$out/share/dsh-desktop/resources/app/node_modules"
    rm -rf \
      "$appNodeModules/sherpa-onnx-linux-${foreignArch}" \
      "$appNodeModules/@deepseek-ai/node-addon-system-linux-${foreignArch}" \
      "$appNodeModules/@deepseek-ai/node-addon-system-linux-x64/bin/musl" \
      "$appNodeModules/@deepseek-ai/node-addon-system-linux-arm64/bin/musl" \
      "$appNodeModules/node-addon-require-builtin-linux-${foreignArch}-gnu" \
      "$appNodeModules/@vscode/ripgrep-linux-${foreignArch}" \
      "$appNodeModules/@koromix/koffi-linux-${foreignArch}" \
      "$appNodeModules/@koromix/koffi-linux-x64/musl_x64" \
      "$appNodeModules/@koromix/koffi-linux-arm64/musl_arm64" \
      "$appNodeModules/koffi/node_modules/@koromix/koffi-linux-${foreignArch}" \
      "$appNodeModules/koffi/node_modules/@koromix/koffi-linux-x64/musl_x64" \
      "$appNodeModules/koffi/node_modules/@koromix/koffi-linux-arm64/musl_arm64" \
      "$appNodeModules/node-pty/prebuilds/linux-${foreignArch}" \
      "$appNodeModules/node-pty/prebuilds/darwin-x64" \
      "$appNodeModules/node-pty/prebuilds/darwin-arm64" \
      "$appNodeModules/node-pty/prebuilds/win32-x64" \
      "$appNodeModules/node-pty/prebuilds/win32-arm64" \
      "$appNodeModules/@dataiku/uv-linux-${foreignArch}" \
      "$appNodeModules/@img/sharp-libvips-linux-${foreignArch}" \
      "$appNodeModules/@img/sharp-linux-${foreignArch}"

    ln -s "$out/share/dsh-desktop/dsh-desktop" "$out/bin/dsh-desktop"

    substituteInPlace "$out/share/applications/dsh-desktop.desktop" \
      --replace-fail '"/opt/DSH Desktop/dsh-desktop"' "dsh-desktop"

    runHook postInstall
  '';

  preFixup = ''
    gappsWrapperArgs+=(
      --prefix LD_LIBRARY_PATH : "${
        lib.makeLibraryPath [
          libGL
          libglvnd
          mesa
          libayatana-appindicator
        ]
      }"
      --suffix PATH : "${
        lib.makeBinPath [
          bash
          git
          xdg-utils
        ]
      }"
    )
  '';

  doInstallCheck = true;

  installCheckPhase = ''
    runHook preInstallCheck

    export HOME="$(mktemp -d)"
    export DSH_HOME="$HOME/.dsh"
    export DSH_TELEMETRY_DISABLED=1

    versionOutput="$(
      ELECTRON_RUN_AS_NODE=1 \
        "$out/share/dsh-desktop/dsh-desktop" \
        "$out/share/dsh-desktop/resources/app/lib/bin.js" \
        --version
    )"
    if [ "$versionOutput" != "${finalAttrs.version}" ]; then
      echo "Unexpected dsh-desktop version: $versionOutput (expected ${finalAttrs.version})" >&2
      exit 1
    fi

    ELECTRON_RUN_AS_NODE=1 \
      "$out/share/dsh-desktop/dsh-desktop" \
      "$out/share/dsh-desktop/resources/app/lib/bin.js" \
      --help >/dev/null

    runHook postInstallCheck
  '';

  passthru.tests = {
    runtime-smoke =
      runCommand "${finalAttrs.pname}-runtime-smoke"
        {
          nativeBuildInputs = [ finalAttrs.finalPackage ];
        }
        ''
          export HOME="$(mktemp -d)"
          export DSH_HOME="$HOME/.dsh"
          export DSH_TELEMETRY_DISABLED=1
          export ELECTRON_RUN_AS_NODE=1

          appRoot="${finalAttrs.finalPackage}/share/dsh-desktop"
          exe="$appRoot/dsh-desktop"
          runtimeRoot="$appRoot/resources/app"

          "$exe" --expose-internals "$runtimeRoot/node_modules/@deepseek-ai/dsh/lib/bin.js" --version
          "$exe" --expose-internals "$runtimeRoot/node_modules/pnpm/bin/pnpm.mjs" --version
          smokeOut="$("$exe" --expose-internals "$runtimeRoot/lib/packaged-runtime-smoke.js")"
          if [ "$smokeOut" != "DSH_PACKAGED_RUNTIME_OK" ]; then
            echo "Unexpected packaged-runtime-smoke output: $smokeOut" >&2
            exit 1
          fi
          "$exe" --expose-internals "$runtimeRoot/lib/desktop-cli.js" --profile headless --dump-config >/dev/null
          "$exe" --expose-internals "$runtimeRoot/lib/desktop-cli.js" --profile headless --help >/dev/null

          touch "$out"
        '';
  };

  meta = {
    description = "Agentic coding desktop for the DeepSeek Harness";
    homepage = "https://github.com/anywhere-labs/dsh-desktop";
    license = lib.licenses.mit;
    mainProgram = "dsh-desktop";
    platforms = [
      "x86_64-linux"
      "aarch64-linux"
    ];
  };
})
