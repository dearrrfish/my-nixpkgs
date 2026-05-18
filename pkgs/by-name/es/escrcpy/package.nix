{ lib, stdenv, fetchurl, dpkg }:
stdenv.mkDerivation {
  pname = "escrcpy";
  version = "2.10.2";
  src = fetchurl {
    url = "https://github.com/viarotel-org/escrcpy/releases/download/v2.10.2/Escrcpy-2.10.2-linux-amd64.deb";
    hash = "sha256-K6ieDMumPRaj40D85uPqozBhUyHUGLIYt8H2kF/6Rd0=";
  };

  nativeBuildInputs = [ dpkg ];

  unpackPhase = "dpkg -x $src .";

  installPhase = ''
    mkdir -p $out
    cp -r usr/* $out/
  '';

  meta = with lib; {
    description = "A graphical interface for scrcpy built with Electron";
    homepage = "https://github.com/viarotel-org/escrcpy";
    license = licenses.gpl3Only;
    mainProgram = "escrcpy";
  };
}
