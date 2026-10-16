{ inputs, ... }:
{
  perSystem =
    { pkgs, lib, ... }:
    let
      evaluated = inputs.home-manager.lib.homeManagerConfiguration {
        inherit pkgs;
        modules = [
          inputs.self.homeManagerModules.default
          {
            home.username = "module-docs";
            home.homeDirectory = "/home/module-docs";
            home.stateVersion = "26.05";
          }
        ];
      };
      optionsDoc = pkgs.nixosOptionsDoc {
        options.programs.askhuman = evaluated.options.programs.askhuman;
        documentType = "none";
        transformOptions =
          option:
          option
          // {
            declarations = map (
              declaration:
              let
                relative = lib.removePrefix "${toString ../.}/" (toString declaration);
              in
              {
                name = relative;
                url = "https://github.com/dearrrfish/my-nixpkgs/blob/main/${relative}";
              }
            ) option.declarations;
          };
      };
      markdown =
        pkgs.runCommand "askhuman-options.md"
          {
            nativeBuildInputs = [ pkgs.mdformat ];
          }
          ''
            {
              printf '# AskHuman Home Manager options\n\n'
              printf '<!-- Generated from evaluated module options. Run nix run .#generate-module-docs to update. -->\n\n'
              cat ${optionsDoc.optionsCommonMark}
            } > "$out"
            mdformat "$out"
          '';
      generator = pkgs.writeShellApplication {
        name = "generate-module-docs";
        runtimeInputs = [ pkgs.coreutils ];
        text = ''
          if [[ ! -f flake.nix || ! -d modules/home-manager/askhuman ]]; then
            echo 'Run this command from the my-nixpkgs repository root.' >&2
            exit 1
          fi
          install -Dm644 ${markdown} docs/modules/askhuman-options.md
        '';
      };
    in
    {
      apps.generate-module-docs = {
        type = "app";
        program = lib.getExe generator;
        meta.description = "Regenerate the evaluated AskHuman Home Manager option reference";
      };
      checks.module-docs = pkgs.runCommand "module-docs" { } ''
        diff -u ${../docs}/modules/askhuman-options.md ${markdown}
        mkdir -p "$out"
        cp ${markdown} "$out/askhuman-options.md"
      '';
    };
}
