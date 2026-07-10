# Design Spec: fcitx5-vocotype Packaging in Nix

- **Date:** 2026-07-10
- **Package Name:** `fcitx5-vocotype`
- **Location:** [pkgs/by-name/fc/fcitx5-vocotype/package.nix](file:///home/yjin/codes/my-nixpkgs/pkgs/by-name/fc/fcitx5-vocotype/package.nix)

---

## 1. Overview
[VocoType-linux](https://github.com/LeonardNJU/VocoType-linux) is a high-performance offline Chinese voice input method that supports Fcitx5 and Rime. It is composed of a C++ Fcitx5 addon client and a Python backend server that performs FunASR transcription, Rime input handling, and optional LLM/SLM text polishing.

The goal is to package the C++ Addon in Nix, along with automated backend scripts, while keeping dynamic Python dependencies outside of Nix's read-only sandbox.

---

## 2. Package Architecture & Nix Integration

The package `fcitx5-vocotype` will be structured in Nix as follows:

```mermaid
graph TD
    Fcitx5[Fcitx5 Input Framework] -->|Loads| Addon[C++ Addon: vocotype.so]
    Addon -->|Launches| RecWrapper[vocotype-fcitx5-recorder]
    RecWrapper -->|Runs| RecPy[audio_recorder.py]
    Systemd[Systemd User Service] -->|Launches| BackWrapper[vocotype-fcitx5-backend]
    BackWrapper -->|Runs| ServPy[fcitx5_server.py]
    
    subgraph Nix Store (Read-Only)
        Addon
        RecWrapper
        BackWrapper
        PySrc[Python Backend Source Code]
    end
    
    subgraph User Directory (Writable)
        Venv[Python Virtualenv: ~/.cache/vocotype-fcitx5/venv]
        Cache[FunASR/SLM Models: ~/.cache/modelscope]
        Socket[IPC Socket: /tmp/vocotype-fcitx5.sock]
        Rime[Rime Schemes: ~/.local/share/fcitx5/rime]
    end
    
    RecPy -->|Writes audio to| TempWav[/tmp/vocotype_input.wav]
    ServPy -->|Listens on| Socket
    Addon -->|Communicates via| Socket
    ServPy -->|Uses| Venv
    ServPy -->|Loads| Cache
    ServPy -->|Reads| Rime
```

---

## 3. Implementation Details

### A. C++ Addon Build & Configuration
1. **Subdirectory:** Build inside `fcitx5/addon` using CMake.
2. **Dependencies:**
   - `cmake`, `extra-cmake-modules`, `pkg-config` (native build inputs).
   - `fcitx5`, `nlohmann_json` (build inputs).
3. **Patching Recorder Path:**
   We will patch `fcitx5/addon/vocotype.cpp` to execute the recorder wrapper directly from the Nix store instead of searching in `~/.local/bin/`:
   ```cpp
   // Before patch
   recorder_launcher_path_ = std::string(home) + "/.local/bin/vocotype-fcitx5-recorder";
   // After patch
   recorder_launcher_path_ = "@recorder_path@";
   ```
   During the derivation build, we will replace `@recorder_path@` with `$out/bin/vocotype-fcitx5-recorder`.

4. **Addon Config Files:**
   The package will manually copy the required addon metadata to Fcitx5 directories:
   - `fcitx5/data/vocotype.conf` $\rightarrow$ `$out/share/fcitx5/addon/vocotype.conf`
   - `fcitx5/data/vocotype.conf.in` (renamed to `vocotype.conf`) $\rightarrow$ `$out/share/fcitx5/inputmethod/vocotype.conf`

### B. Python Backend Wrapper Scripts (`bin/`)
We will generate two wrapper scripts in `$out/bin/` to manage the virtualenv and dynamically bind Nix shared libraries on the user's host system:

#### 1. `vocotype-fcitx5-backend`
This wrapper runs the backend server:
```bash
#!/usr/bin/env bash
set -euo pipefail

VENV_DIR="$HOME/.cache/vocotype-fcitx5/venv"
PYTHON_BIN="$VENV_DIR/bin/python"

# 1. Initialize venv if not exists
if [ ! -f "$PYTHON_BIN" ]; then
  echo "Initializing VocoType Python virtualenv in $VENV_DIR..."
  mkdir -p "$(dirname "$VENV_DIR")"
  @python3@ -m venv "$VENV_DIR"
  "$PYTHON_BIN" -m pip install --upgrade pip
fi

# 2. Check and install dependencies if missing
if ! "$PYTHON_BIN" -c "import funasr_onnx, pyrime, sounddevice" &>/dev/null; then
  echo "Installing Python dependencies (FunASR, PyRime, sounddevice, soundfile, etc.)..."
  "$PYTHON_BIN" -m pip install -r @package_src@/requirements.txt pyrime
fi

# 3. Inject standard Native Libraries for PyPI wheels on NixOS
export LD_LIBRARY_PATH="@libPath@:$LD_LIBRARY_PATH"

# 4. Exec the Python backend script
exec "$PYTHON_BIN" "@package_src@/fcitx5/backend/fcitx5_server.py" "$@"
```

#### 2. `vocotype-fcitx5-recorder`
This wrapper runs the recording script for the C++ client:
```bash
#!/usr/bin/env bash
set -euo pipefail

VENV_DIR="$HOME/.cache/vocotype-fcitx5/venv"
PYTHON_BIN="$VENV_DIR/bin/python"

# Inject standard Native Libraries
export LD_LIBRARY_PATH="@libPath@:$LD_LIBRARY_PATH"

# Exec the Python recorder script
exec "$PYTHON_BIN" "@package_src@/fcitx5/backend/audio_recorder.py" "$@"
```

### C. Native Library Paths (`LD_LIBRARY_PATH`)
To ensure PyPI-installed wheels (which expect standard dynamic linkers and shared libraries) run perfectly on NixOS, we bind the following packages in `@libPath@`:
* `stdenv.cc.cc.lib` (C++ runtime: `libstdc++.so.6`, `libgcc_s.so.1`)
* `zlib`
* `portaudio` (required by `sounddevice`)
* `libsndfile` (required by `soundfile`)
* `librime` (required by `pyrime`)
* `alsa-lib`, `libpulseaudio`, `pipewire` (audio interface compatibility)

---

## 4. How to Use with Home Manager

We will document the configuration format for Home Manager:

```nix
# home.nix
{ pkgs, ... }: {
  # 1. Add the custom addon to Fcitx5
  i18n.inputMethod = {
    enabled = "fcitx5";
    fcitx5.addons = [
      pkgs.fcitx5-vocotype
    ];
  };

  # 2. Enable backend server autostart
  systemd.user.services.vocotype-fcitx5-backend = {
    Unit = {
      Description = "VoCoType Fcitx5 Backend Service";
      After = [ "graphical-session.target" ];
    };
    Service = {
      Type = "simple";
      ExecStart = "${pkgs.fcitx5-vocotype}/bin/vocotype-fcitx5-backend";
      Restart = "always";
      RestartSec = "5s";
      Environment = "PYTHONIOENCODING=UTF-8";
    };
    Install = {
      WantedBy = [ "default.target" ];
    };
  };
}
```
