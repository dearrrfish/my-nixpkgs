{
  inputs,
  pkgs,
  system,
}:
let
  inherit (pkgs) lib;
  standalonePkgs = import inputs.nixpkgs { inherit system; };
  home = inputs.home-manager.lib.homeManagerConfiguration {
    pkgs = standalonePkgs;
    modules = [
      inputs.self.homeManagerModules.default
      {
        home.username = "module-test";
        home.homeDirectory = "/home/module-test";
        home.stateVersion = "26.05";
      }
    ];
  };
  evaluates = configuration: (builtins.tryEval configuration.activationPackage.drvPath).success;
  nixos = inputs.nixpkgs.lib.nixosSystem {
    system = "x86_64-linux";
    modules = [
      inputs.self.nixosModules.default
      {
        networking.hostName = "module-test";
        system.stateVersion = "26.05";
        boot.loader.grub.enable = false;
        fileSystems."/" = {
          device = "/dev/disk/by-label/root";
          fsType = "ext4";
        };
      }
    ];
  };
  expectedPackages = [
    "cl/cli-proxy-api"
    "de/deepseek-harness"
    "do/doubao-murmur"
    "ds/dsh-desktop"
    "ds/dsh-desktop-beta"
    "ds/dsh-desktop-next"
    "ds/dsh-tui"
    "es/escrcpy"
    "fc/fcitx5-vocotype"
    "fr/freecontrol2"
    "ma/magpie"
  ];
  overlayPkgs = import inputs.nixpkgs {
    inherit system;
    overlays = [ inputs.self.overlays.default ];
  };
  results = {
    homeManagerAggregation = evaluates home;
    retiredPackageAbsent =
      !(inputs.self.packages.${system} ? "as/askhuman")
      && !(inputs.self.packages.${system} ? "as/askhuman-my");
    standalonePkgsHasNoConsumerOverlay = !(standalonePkgs ? local);
    nixosAggregation =
      nixos.config.networking.hostName == "module-test"
      && builtins.isString nixos.config.system.build.toplevel.drvPath;
    packageNames = builtins.attrNames inputs.self.packages.${system} == expectedPackages;
    overlayNames = builtins.attrNames overlayPkgs.local == expectedPackages;
  };
  failures = builtins.attrNames (lib.filterAttrs (_: passed: !passed) results);
in
assert lib.assertMsg (
  failures == [ ]
) "Module evaluation failed: ${lib.concatStringsSep ", " failures}";
pkgs.runCommand "module-eval"
  {
    evidence = builtins.toJSON {
      inherit system results;
      homeManagerActivation = builtins.unsafeDiscardStringContext home.activationPackage.drvPath;
      nixosSystem = builtins.unsafeDiscardStringContext nixos.config.system.build.toplevel.drvPath;
    };
  }
  ''
    mkdir -p "$out"
    printf '%s\n' "$evidence" > "$out/results.json"
  ''
