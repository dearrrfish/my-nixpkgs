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
  procps,
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
  baseVersion = "0.16.0";
  nodejs = nodejs_24;
  pnpm = pnpm_10.override { nodejs-slim = nodejs; };
in
rustPlatform.buildRustPackage (finalAttrs: {
  pname = "askhuman-my";
  version = "${baseVersion}+my-${builtins.substring 0 7 finalAttrs.src.rev}";

  src = fetchFromGitHub {
    owner = "dearrrfish";
    repo = "AskHuman";
    rev = "48e243d201aaa3cd004f43d85374af11460e9b92";
    fetchLFS = true;
    hash = "sha256-yFUQay5xwOhzNODhnXM6cVsrgasJj/DwDwI05Q7t/g4=";
  };

  pnpmDeps = fetchPnpmDeps {
    inherit (finalAttrs) pname version src;
    inherit pnpm;
    fetcherVersion = 3;
    hash = "sha256-IBH1jniSjOC8/sBxuuuPEaDdgUQbkgjYhxFKhlsAR0Q=";
  };

  cargoRoot = "src-tauri";
  buildAndTestSubdir = finalAttrs.cargoRoot;
  cargoHash = "sha256-/kaKFKT0Wu9U2UY+kwNbVtzUjfONKI5BMjolLQjDZbo=";

  buildFeatures = [ "custom-protocol" ];

  # Stamp the <baseVersion>+my-<short_rev> version into manifests and lockfiles so the
  # built binary, daemon handshake, and tray report the branch commit distinctly without
  # mutating upstream's base version in git, while keeping compare_versions normalized.
  # Also patch Python fixture shebangs in the Codex Desktop runtime and model tests.
  postPatch = ''
    substituteInPlace package.json src-tauri/tauri.conf.json \
      --replace-fail '"version": "${baseVersion}"' '"version": "${finalAttrs.version}"'
    substituteInPlace src-tauri/Cargo.toml \
      --replace-fail 'version = "${baseVersion}"' 'version = "${finalAttrs.version}"'
    substituteInPlace src-tauri/Cargo.lock "$cargoDepsCopy/Cargo.lock" \
      --replace-fail $'name = "humaninloop"\nversion = "${baseVersion}"' \
      $'name = "humaninloop"\nversion = "${finalAttrs.version}"'
    substituteInPlace src-tauri/src/codex_desktop/runtime.rs src-tauri/src/codex_desktop/models.rs \
      --replace-fail "#!/usr/bin/env python3" "#!${python3}/bin/python3"
  '';

  # codex_desktop::runtime::tests writes and immediately execs a temporary script;
  # running it concurrently with other fork/exec tests triggers Linux ETXTBSY (os error 26).
  # Run the main suite in parallel and execute codex_desktop::runtime::tests single-threaded in postCheck.
  checkFlags = [
    "--skip=codex_desktop::runtime::tests::"
    "--skip=dev_instance::tests::process_direct_dev_binary_binds_home_without_marker"
  ];

  postCheck = ''
    cargo test --release --manifest-path src-tauri/Cargo.toml \
      --target ${stdenv.hostPlatform.rust.rustcTargetSpec} \
      --features custom-protocol \
      -- codex_desktop::runtime::tests:: --test-threads=1
    # 该测试同样会立即执行新写入的文件；避免并发 fork/exec 引发 ETXTBSY。
    cargo test --release --manifest-path src-tauri/Cargo.toml \
      --target ${stdenv.hostPlatform.rust.rustcTargetSpec} \
      --features custom-protocol \
      -- dev_instance::tests::process_direct_dev_binary_binds_home_without_marker --exact --test-threads=1
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
    procps
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
  # Agent 检测在运行时调用 ps，需要独立于 nativeCheckInputs 提供。
  preFixup = ''
    gappsWrapperArgs+=(
      --prefix PATH : "${lib.makeBinPath [ procps ]}"
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
