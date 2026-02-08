{
  lib,
  python3Packages,
  fetchFromGitHub,
  buildNpmPackage,
}:

let
  version = "0.1.3.post4";
  src = fetchFromGitHub {
    owner = "HKUDS";
    repo = "nanobot";
    rev = "v${version}";
    sha256 = "0f1y5b1qzzxjdjmn6fhj238pvzk9m3myjkxm5x199h99ranfwmza";
  };

  # Helper to build the bridge
  nanobot-bridge = buildNpmPackage {
    pname = "nanobot-bridge";
    inherit version src;

    sourceRoot = "${src.name}/bridge";

    # We use the lockfile we generated/copied
    postPatch = ''
      cp ${./package-lock.json} package-lock.json
    '';

    # TODO: UPDATE THIS HASH
    # Run `nix build` and replace this with the actual hash from the error message.
    npmDepsHash = "sha256-hi9hRJTzVIEAImHQGJEMM7heGcyaukS2EnpYb2NY+jY=";

    makeCacheWritable = true;

    # We need to build the typescript
  };

  readability-lxml = python3Packages.buildPythonPackage rec {
    pname = "readability-lxml";
    version = "0.8.1";
    format = "setuptools";

    src = python3Packages.fetchPypi {
      inherit pname version;
      sha256 = "1qd4n4jlvadw11ypnmpsb8jr6qh9kvklhz9hdn4az6lhnmbfl7z5";
    };

    doCheck = false;
    propagatedBuildInputs = with python3Packages; [
      lxml
      cssselect
    ];
  };

in
python3Packages.buildPythonApplication {
  pname = "nanobot";
  inherit version src;
  format = "pyproject";

  nativeBuildInputs = with python3Packages; [
    hatchling
  ];

  propagatedBuildInputs = with python3Packages; [
    typer
    litellm
    pydantic
    pydantic-settings
    websockets
    websocket-client
    httpx
    loguru
    rich
    croniter
    python-telegram-bot
    readability-lxml
  ];

  # The pyproject.toml expects 'bridge' to be copied to 'nanobot/bridge'.
  # Since hatchling handles this during build if the files are present,
  # we need to make sure the 'bridge' folder is populated in the source before build.
  # However, we want to use our PRE-BUILT bridge from nix, not let hatchling try to build it (it can't run npm).

  # Actually, hatchling just copies files. It doesn't run npm install.
  # But the bridge code expects `dist/index.js` etc.
  # So we should copy our built bridge into the source tree before python build.

  preBuild = ''
    # Remove existing bridge source (typescript) and replace with built artifacts
    rm -rf bridge
    mkdir bridge

    # Copy the built bridge files (dist, package.json, etc)
    cp -r ${nanobot-bridge}/lib/node_modules/nanobot-whatsapp-bridge/* bridge/
  '';

  meta = with lib; {
    description = "A lightweight personal AI assistant framework";
    homepage = "https://github.com/HKUDS/nanobot";
    license = licenses.mit;
    maintainers = [ ];
  };
}
