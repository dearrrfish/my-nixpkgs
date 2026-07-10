{
  lib,
  python3Packages,
  fetchFromGitHub,
  gobject-introspection,
  wrapGAppsHook4,
  webkitgtk_6_0,
  wl-clipboard,
  xclip,
  xdotool,
  ydotool,
  wtype,
}:

python3Packages.buildPythonApplication rec {
  pname = "doubao-murmur";
  version = "1.4.5";

  src = fetchFromGitHub {
    owner = "lilong7676";
    repo = "doubao-murmur";
    rev = "v${version}";
    hash = "sha256-axQblvdvtX9XMLXpz4Kjq8BpNlEcVkOzwbQqfz5egCg=";
  };

  sourceRoot = "source/linux";

  pyproject = true;

  postPatch = ''
    substituteInPlace pyproject.toml \
      --replace-warn 'build-backend = "setuptools.backends._legacy:_Backend"' 'build-backend = "setuptools.build_meta"'
  '';

  build-system = [
    python3Packages.setuptools
    python3Packages.wheel
  ];

  nativeBuildInputs = [
    gobject-introspection
    wrapGAppsHook4
  ];

  buildInputs = [
    webkitgtk_6_0
  ];

  dependencies = with python3Packages; [
    pygobject3
    websockets
    sounddevice
  ];

  nativeCheckInputs = with python3Packages; [
    pytestCheckHook
    pytest-asyncio
  ];

  pytestFlagsArray = [ "--asyncio-mode=auto" ];

  # Suppress wrapGAppsHook4's own wrapping; merge its args into Python's makeWrapper
  dontWrapGApps = true;

  # Prepend the paths of clipboard and simulation CLI tools to the environment wrapper's PATH
  makeWrapperArgs = [
    "--prefix PATH : ${
      lib.makeBinPath [
        wl-clipboard
        xclip
        xdotool
        ydotool
        wtype
      ]
    }"
  ];

  preFixup = ''
    makeWrapperArgs+=("''${gappsWrapperArgs[@]}")
  '';

  meta = with lib; {
    description = "Voice-to-text input using Doubao ASR for SteamOS/Linux";
    homepage = "https://github.com/lilong7676/doubao-murmur";
    license = licenses.mit;
    maintainers = [ ];
    mainProgram = "doubao-murmur";
    platforms = platforms.linux;
  };
}
