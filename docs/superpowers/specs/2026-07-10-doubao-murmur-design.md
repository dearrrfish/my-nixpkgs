# Design Spec: Add doubao-murmur package to my-nixpkgs

## 1. Overview

This design document describes the packaging of `doubao-murmur` (v1.4.5) into the `my-nixpkgs` overlay repository.
`doubao-murmur` is a minimalist voice input tool for Linux/SteamOS using Doubao Web Voice Recognition.

## 2. Requirements & Scope

- Package the latest version `v1.4.5` from source.
- Adhere to the `pkgs/by-name` convention (RFC 140).
- Expose runtime dependencies (`wl-clipboard`, `xclip`, `xdotool`, `ydotool`, `wtype`) in the executable's `PATH`.

## 3. Design & Architecture

The package is built as a standard Python application using Gtk4, GObject-Introspection, and WebKitGTK 6.0.

- **File Path**: `pkgs/by-name/do/doubao-murmur/package.nix`
- **Builder**: `python3Packages.buildPythonApplication`
- **Subdirectory**: `sourceRoot = "source/linux"` (as `pyproject.toml` is under `linux/`)
- **Native Build Inputs**:
  - [gobject-introspection](https://nixos.org/manual/nixpkgs/unstable/#sec-gobject-introspection)
  - [wrapGAppsHook4](https://nixos.org/manual/nixpkgs/unstable/#hooks-gapps)
- **Build Inputs**:
  - `webkitgtk_6_0`
- **Python Dependencies**:
  - `python3Packages.pygobject3`
  - `python3Packages.websockets`
  - `python3Packages.sounddevice`
- **Wrapper Customization**: Prepend `PATH` with:
  - `wl-clipboard`
  - `xclip`
  - `xdotool`
  - `ydotool`
  - `wtype`

## 4. Verification Plan

1. Run `nix build .#doubao-murmur` to compile and construct the derivation.
1. Run `nix flake check` to verify metadata and flake validity.
1. Format with `nix fmt`.
