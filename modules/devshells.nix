{ inputs, ... }:
{
  imports = [ inputs.make-shell.flakeModules.default ];

  perSystem =
    { pkgs, ... }:
    {
      make-shells.default = {
        packages = [
        ];
        shellHook = ''
          ${pkgs.figlet}/bin/figlet "Dev shell"
          echo "Welcome to the development shell, all the tools you need are here!"
        '';
      };
    };
}
