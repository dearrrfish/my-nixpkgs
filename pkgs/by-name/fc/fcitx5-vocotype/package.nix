{
  lib,
  stdenv,
  fetchFromGitHub,
  cmake,
  extra-cmake-modules,
  pkg-config,
  fcitx5,
  nlohmann_json,
  python3,
  makeWrapper,
  portaudio,
  libsndfile,
  librime,
  alsa-lib,
  pulseaudio,
  pipewire,
  zlib,
}:

stdenv.mkDerivation rec {
  pname = "fcitx5-vocotype";
  version = "2.2.3";

  src = fetchFromGitHub {
    owner = "LeonardNJU";
    repo = "VocoType-linux";
    rev = "b7ef3df198c059be61d191f938a988eafc93433a";
    hash = "sha256-EsDDm1Ux5sg51Uz60yxk75Cd5j1lV5kAv2sdUuImrdQ=";
  };

  sourceRoot = "${src.name}/fcitx5/addon";

  nativeBuildInputs = [
    cmake
    extra-cmake-modules
    pkg-config
    makeWrapper
  ];

  buildInputs = [
    fcitx5
    nlohmann_json
  ];

  postPatch = ''
    substituteInPlace vocotype.cpp \
      --replace-fail 'std::string(home) + "/.local/bin/vocotype-fcitx5-recorder"' '"'"$out"'/bin/vocotype-fcitx5-recorder"'
  '';

  postInstall =
    let
      libPath = lib.makeLibraryPath [
        stdenv.cc.cc.lib
        zlib
        portaudio
        libsndfile
        librime
        alsa-lib
        pulseaudio
        pipewire
      ];
    in
    ''
      # Copy addon configs
      mkdir -p $out/share/fcitx5/addon
      mkdir -p $out/share/fcitx5/inputmethod
      cp $src/fcitx5/data/vocotype.conf $out/share/fcitx5/addon/vocotype.conf
      cp $src/fcitx5/data/vocotype.conf.in $out/share/fcitx5/inputmethod/vocotype.conf

      # Copy backend scripts and requirements.txt
      mkdir -p $out/share/vocotype-fcitx5
      cp -r $src/app $out/share/vocotype-fcitx5/
      cp -r $src/fcitx5/backend $out/share/vocotype-fcitx5/
      cp $src/requirements.txt $out/share/vocotype-fcitx5/
      cp $src/vocotype_version.py $out/share/vocotype-fcitx5/

      # Write backend wrapper
      makeWrapper ${python3}/bin/python3 $out/bin/vocotype-fcitx5-backend \
        --prefix LD_LIBRARY_PATH : "${libPath}" \
        --run '
          VENV_DIR="$HOME/.cache/vocotype-fcitx5/venv"
          PYTHON_BIN="$VENV_DIR/bin/python"
          if [ ! -f "$PYTHON_BIN" ]; then
            echo "Initializing VocoType Python virtualenv in $VENV_DIR..."
            mkdir -p "$(dirname "$VENV_DIR")"
            ${python3}/bin/python3 -m venv "$VENV_DIR"
            "$PYTHON_BIN" -m pip install --upgrade pip
          fi
          if ! "$PYTHON_BIN" -c "import funasr_onnx, pyrime, sounddevice" &>/dev/null; then
            echo "Installing Python dependencies (FunASR, PyRime, sounddevice, soundfile, etc.)..."
            "$PYTHON_BIN" -m pip install -r '$out'/share/vocotype-fcitx5/requirements.txt pyrime
          fi
        ' \
        --add-flags "$out/share/vocotype-fcitx5/backend/fcitx5_server.py"

      # Write recorder wrapper
      makeWrapper ${python3}/bin/python3 $out/bin/vocotype-fcitx5-recorder \
        --prefix LD_LIBRARY_PATH : "${libPath}" \
        --run '
          VENV_DIR="$HOME/.cache/vocotype-fcitx5/venv"
          PYTHON_BIN="$VENV_DIR/bin/python"
        ' \
        --add-flags "$out/share/vocotype-fcitx5/backend/audio_recorder.py"
    '';

  meta = with lib; {
    description = "High-performance offline Chinese speech input method for Fcitx5";
    homepage = "https://github.com/LeonardNJU/VocoType-linux";
    license = licenses.mit;
    platforms = platforms.linux;
    maintainers = [ ];
    mainProgram = "vocotype-fcitx5-backend";
  };
}
