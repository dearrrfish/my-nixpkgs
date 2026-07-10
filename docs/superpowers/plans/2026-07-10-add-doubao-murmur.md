# Add doubao-murmur Package Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Package `doubao-murmur` (v1.4.5) for the `my-nixpkgs` overlay repository under the RFC 140 structure.

**Architecture:** Use `python3Packages.buildPythonApplication` with a specific `sourceRoot` pointing to the `linux` subdirectory. Integrate GObject introspection hooks and WebKitGTK 6.0 library to support WebKit-based authentication, and prepend essential runtime clipboard/key-simulation binaries to the wrapper's `PATH`.

**Tech Stack:** Nix, Python 3, PyGObject, Gtk4, WebKitGTK 6.0, sounddevice, websockets, pytest.

## Global Constraints

- **Location:** `pkgs/by-name/do/doubao-murmur/package.nix`.
- **Reproducibility:** Lock source revision to GitHub tag `v1.4.5` and verify hash `sha256-axQblvdvtX9XMLXpz4Kjq8BpNlEcVkOzwbQqfz5egCg=`.
- **Testing:** Ensure checkPhase runs the package's python tests using pytest.
- **Convention:** Use Conventional Commits.

______________________________________________________________________

### Task 1: Define doubao-murmur Derivation

**Files:**

- Create: `pkgs/by-name/do/doubao-murmur/package.nix`

**Interfaces:**

- Consumes: None

- Produces: `doubao-murmur` package definition

- [ ] **Step 1: Write the package derivation**
  Create the folder `pkgs/by-name/do/doubao-murmur` and write the following package definition code into `pkgs/by-name/do/doubao-murmur/package.nix`:

  ```nix
  { lib
  , python3Packages
  , fetchFromGitHub
  , gobject-introspection
  , wrapGAppsHook4
  , webkitgtk_6_0
  , wl-clipboard
  , xclip
  , xdotool
  , ydotool
  , wtype
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

    nativeBuildInputs = [
      gobject-introspection
      wrapGAppsHook4
    ];

    buildInputs = [
      webkitgtk_6_0
    ];

    propagatedBuildInputs = with python3Packages; [
      pygobject3
      websockets
      sounddevice
    ];

    nativeCheckInputs = with python3Packages; [
      pytestCheckHook
      pytest-asyncio
    ];

    # Prepend the paths of clipboard and simulation CLI tools to the environment wrapper's PATH
    makeWrapperArgs = [
      "--prefix PATH : ${lib.makeBinPath [ wl-clipboard xclip xdotool ydotool wtype ]}"
    ];

    meta = with lib; {
      description = "Voice-to-text input using Doubao ASR for SteamOS/Linux";
      homepage = "https://github.com/lilong7676/doubao-murmur";
      license = licenses.mit;
      maintainers = [ ];
      mainProgram = "doubao-murmur";
      platforms = platforms.linux;
    };
  }
  ```

- [ ] **Step 2: Verify registration in the Flake**
  Run: `nix eval .#packages.x86_64-linux."do/doubao-murmur".name`
  Expected output: `"doubao-murmur-1.4.5"`

- [ ] **Step 3: Commit derivation definition**
  Run:

  ```bash
  git add pkgs/by-name/do/doubao-murmur/package.nix
  git commit -m "feat(pkgs): add doubao-murmur package definition"
  ```

______________________________________________________________________

### Task 2: Build and Verify the Package

**Files:**

- Modify: `pkgs/by-name/do/doubao-murmur/package.nix` (if adjustments are needed)

**Interfaces:**

- Consumes: `pkgs/by-name/do/doubao-murmur/package.nix`

- Produces: Valid package build and clean flake checks

- [ ] **Step 1: Build the package**
  Run: `nix build .#doubao-murmur`
  Expected output: Builds successfully and creates a `result` symlink pointing to the output path.

- [ ] **Step 2: Format the code**
  Run: `nix fmt`
  Expected output: Code formatting is applied to the newly added file.

- [ ] **Step 3: Run full flake check**
  Run: `nix flake check`
  Expected output: `all checks passed!`

- [ ] **Step 4: Commit any adjustments**
  Run:

  ```bash
  git add pkgs/by-name/do/doubao-murmur/package.nix
  git commit -m "fix(pkgs): verify and format doubao-murmur derivation" || echo "No changes to commit"
  ```
