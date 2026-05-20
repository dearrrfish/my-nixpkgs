{ inputs, lib, ... }:

{
  perSystem =
    { config, system, ... }:
    {
      _module.args.pkgs = import inputs.nixpkgs {
        inherit system;
        config.allowUnfreePredicate = pkg: builtins.elem (lib.getName pkg) [
          "android-sdk-platform-tools"
          "platform-tools"
        ];
        overlays = [
          (_final: _prev: {
            local = config.packages;
          })
        ];
      };
    };
}
