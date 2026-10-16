_: {
  flake = {
    homeManagerModules = {
      default = ../modules/home-manager;
      askhuman = ../modules/home-manager/askhuman;
    };
    nixosModules.default = ../modules/nixos;
  };
}
