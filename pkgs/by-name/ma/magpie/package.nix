{
  lib,
  stdenv,
  buildGoModule,
  fetchFromGitHub,
  runCommand,
  pkg-config,
  wrapGAppsHook3,
  makeWrapper,
  copyDesktopItems,
  makeDesktopItem,
  gtk3,
  webkitgtk_4_1,
  glib,
  cairo,
  pango,
  gdk-pixbuf,
  bun,
  xdg-utils,
  versionCheckHook,
  coreutils,
  dbus,
  bash,
  python3,
  procps,
  withGui ? stdenv.hostPlatform.isLinux,
  callPackage,
}:

buildGoModule (finalAttrs: {
  pname = "magpie";
  version = "0.1.1472";

  src = fetchFromGitHub {
    owner = "yetone";
    repo = "magpie";
    rev = "v${finalAttrs.version}";
    hash = "sha256-UOmr4j3Jtw6oifpDW9yRYW7+ot1HwkkmzUOCsRGn8vQ=";
  };

  vendorHash = "sha256-pBk3sQZ9/1sVdz2ZteBGgQrI49fDfgsQ8ur7pzM477A=";

  excludedPackages = [
    "build/icon"
    "internal/gui/genpurposes"
  ];

  env = {
    CGO_ENABLED = if withGui then 1 else 0;
  };

  tags =
    if withGui then
      [
        "production"
        "gtk3"
      ]
    else
      [ "nogui" ];

  nativeBuildInputs =
    if withGui then
      [
        pkg-config
        wrapGAppsHook3
        copyDesktopItems
      ]
    else
      [
        makeWrapper
      ];

  buildInputs = lib.optionals withGui [
    gtk3
    webkitgtk_4_1
    glib
    cairo
    pango
    gdk-pixbuf
  ];

  nativeCheckInputs = [
    bash
    coreutils
    dbus
    procps
    python3
  ];

  ldflags = [
    "-s"
    "-w"
    "-X main.version=${finalAttrs.version}"
  ];

  # Nix wrapper scripts execute .magpie-wrapped. Re-invoking or registering
  # os.Executable() directly would bypass the wrapper's environment setup
  # (such as GTK/WebKit runtime variables and MAGPIE_BUN).
  postPatch = ''
    substituteInPlace internal/update/update.go \
      --replace-fail 'return filepath.EvalSymlinks(exe)' \
      'p, err := filepath.EvalSymlinks(exe)
    	if err != nil {
    		return "", err
    	}
    	return strings.ReplaceAll(p, "/.magpie-wrapped", "/magpie"), nil'

    substituteInPlace internal/daemon/daemon.go \
      --replace-fail 'exe, err := os.Executable()
    	if err != nil {
    		return "", err
    	}' \
      'exe, err := os.Executable()
    	if err != nil {
    		return "", err
    	}
    	exe = strings.ReplaceAll(exe, "/.magpie-wrapped", "/magpie")'

    substituteInPlace internal/autostart/autostart.go \
      --replace-fail 'return exe, nil' \
      'return strings.ReplaceAll(exe, "/.magpie-wrapped", "/magpie"), nil'

    substituteInPlace internal/gui/scheme_linux.go \
      --replace-fail 'exe, err := os.Executable()
    	if err != nil {
    		return err
    	}' \
      'exe, err := os.Executable()
    	if err != nil {
    		return err
    	}
    	exe = strings.ReplaceAll(exe, "/.magpie-wrapped", "/magpie")' \
      --replace-fail 'exe, err := os.Executable()
    	if err != nil {
    		return
    	}' \
      'exe, err := os.Executable()
    	if err != nil {
    		return
    	}
    	exe = strings.ReplaceAll(exe, "/.magpie-wrapped", "/magpie")'

    substituteInPlace internal/gui/api.go \
      --replace-fail 'exe, err := os.Executable()
    		if err != nil {
    			fail(rw, err)
    			return
    		}' \
      'exe, err := os.Executable()
    		if err != nil {
    			fail(rw, err)
    			return
    		}
    		exe = strings.ReplaceAll(exe, "/.magpie-wrapped", "/magpie")'

    substituteInPlace internal/gateway/claude_subscription.go \
      --replace-fail 'return os.Executable()' \
      'exe, err := os.Executable()
    	if err != nil {
    		return "", err
    	}
    	return strings.ReplaceAll(exe, "/.magpie-wrapped", "/magpie"), nil'

    substituteInPlace internal/provider/claude_signin.go \
      --replace-fail 'exe, _ := os.Executable()' \
      'exe, _ := os.Executable()
    	exe = strings.ReplaceAll(exe, "/.magpie-wrapped", "/magpie")'

    substituteInPlace internal/gui/omarchy.go \
      --replace-fail '"os"' '"os"
    	"strings"' \
      --replace-fail 'if exe, err = os.Executable(); err == nil {' \
      'if exe, err = os.Executable(); err == nil {
    				exe = strings.ReplaceAll(exe, "/.magpie-wrapped", "/magpie")' \
      --replace-fail 'if exe, err := os.Executable(); err == nil {' \
      'if exe, err := os.Executable(); err == nil {
    				exe = strings.ReplaceAll(exe, "/.magpie-wrapped", "/magpie")'
  '';

  desktopItems = lib.optionals withGui [
    (makeDesktopItem {
      name = "magpie";
      exec = "magpie %u";
      icon = "magpie";
      desktopName = "Magpie";
      comment = finalAttrs.meta.description;
      categories = [
        "Development"
        "Utility"
      ];
      mimeTypes = [ "x-scheme-handler/magpie" ];
      startupWMClass = "magpie";
      terminal = false;
    })
  ];

  # Adapt sandbox test environments in preCheck so test-only dependencies are
  # only referenced when checks are enabled.
  preCheck = ''
    export HOME="$(mktemp -d)"

    substituteInPlace internal/agent/omp_wsl_key_test.go \
      --replace-fail '#!/usr/bin/env bun' '#!${coreutils}/bin/env bun' \
      --replace-fail '":/usr/bin:/bin"' '":${coreutils}/bin:${bash}/bin"'

    substituteInPlace internal/agent/wsl_nvm_test.go \
      --replace-fail '":/usr/bin:/bin"' '":${coreutils}/bin:${bash}/bin"'

    substituteInPlace internal/agent/cliupdate_admin_test.go \
      --replace-fail '/bin/cat' '${coreutils}/bin/cat'

    substituteInPlace internal/agent/cliupdate_test.go \
      --replace-fail '/bin/cat' '${coreutils}/bin/cat'

    substituteInPlace internal/daemon/daemon_test.go \
      --replace-fail '/bin/cat' '${coreutils}/bin/cat'

    substituteInPlace internal/library/rtk_agy_test.go \
      --replace-fail '/bin/cat' '${coreutils}/bin/cat' \
      --replace-fail '/bin/mkdir' '${coreutils}/bin/mkdir'

    substituteInPlace internal/library/rtk_test.go \
      --replace-fail '/bin/cat' '${coreutils}/bin/cat' \
      --replace-fail '/bin/mkdir' '${coreutils}/bin/mkdir'

    substituteInPlace internal/library/rtk_upgrade_test.go \
      --replace-fail '/bin/cat' '${coreutils}/bin/cat'

    substituteInPlace internal/agent/zed_credential_secret_test.go \
      --replace-fail '"--session"' '"--config-file=${dbus}/share/dbus-1/session.conf"'

    substituteInPlace internal/gateway/automode_test.go \
      --replace-fail '#!/usr/bin/env python3' '#!${python3}/bin/python3'

    # Upstream test expectation typo: raw JSON has escaped \n, not unescaped newlines
    substituteInPlace internal/gateway/claude_client_cache_test.go \
      --replace-fail 'instructions\\u003e\nshared\n\\u003c/external_system_instructions\\u003e\n\n\"' \
                     'instructions\\u003e\\nshared\\n\\u003c/external_system_instructions\\u003e\\n\\n\"'

    # Exclude Go modules vendor directory unpacked by buildGoModule from internal source lints
    substituteInPlace internal/proc/proc_test.go \
      --replace-fail 'd.Name() == "node_modules"' 'd.Name() == "node_modules" || d.Name() == "vendor"'

    substituteInPlace internal/sqlitedb/sqlitedb_test.go \
      --replace-fail 'd.Name() == "node_modules"' 'd.Name() == "node_modules" || d.Name() == "vendor"'

    substituteInPlace internal/pluginrt/pluginrt_test.go \
      --replace-fail 'rel == "site"' 'rel == "site" || rel == "vendor"'

    substituteInPlace internal/library/rtk_channel_background_test.go \
      --replace-fail '/bin/sleep' '${coreutils}/bin/sleep'

    substituteInPlace internal/provider/codex_keychain_ask_unix_test.go \
      --replace-fail '/bin/sleep' '${coreutils}/bin/sleep'

    substituteInPlace internal/proc/path_other_test.go \
      --replace-fail 'ps -o pgid= -p $$ | tr -d' '${procps}/bin/ps -o pgid= -p $$ | ${coreutils}/bin/tr -d' \
      --replace-fail 'ps -o sess= -p $$ | tr -d' '${procps}/bin/ps -o sess= -p $$ | ${coreutils}/bin/tr -d' \
      --replace-fail 't.Setenv("PATH", "/usr/bin:/bin")' 't.Setenv("PATH", "/usr/bin:/bin:${coreutils}/bin")' \
      --replace-fail '/bin/cat' '${coreutils}/bin/cat'
  '';

  postInstall =
    if withGui then
      ''
        install -Dm644 build/icon/magpie.svg $out/share/icons/hicolor/scalable/apps/magpie.svg
        install -Dm644 internal/gui/icon.png $out/share/icons/hicolor/64x64/apps/magpie.png
        install -Dm644 internal/gui/icon-256.png $out/share/icons/hicolor/256x256/apps/magpie.png
        install -Dm644 internal/gui/icon-1024.png $out/share/icons/hicolor/1024x1024/apps/magpie.png
      ''
    else
      ''
        wrapProgram $out/bin/magpie \
          --set-default MAGPIE_BUN "${lib.getExe bun}"
      '';

  preFixup = lib.optionalString withGui ''
    gappsWrapperArgs+=(
      --set-default MAGPIE_BUN "${lib.getExe bun}"
      --set-default WEBKIT_DISABLE_DMABUF_RENDERER 1
      --suffix PATH : "${lib.makeBinPath [ xdg-utils ]}"
    )
  '';

  doInstallCheck = true;
  nativeInstallCheckInputs = [ versionCheckHook ];
  versionCheckProgramArg = "--version";

  passthru.tests = {
    cli-smoke =
      runCommand "${finalAttrs.pname}-cli-smoke"
        {
          nativeBuildInputs = [ finalAttrs.finalPackage ];
        }
        ''
          export HOME="$(mktemp -d)"
          mkdir -p "$HOME/.claude"
          echo '{}' > "$HOME/.claude/settings.json"
          magpie --version
          magpie --help
          magpie ls
          magpie agents
          touch "$out"
        '';
  }
  // lib.optionalAttrs withGui {
    nogui = callPackage ./package.nix { withGui = false; };
  };

  meta = {
    description = "One place to pick every agent's model";
    homepage = "https://github.com/yetone/magpie";
    license = lib.licenses.mit;
    mainProgram = "magpie";
    platforms = if withGui then lib.platforms.linux else lib.platforms.unix;
  };
})
