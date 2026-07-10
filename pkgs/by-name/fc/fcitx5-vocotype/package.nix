{
  lib,
  stdenv,
  fetchFromGitHub,
  cmake,
  extra-cmake-modules,
  pkg-config,
  fcitx5,
  nlohmann_json,
  python312,
  portaudio,
  libsndfile,
  librime,
  alsa-lib,
  pulseaudio,
  pipewire,
  zlib,
}:

let
  autopxd2-override = python312.pkgs.autopxd2.overridePythonAttrs (_oldAttrs: {
    doCheck = false;
  });

  pyrime = python312.pkgs.buildPythonPackage rec {
    pname = "pyrime";
    version = "0.2.3";
    format = "pyproject";

    src = python312.pkgs.fetchPypi {
      inherit pname version;
      sha256 = "1v17hsprhhh7phjn7jwcg84qxa2sp6sjwdiiz2hk16cnyqr4941k";
    };

    nativeBuildInputs = [
      python312.pkgs.meson-python
      python312.pkgs.cython
      autopxd2-override
      pkg-config
    ];

    buildInputs = [
      librime
    ];

    propagatedBuildInputs = [
      python312.pkgs.platformdirs
      python312.pkgs.wcwidth
    ];
  };

  pythonEnv = python312.withPackages (_ps: [ pyrime ]);
in
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

            mkdir -p $out/bin

            # Write backend wrapper
            cat << EOF > $out/bin/vocotype-fcitx5-backend
      #!/usr/bin/env bash
      # Perform venv and dependency checks
      VENV_DIR="\$HOME/.cache/vocotype-fcitx5/venv"
      PYTHON_BIN="\$VENV_DIR/bin/python"

      if [ ! -f "\$PYTHON_BIN" ]; then
        echo "Initializing VocoType Python virtualenv in \$VENV_DIR..."
        mkdir -p "\$(dirname "\$VENV_DIR")"
        ${python312}/bin/python3 -m venv "\$VENV_DIR"
        "\$PYTHON_BIN" -m pip install --upgrade pip
      fi

      if ! "\$PYTHON_BIN" -c "import sounddevice, librosa, soundfile, funasr_onnx, jieba, modelscope" &>/dev/null; then
        echo "Installing Python dependencies (sounddevice, librosa, soundfile, funasr-onnx, jieba, modelscope)..."
        "\$PYTHON_BIN" -m pip install sounddevice librosa soundfile funasr-onnx jieba modelscope
      fi

      # Inject paths
      export LD_LIBRARY_PATH="${libPath}\''${LD_LIBRARY_PATH:+:\$LD_LIBRARY_PATH}"
      export PYTHONPATH="${pythonEnv}/${python312.sitePackages}\''${PYTHONPATH:+:\$PYTHONPATH}"

      # Directly exec the virtualenv python with the target script path
      exec "\$PYTHON_BIN" "$out/share/vocotype-fcitx5/backend/fcitx5_server.py" "\$@"
      EOF
            chmod +x $out/bin/vocotype-fcitx5-backend

            # Write recorder wrapper
            cat << EOF > $out/bin/vocotype-fcitx5-recorder
      #!/usr/bin/env bash
      VENV_DIR="\$HOME/.cache/vocotype-fcitx5/venv"
      PYTHON_BIN="\$VENV_DIR/bin/python"

      if [ ! -f "\$PYTHON_BIN" ]; then
        echo "Error: VocoType virtualenv not initialized. Please start vocotype-fcitx5-backend first." >&2
        exit 1
      fi

      # Inject paths
      export LD_LIBRARY_PATH="${libPath}\''${LD_LIBRARY_PATH:+:\$LD_LIBRARY_PATH}"
      export PYTHONPATH="${pythonEnv}/${python312.sitePackages}\''${PYTHONPATH:+:\$PYTHONPATH}"

      # Directly exec the virtualenv python with the target script path
      exec "\$PYTHON_BIN" "$out/share/vocotype-fcitx5/backend/audio_recorder.py" "\$@"
      EOF
            chmod +x $out/bin/vocotype-fcitx5-recorder
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
