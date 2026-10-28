{
  lib,
  stdenv,
  fetchFromGitHub,
  nodejs_24,
  pnpm_11,
  pnpmConfigHook,
  fetchPnpmDeps,
  makeWrapper,
  python3,
  node-gyp,
  pkgsMusl,
  bash,
  git,
}:
let
  nodejs = nodejs_24;
  pnpm = pnpm_11.override { nodejs-slim = nodejs; };
in
stdenv.mkDerivation (
  finalAttrs:
  let
    sourceRevision =
      if builtins.stringLength finalAttrs.src.rev == 40 then
        finalAttrs.src.rev
      else
        builtins.hashString "sha1" finalAttrs.src.rev;
  in
  {
    pname = "deepseek-harness";
    # Tracks upstream releases; keep in sync with apps/cli/package.json at `rev`.
    version = "0.2.1-rc.3";

    src = fetchFromGitHub {
      owner = "deepseek-ai";
      repo = "deepseek-harness";
      rev = "dsh-v0.2.1-rc.3";
      hash = "sha256-wNwpit8WCjltafq+1JFTTFFbH05No60ImlmoJpVz2RQ=";
    };

    pnpmDeps = fetchPnpmDeps {
      inherit (finalAttrs) pname version src;
      inherit pnpm;
      fetcherVersion = 4;
      hash = "sha256-C9Aw9AS4r7zubaEuT6mLXQ+AhhMVlTxPZRKTpzRUkcU=";
      # pnpm 11 must use our locked manager, not download upstream's patch version.
      pnpm_config_pm_on_fail = "ignore";
    };

    # Keep the pinned Node and upstream loader checks; avoid unsupported native
    # accessor probing for internals already exposed by the runtime wrapper.
    patches = [ ./exposed-internals.patch ];

    nativeBuildInputs = [
      nodejs
      pnpm
      pnpmConfigHook
      makeWrapper
      python3
      node-gyp
    ];

    pnpm_config_pm_on_fail = "ignore";
    ELECTRON_SKIP_BINARY_DOWNLOAD = "1";
    PLAYWRIGHT_SKIP_BROWSER_DOWNLOAD = "1";
    LEFTHOOK = "0";
    # GitHub archives omit .git; upstream supports explicit client provenance.
    DSH_CLIENT_COMMIT_HASH = sourceRevision;
    npm_config_nodedir = nodejs;
    npm_config_python = "${python3}/bin/python3";

    postPatch = ''
      substituteInPlace packages/terminal/terminal-bash/src/config.ts \
        --replace-fail "DEFAULT_BASH_SHELL = '/bin/bash'" "DEFAULT_BASH_SHELL = '${bash}/bin/bash'"
      substituteInPlace native/system/scripts/build.ts \
        --replace-fail "'musl-gcc'" "'${pkgsMusl.stdenv.cc}/bin/cc'"
    '';

    preConfigure = ''
      export HOME="$TMPDIR/home"
      mkdir -p "$HOME"
      echo "dsh dependency install: $(command -v pnpm) $(pnpm --version)"
    '';

    buildPhase = ''
      runHook preBuild
      # Build the patched PTY against Nix's Node headers without fetching prebuilts.
      (
        cd node_modules/.pnpm/node-pty@*/node_modules/node-pty
        node-gyp rebuild
      )
      echo "dsh nested builds: $(command -v pnpm) $(pnpm --version)"
      pnpm run build
      # The aggregate build only builds the host flock addon, not the launcher.
      pnpm --dir native/system run build:native
      runHook postBuild
    '';

    installPhase = ''
      runHook preInstall
      mkdir -p "$out/lib/deepseek-harness" "$out/bin"
      cp -a . "$out/lib/deepseek-harness/"
      makeWrapper ${nodejs}/bin/node "$out/bin/dsh" \
        --prefix PATH : ${
          lib.makeBinPath [
            nodejs
            pnpm
            bash
            git
          ]
        } \
        --add-flags --expose-internals \
        --add-flags "$out/lib/deepseek-harness/apps/cli/lib/bin.js"
      mkdir -p "$out/share/deepseek-harness"
      printf '%s\n' ${
        lib.escapeShellArg (
          builtins.toJSON {
            inherit (finalAttrs) version;
            inherit sourceRevision;
          }
        )
      } \
        > "$out/share/deepseek-harness/source.json"
      runHook postInstall
    '';

    # Keep the complete workspace layout: built-in profiles resolve via apps/cli.
    dontStrip = true;

    passthru = {
      inherit pnpm;
      inherit sourceRevision;
    };

    meta = {
      description = "DeepSeek Harness agent CLI, built from source with mutable user plugin profiles";
      homepage = "https://github.com/deepseek-ai/deepseek-harness";
      license = lib.licenses.mit;
      maintainers = [ ];
      mainProgram = "dsh";
      platforms = [ "x86_64-linux" ];
    };
  }
)
