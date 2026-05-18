# Verification Report: escrcpy build

**Date:** 2026-05-17
**Task:** Verify escrcpy build and runtime dependencies.

## Verification Steps

### 1. Nix Build
- **Command:** `nix build .#\"es/escrcpy\"`
- **Result:** Success.
- **Output Path:** `/nix/store/xmpxpn0w4qkpm2va9q6fj6jq8cm0gncl-escrcpy-2.10.2`

### 2. Binary Existence
- **Command:** `ls -l result/bin/escrcpy`
- **Result:** Found.
- **Permissions:** `-r-xr-xr-x`

### 3. Runtime Libraries
- **Command:** `ldd result/share/escrcpy/escrcpy`
- **Result:** No "not found" libraries.
- **Internal Components Verified:**
  - `result/share/escrcpy/resources/extra/linux-x64/scrcpy/scrcpy`: OK
  - `result/share/escrcpy/resources/extra/linux-x64/gnirehtet/gnirehtet`: OK
  - `sharp-libvips`: OK
  - `node-pty`: OK

## Conclusion
The `escrcpy` package builds successfully and all identified runtime library dependencies are resolved.
