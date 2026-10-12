{
  lib,
  python3Packages,
  fetchFromGitHub,
}:

let
  version = "0.3.5";
  src = fetchFromGitHub {
    owner = "HKUDS";
    repo = "nanobot";
    rev = "v${version}";
    sha256 = "sha256-X+WyEMRTwO+y4M0agQQmH37alEL0kg5GqpD0Wy/wNoE=";
  };

  python = python3Packages.python.override {
    packageOverrides = import ./python-overrides.nix;
  };

in
python.pkgs.buildPythonApplication {
  pname = "nanobot";
  inherit version src;
  format = "pyproject";

  nativeBuildInputs = with python.pkgs; [
    hatchling
  ];

  dependencies = with python.pkgs; [
    anthropic
    chardet
    croniter
    ddgs
    defusedxml
    dulwich
    filelock
    httpx
    jinja2
    json-repair
    loguru
    lxml-html-clean
    mcp
    oauth-cli-kit
    openai
    openpyxl
    packaging
    pillow
    prompt-toolkit
    pydantic
    pydantic-settings
    pypdf
    python-docx
    python-pptx
    pyyaml
    qrcode
    questionary
    rapidfuzz
    readability-lxml
    rich
    setproctitle
    socksio
    tiktoken
    typer
    tzdata
    tzlocal
    watchfiles
    websockets
  ];

  env.NANOBOT_SKIP_WEBUI_BUILD = 1;

  pythonImportsCheck = [
    "nanobot.cli.commands"
    "nanobot.providers.openai_codex_provider"
  ];

  postInstallCheck = ''
    $out/bin/nanobot --version
    $out/bin/nanobot --help
  '';

  meta = with lib; {
    description = "A lightweight personal AI assistant framework";
    homepage = "https://github.com/HKUDS/nanobot";
    license = licenses.mit;
    maintainers = [ ];
  };
}
