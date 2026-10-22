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
  nodejs,
  pango,
  python3,
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
  runtimeArch = if stdenv.hostPlatform.isx86_64 then "x64" else "arm64";
  foreignArch = if stdenv.hostPlatform.isx86_64 then "arm64" else "x64";
  officePythonPackages = {
    inherit (python3.pkgs)
      lxml
      numpy
      openpyxl
      pandas
      pillow
      python-docx
      python-pptx
      xlsxwriter
      ;
  };
  officePython = python3.withPackages (_: builtins.attrValues officePythonPackages);
  officePythonVersions = lib.mapAttrs (_: pkg: pkg.version) officePythonPackages;
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

        # VERIFY: Re-evaluate whether this primary-runtime / office-skills assembly
        # hotfix is still needed after the next upstream version update once PR #1451
        # (commit 0cf20e6, which bundles resources/runtime on Linux) is included in a
        # release.
        # Upstream v2.0.18 omitted resources/runtime/<arch>/{primary-runtime,office-skills}
        # in Linux .deb builds (fixed upstream after v2.0.18 in PR #1451), which caused
        # Plugin Host startup to fail with "the bundled primary runtime is missing".
        # Assemble the primary-runtime and office-skills layout from Nixpkgs Python/Node
        # and the bundled pnpm + @deepseek-ai/dsh-skill-office assets, and keep the
        # runtime in-place in the immutable Nix store rather than copying it into $HOME.
        runtimeDir="$out/share/dsh-desktop/resources/runtime/${runtimeArch}"
        primaryRuntimeDir="$runtimeDir/primary-runtime"
        pythonBinDir="$primaryRuntimeDir/dependencies/python/bin"
        pythonLibDir="$primaryRuntimeDir/dependencies/python/lib/python${python3.pythonVersion}"
        nodeDir="$primaryRuntimeDir/dependencies/node"

        rm -rf "$runtimeDir"
        mkdir -p "$pythonBinDir" "$pythonLibDir" "$nodeDir/bin" "$nodeDir/node_modules" "$runtimeDir/office-skills"

        cat > "$pythonBinDir/python${python3.pythonVersion}" <<EOF
    #!${stdenv.shell}
    exec "${officePython}/bin/python3" "\$@"
    EOF
        chmod +x "$pythonBinDir/python${python3.pythonVersion}"
        ln -s "python${python3.pythonVersion}" "$pythonBinDir/python"
        ln -s "python${python3.pythonVersion}" "$pythonBinDir/python3"
        ln -s "${officePython}/${python3.sitePackages}" "$pythonLibDir/site-packages"

        ln -s "${nodejs}/bin/node" "$nodeDir/bin/node"
        ln -s "$appNodeModules/pnpm" "$primaryRuntimeDir/dependencies/pnpm"
        cp -a "$appNodeModules/@deepseek-ai/dsh-skill-office/assets/." "$runtimeDir/office-skills/"

        pnpmVersion="$("${nodejs}/bin/node" -p "require('$appNodeModules/pnpm/package.json').version")"
        "${nodejs}/bin/node" -e '
          const fs = require("node:fs");
          const manifest = {
            desktopVersion: process.argv[1],
            platform: "linux",
            arch: process.argv[2],
            python: process.argv[3],
            node: process.argv[4],
            pnpm: process.argv[5],
            pythonPackages: JSON.parse(process.argv[6]),
          };
          fs.writeFileSync(process.argv[7], JSON.stringify(manifest, null, 2) + "\n");
        ' \
          "${finalAttrs.version}" \
          "${runtimeArch}" \
          "${python3.version}" \
          "${nodejs.version}" \
          "$pnpmVersion" \
          '${builtins.toJSON officePythonVersions}' \
          "$primaryRuntimeDir/runtime.json"

        substituteInPlace "$out/share/dsh-desktop/resources/app/lib/"profile-channel-admission-*.js \
          --replace-fail 'root: join(home, "dsh-runtimes", PRIMARY_RUNTIME_INSTALL_NAME)' 'root: void 0'

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
          export APP_ROOT="$appRoot"
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

          # Verify that packaged Plugin Host primary-runtime and Office skills
          # resolution succeeds with packaged=true and executes the bundled
          # Python/Node/pnpm workspace dependencies.
          "$exe" --expose-internals --input-type=module -e '
            import { execFileSync } from "node:child_process";
            import { readdirSync } from "node:fs";
            import { join } from "node:path";
            import { pathToFileURL } from "node:url";

            const appRoot = process.env.APP_ROOT;
            const resourcesPath = join(appRoot, "resources");
            const runtimeRoot = join(resourcesPath, "app");
            const libDir = join(runtimeRoot, "lib");
            const findChunk = prefix => {
              const name = readdirSync(libDir).find(
                n => n.startsWith(prefix) && n.endsWith(".js")
              );
              if (!name) throw new Error("Missing chunk: " + prefix);
              return pathToFileURL(join(libDir, name)).href;
            };

            const admission = await import(findChunk("profile-channel-admission-"));
            const profileMod = await import(findChunk("profile-"));
            const contextMod = await import(findChunk("profile-context-"));
            const moduleRes = await import(findChunk("module-resolution-"));
            const pluginPkgs = await import(findChunk("plugin-packages-"));
            const pluginsSvc = await import(findChunk("desktop-plugins-"));
            const profileSvc = await import(findChunk("profile-service-"));
            const appBoot = await import(
              pathToFileURL(join(runtimeRoot, "node_modules/@deepseek-ai/dsh-app-boot/lib/index.js")).href
            );
            const cmdline = await import(
              pathToFileURL(join(runtimeRoot, "node_modules/@deepseek-ai/dsh-cmdline/lib/index.js")).href
            );
            const launchEnv = await import(
              pathToFileURL(join(runtimeRoot, "node_modules/@deepseek-ai/dsh-launch-environment/lib/index.js")).href
            );

            const desktopOffice = admission.D;
            const desktopPrimaryRuntime = admission.E;
            const resolveDesktopOfficeConfig = admission.O;
            const homeDir = process.env.DSH_HOME;

            const primaryRuntime = desktopPrimaryRuntime({
              packaged: true,
              resourcesPath,
              packageRoot: runtimeRoot,
            });
            const officeConfig = resolveDesktopOfficeConfig(primaryRuntime, homeDir);
            if (!officeConfig || officeConfig.root !== undefined) {
              throw new Error("Unexpected officeConfig: " + JSON.stringify(officeConfig));
            }

            let registeredTool;
            let registeredSkillProvider;
            const fakeCtx = {
              effect() {},
              tools: { register(tool) { registeredTool = tool; } },
              skills: { registerProvider(factory) { registeredSkillProvider = factory(); } },
              async plugin(plugin, cfg) { await plugin.apply(fakeCtx, cfg); },
            };
            await desktopOffice.apply(fakeCtx, officeConfig);

            if (!registeredTool || !registeredSkillProvider) {
              throw new Error("desktop-office failed to register tool or skill provider");
            }
            const skills = await registeredSkillProvider.list();
            if (skills.length !== 7) {
              throw new Error("Expected 7 office skills, got " + skills.length);
            }
            const resolvedPaths = await registeredTool.execute({});
            execFileSync(
              resolvedPaths.python,
              [
                "-I",
                "-B",
                "-c",
                "import decimal, xml.parsers.expat, lzma, uuid, numpy, pandas, docx, pptx, openpyxl, PIL, lxml, xlsxwriter; assert numpy.arange(4).sum() == 6; assert pandas.DataFrame({\"n\": [1, 2]}).n.sum() == 3",
              ],
              { stdio: "inherit" }
            );
            execFileSync(resolvedPaths.node, [resolvedPaths.pnpm, "--version"], { stdio: "inherit" });

            const prepared = profileMod.h("0", homeDir, "linux", undefined, undefined, undefined, {
              aaEnabled: false,
            });
            const releaseResolver = moduleRes.t(prepared.bareModuleBaseUrl);
            const pnpmBootstrap = {
              activeProfileName: "desktop",
              activeProfileDir: prepared.profile.dir,
              homeDir,
              appExecutable: process.execPath,
              pnpmBinPath: join(runtimeRoot, "node_modules/pnpm/bin/pnpm.mjs"),
              electronVersion: process.versions.electron,
              nodeBinDir: join(homeDir, "runtime-commands"),
              nodeShimPath: join(homeDir, "runtime-commands/node"),
              clearEnvironmentPath: join(homeDir, "runtime-commands/clear-env.cjs"),
              dshBootstrapPath: join(libDir, "desktop-cli.js"),
            };
            const runtime = {
              platform: "linux",
              locale: "en",
              updates: {
                isPackaged: true,
                canDownload: false,
                currentVersion: "${finalAttrs.version}",
                statePath: join(homeDir, "update-state.json"),
                request: async () => { throw new Error("unexpected"); },
                confirmDownload: async () => false,
                showManualCheckResult: async () => {},
                downloadAndOpen: async () => {},
                notify: () => {},
              },
              schedule() { return async () => {}; },
              async mountScheduled() {},
              show() {},
              registerTrayItem() { return { refresh() {}, dispose() {} }; },
              openTerminal() {},
              setLocalePreference() {},
              setThemeSource() {},
              async requestRestart() {},
              prepareToQuit() {},
            };
            const profileBoot = contextMod.t(prepared, pnpmBootstrap);
            const ctx = await appBoot.boot(
              "dsh-plugin-desktop",
              prepared.rootConfig,
              prepared.patches,
              async hostCtx => {
                profileBoot.prepare(hostCtx);
                hostCtx.loader.internal = undefined;
                await hostCtx.plugin(pluginPkgs.t);
                hostCtx.provide(
                  launchEnv.DSH_LAUNCH_ENVIRONMENT_KEY,
                  launchEnv.createLaunchEnvironmentSnapshot([])
                );
                hostCtx.provide("desktopBrowserAccess", {
                  ordinaryBrowserEnabled: false,
                  rendererHeader: { name: "x-dsh-desktop-renderer", value: "test" },
                  setOrdinaryBrowserEnabled() {},
                });
                hostCtx.provide("desktopLanHttps", {
                  caCertificate: null,
                  attach() {},
                  snapshot() {
                    return {
                      state: "inactive",
                      actualPort: null,
                      addresses: [],
                      caFingerprint: null,
                      errorCode: null,
                    };
                  },
                  async setEnabled() {},
                  async stop() {},
                });
                hostCtx.provide("desktopRuntime", runtime);
                hostCtx.provide("desktopPnpmBootstrap", pnpmBootstrap);
                await hostCtx.plugin(admission._, {
                  openTerminal() {},
                  requestRestart: async () => {},
                });
                await hostCtx.plugin(pluginsSvc.n, {
                  profileName: "desktop",
                  homeDir,
                  statePath: join(homeDir, "plugin-management.json"),
                  installAnchor: profileMod.s(),
                });
                await hostCtx.plugin(desktopOffice, officeConfig);
                await hostCtx.plugin(profileSvc.t, {
                  current: { name: "desktop", dir: prepared.profile.dir },
                  create: () => ({ name: "test", dir: prepared.profile.dir }),
                  list: () => [],
                  canDelete: () => false,
                  delete: async () => {},
                  persistSelection: () => {},
                  requestRestart: async () => {},
                });
                cmdline.provideCmdline(hostCtx, {
                  args: ["--host", "127.0.0.1", "--port", "0"],
                  exit: () => {},
                });
              },
              prepared.bareModuleBaseUrl
            );
            profileBoot.markReady();
            await ctx.fiber.dispose();
            releaseResolver();
            process.exit(0);
          '

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
