# Design Doc: escrcpy Nix Package

**Feature Name:** escrcpy Nix Package
**Date:** 2026-05-17
**Status:** Draft

## 1. Goal
Add a Nix package for `escrcpy`, a graphical interface for `scrcpy` built with Electron. The package will use pre-built binaries from GitHub releases to support Linux across x86_64 and aarch64 architectures.

## 2. Success Criteria
- `nix build .#escrcpy` succeeds on Linux (x86_64/aarch64).
- The binary `escrcpy` is available in the user's PATH.
- The application launches and correctly detects `scrcpy` and `adb` when they are available in the system PATH.

## 3. Architecture
The package will be a standard Nix derivation using `stdenv.mkDerivation`.

### Source Selection
- **Linux:** Use `.deb` packages for easy extraction and patching.

### Build Steps
1. **Fetch:** Use `fetchurl` to download the asset corresponding to the current system's architecture.
2. **Unpack:** 
   - Linux: Use `dpkg-deb -x` (provided by `dpkg`).
3. **Install:**
   - Linux: Move extracted files to `$out`.
4. **Fixup:**
   - Use `autoPatchelfHook` to resolve dynamic library dependencies.
   - Use `wrapGAppsHook3` to handle GTK and desktop integration.
   - Add necessary libraries to `buildInputs` (e.g., `nss`, `nspr`, `mesa`, `alsa-lib`, etc.).
5. **Wrapping:**
   - Create a symlink or wrapper script at `$out/bin/escrcpy` pointing to the main executable.

## 4. Components
- **`pkgs/by-name/es/escrcpy/package.nix`**: The Nix derivation.

## 5. Testing Strategy
1. **Build Verification:** Run `nix build .#escrcpy` on available platforms.
2. **Runtime Verification:** Run `nix run .#escrcpy -- --help` (or equivalent) to ensure the binary executes.
3. **Dependency Check:** Verify that the app starts even if `scrcpy`/`adb` are missing (it should show a configuration UI).

## 6. Security & Reproducibility
- Use fixed-output derivations with hashes for all downloads.
- No network access during the build phase.
