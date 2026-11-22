_: {
  flake = {
    homeManagerModules = {
      default = ../modules/home-manager;
    };
    nixosModules.default = ../modules/nixos;
  };
}
