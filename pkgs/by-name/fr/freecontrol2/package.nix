{
  lib,
  rustPlatform,
  fetchFromGitHub,
  fetchNpmDeps,
  cargo-tauri,
  nodejs,
  npmHooks,
  pkg-config,
  wrapGAppsHook3,
  jq,
  moreutils,
  glib,
  gtk3,
  openssl,
  webkitgtk_4_1,
  libayatana-appindicator,
  scrcpy,
  android-tools,
}:

rustPlatform.buildRustPackage (finalAttrs: {
  pname = "freecontrol2";
  version = "2.3.0";

  src = fetchFromGitHub {
    owner = "pdone";
    repo = "FreeControl2";
    tag = "v${finalAttrs.version}";
    hash = "sha256-bUdgF0RhiF9nlhFOxsxxldShuxc+54H8XKXSQNoXPrw=";
  };

  npmDeps = fetchNpmDeps {
    inherit (finalAttrs) src;
    hash = "sha256-D9niokwRPjPMcOGQtT/xXCGBZ89PpHx0wED0fEvY3WU=";
  };

  cargoHash = "sha256-fjaZOdssZdZJdx1PfXwnjHpc9wn8/hCFGBMzLBagykA=";

  cargoRoot = "src-tauri";
  buildAndTestSubdir = "src-tauri";

  postPatch = ''
    jq 'del(.build.beforeBuildCommand)' src-tauri/tauri.conf.json | sponge src-tauri/tauri.conf.json

    # libappindicator-sys dlopens libayatana-appindicator3.so.1 at runtime
    substituteInPlace $cargoDepsCopy/*/libappindicator-sys-*/src/lib.rs \
      --replace-warn "libayatana-appindicator3.so.1" "${libayatana-appindicator}/lib/libayatana-appindicator3.so.1"
  '';

  preBuild = ''
    npm run build
  '';

  nativeBuildInputs = [
    cargo-tauri.hook
    nodejs
    npmHooks.npmConfigHook
    pkg-config
    wrapGAppsHook3
    jq
    moreutils
  ];

  buildInputs = [
    glib
    gtk3
    openssl
    webkitgtk_4_1
    libayatana-appindicator
  ];

  preFixup = ''
    gappsWrapperArgs+=(
      --prefix PATH : ${
        lib.makeBinPath [
          scrcpy
          android-tools
        ]
      }
    )
  '';

  meta = {
    description = "Next-generation scrcpy GUI client built with Rust and Svelte";
    homepage = "https://github.com/pdone/FreeControl2";
    license = lib.licenses.mit;
    mainProgram = "FreeControl2";
    platforms = [ "x86_64-linux" ];
  };
})
