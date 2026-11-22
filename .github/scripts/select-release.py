"""Select the newest complete release for a package from paginated GitHub JSON."""

import base64
import json
from pathlib import Path
import re
import sys


VERSION = r"v([0-9]+)\.([0-9]+)\.([0-9]+)"
DESKTOP = {
    "dsh-desktop": ("", "DSH-Desktop", False),
    "dsh-desktop-next": ("-next", "DSH-NEXT", False),
    "dsh-desktop-beta": (r"-beta\.([0-9]+)", "DSH-Desktop-Beta", True),
}


def select(package: str, pages: list) -> tuple[str, dict[str, str]] | None:
    suffix, prefix, prerelease = DESKTOP[package]
    candidates = []
    for page in pages:
        for release in page:
            tag = release["tag_name"]
            match = re.fullmatch(VERSION + suffix, tag)
            if not match or release["draft"] or release["prerelease"] != prerelease:
                continue
            version = tag[1:]
            assets = {
                asset["name"]: asset
                for asset in release["assets"]
                if asset["state"] == "uploaded"
            }
            names = {
                arch: f"{prefix}-{version}-{arch}.deb" for arch in ("amd64", "arm64")
            }
            if not all(name in assets for name in names.values()):
                continue
            hashes = {arch: assets[name].get("digest") for arch, name in names.items()}
            candidates.append((tuple(map(int, match.groups())), version, hashes))
    if not candidates:
        return None
    _, version, hashes = max(candidates, key=lambda candidate: candidate[0])
    return version, hashes


def version_key(version: str) -> tuple[int, ...]:
    return tuple(map(int, re.findall(r"[0-9]+", version)))


def main() -> None:
    package, current_or_path = sys.argv[1:]
    release = select(package, json.load(sys.stdin))
    if release is None:
        return
    version, digests = release
    pins = Path(current_or_path)
    current = json.loads(pins.read_text(encoding="utf-8"))["version"]
    if version_key(version) <= version_key(current):
        return
    hashes = {}
    for arch, digest in digests.items():
        if not isinstance(digest, str) or not re.fullmatch(
            r"sha256:[0-9a-f]{64}", digest
        ):
            raise ValueError(
                f"{package} {version} has no valid SHA-256 digest for {arch}"
            )
        hashes[arch] = "sha256-" + base64.b64encode(bytes.fromhex(digest[7:])).decode(
            "ascii"
        )
    pins.write_text(
        json.dumps({"version": version, "hashes": hashes}, indent=2) + "\n",
        encoding="utf-8",
    )
    print(version)


if __name__ == "__main__":
    main()
