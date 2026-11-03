{
  lib,
  stdenvNoCC,
  fetchurl,
  makeWrapper,
  nodejs_24,
  pnpm_11,
  deepseek-harness ? null,
  bash,
  git,
}:
stdenvNoCC.mkDerivation (finalAttrs: {
  pname = "dsh-tui";
  version = "0.18.0";

  src = fetchurl {
    url = "https://registry.npmjs.org/@deepseek-harness-tui/dsh-tui/-/dsh-tui-${finalAttrs.version}.tgz";
    hash = "sha256-k7iKzV/1kEP4sl7yg1FECKLMIb/l9E5zQJtfIRE+Xs8=";
  };

  sourceRoot = "package";

  nativeBuildInputs = [ makeWrapper ];

  installPhase = ''
    runHook preInstall

    mkdir -p "$out/lib/dsh-tui" "$out/bin"
    cp -a . "$out/lib/dsh-tui/"

    makeWrapper ${nodejs_24}/bin/node "$out/bin/dsh-tui" \
      --prefix PATH : ${
        lib.makeBinPath (
          [
            nodejs_24
            pnpm_11
            bash
            git
          ]
          ++ lib.optional (deepseek-harness != null) deepseek-harness
        )
      } \
      --add-flags "$out/lib/dsh-tui/bin/dsh-tui.js"

    ln -s dsh-tui "$out/bin/dst"

    runHook postInstall
  '';

  meta = {
    description = "Interactive terminal UI for DeepSeek Harness agents, sessions and tools";
    homepage = "https://github.com/ccch1mneyyy/dsh-TUI";
    license = lib.licenses.mit;
    mainProgram = "dsh-tui";
    platforms = [ "x86_64-linux" ];
  };
})
