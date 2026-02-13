{
  lib,
  stdenv,
  fetchurl,
}:
let
  version = "6.8.14";
  sources = {
    x86_64-linux = {
      url = "https://github.com/router-for-me/CLIProxyAPI/releases/download/v${version}/CLIProxyAPI_${version}_linux_amd64.tar.gz";
      hash = "sha256-SaatkdZ1VdxeIMbEnizfnUC2b3J5FS+WkZY+VXyvLew=";
    };
    aarch64-linux = {
      url = "https://github.com/router-for-me/CLIProxyAPI/releases/download/v${version}/CLIProxyAPI_${version}_linux_arm64.tar.gz";
      hash = "sha256-w3xita6444jxxk8zlMNNcadzo1r/9vW9PBl1wKiSpCg=";
    };
  };
  srcConfig =
    sources.${stdenv.hostPlatform.system}
      or (throw "Unsupported system: ${stdenv.hostPlatform.system}");
in
stdenv.mkDerivation {
  pname = "cli-proxy-api";
  inherit version;

  src = fetchurl {
    inherit (srcConfig) url hash;
  };

  sourceRoot = ".";

  installPhase = ''
    runHook preInstall

    install -Dm755 cli-proxy-api $out/bin/cli-proxy-api
    install -Dm644 config.example.yaml $out/share/doc/cli-proxy-api/config.example.yaml

    runHook postInstall
  '';

  meta = with lib; {
    description = "Proxy server providing OpenAI/Gemini/Claude compatible API interfaces";
    homepage = "https://github.com/router-for-me/CLIProxyAPI";
    license = licenses.mit;
    platforms = [
      "x86_64-linux"
      "aarch64-linux"
    ];
    mainProgram = "cli-proxy-api";
  };
}
