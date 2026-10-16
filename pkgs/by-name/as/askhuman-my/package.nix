{
  lib,
  stdenv,
  rustPlatform,
  fetchFromGitHub,
  fetchPnpmDeps,
  pnpmConfigHook,
  pnpm_10,
  nodejs_24,
  pkg-config,
  wrapGAppsHook4,
  git,
  python3,
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
let
  baseVersion = "0.14.5";
  nodejs = nodejs_24;
  pnpm = pnpm_10.override { nodejs-slim = nodejs; };
in
rustPlatform.buildRustPackage (finalAttrs: {
  pname = "askhuman-my";
  version = "${baseVersion}-my-${builtins.substring 0 7 finalAttrs.src.rev}";

  src = fetchFromGitHub {
    owner = "dearrrfish";
    repo = "AskHuman";
    rev = "c1c8b46e6d7768138f46e79ab2431e3658411d38";
    fetchLFS = true;
    hash = "sha256-//EMNKYuwllykWMyB1d7kC0uVOez6td+TNMNrEtl97g=";
  };

  pnpmDeps = fetchPnpmDeps {
    inherit (finalAttrs) pname version src;
    inherit pnpm;
    fetcherVersion = 3;
    hash = "sha256-IBH1jniSjOC8/sBxuuuPEaDdgUQbkgjYhxFKhlsAR0Q=";
  };

  cargoRoot = "src-tauri";
  buildAndTestSubdir = finalAttrs.cargoRoot;
  cargoHash = "sha256-cMOBuVC2r+xLMskrDt0+yzSyMWZSqwpeyHlMBlw8zAw=";

  buildFeatures = [ "custom-protocol" ];

  # Stamp the <baseVersion>-my-<short_rev> version into manifests and lockfiles so the
  # built binary, daemon handshake, and tray report the branch commit distinctly without
  # mutating upstream's base version in git, while keeping compare_versions normalized.
  # Also patch the hardcoded /usr/bin/env python3 shebang in codex_desktop::runtime::tests.
  postPatch = ''
    substituteInPlace package.json src-tauri/tauri.conf.json \
      --replace-fail '"version": "${baseVersion}"' '"version": "${finalAttrs.version}"'
    substituteInPlace src-tauri/Cargo.toml \
      --replace-fail 'version = "${baseVersion}"' 'version = "${finalAttrs.version}"'
    substituteInPlace src-tauri/Cargo.lock "$cargoDepsCopy/Cargo.lock" \
      --replace-fail $'name = "humaninloop"\nversion = "${baseVersion}"' \
      $'name = "humaninloop"\nversion = "${finalAttrs.version}"'
    substituteInPlace src-tauri/src/update/mod.rs \
      --replace-fail "let pa: Vec<u64> = a.split('.')" \
      "let (a, b) = (normalize_version(a), normalize_version(b)); let pa: Vec<u64> = a.split('.')"
    substituteInPlace src-tauri/src/codex_desktop/runtime.rs \
      --replace-fail "#!/usr/bin/env python3" "#!${python3}/bin/python3"
  '';

  # codex_desktop::runtime::tests writes and immediately execs a temporary script;
  # running it concurrently with other fork/exec tests triggers Linux ETXTBSY (os error 26).
  # Run the main suite in parallel and execute codex_desktop::runtime::tests single-threaded in postCheck.
  checkFlags = [
    "--skip=codex_desktop::runtime::tests::"
  ];

  postCheck = ''
    cargo test --release --manifest-path src-tauri/Cargo.toml \
      --target ${stdenv.hostPlatform.rust.rustcTargetSpec} \
      --features custom-protocol \
      -- codex_desktop::runtime::tests:: --test-threads=1
  '';

  nativeBuildInputs = [
    nodejs
    pnpm
    pnpmConfigHook
    pkg-config
    wrapGAppsHook4
  ];

  nativeCheckInputs = [
    git
    python3
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

  # The tray backend loads AppIndicator via dlopen at runtime, so expose it
  # through the wrapper's LD_LIBRARY_PATH alongside the WebKit DMA-BUF workaround.
  preFixup = ''
    gappsWrapperArgs+=(
      --prefix LD_LIBRARY_PATH : "${lib.makeLibraryPath [ libayatana-appindicator ]}"
      --set WEBKIT_DISABLE_DMABUF_RENDERER 1
    )
  '';

  preBuild = ''
    pnpm run build
  '';

  meta = {
    description = "Human-in-the-loop interaction tool for AI agents (dearrrfish/AskHuman my-nixpkgs branch)";
    homepage = "https://github.com/dearrrfish/AskHuman";
    license = lib.licenses.mit;
    platforms = [ "x86_64-linux" ];
    mainProgram = "AskHuman";
  };
})
