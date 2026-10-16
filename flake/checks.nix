{ inputs, ... }:
{
  perSystem =
    {
      pkgs,
      system,
      config,
      lib,
      ...
    }:
    let
      # Preserve relative Python imports and exclude unrelated repository content.
      testSource = builtins.path {
        path = ../.;
        name = "askhuman-module-tests";
        filter =
          path: type:
          let
            relative = lib.removePrefix "${toString ../.}/" path;
          in
          type == "directory"
          || builtins.elem relative [
            "modules/home-manager/askhuman/reconcile.py"
            "modules/home-manager/askhuman/runtime.py"
            "tests/test_askhuman_reconcile.py"
            "tests/test_askhuman_runtime.py"
            "tests/test_askhuman_activation.py"
            "tests/askhuman-schema.json"
          ]
          || lib.hasPrefix "tests/native-integration/" relative;
      };
      python = pkgs.python3.withPackages (packages: [ packages.tomlkit ]);
      activationHome = inputs.home-manager.lib.homeManagerConfiguration {
        inherit pkgs;
        modules = [
          inputs.self.homeManagerModules.default
          {
            home.username = "activation-test";
            home.homeDirectory = "/build/askhuman-activation-home";
            home.stateVersion = "26.05";
            programs.askhuman = {
              enable = true;
              package = pkgs.writeShellScriptBin "AskHuman" "exit 0";
              settings.general.theme = "dark";
            };
          }
        ];
      };
      activationScript = pkgs.writeText "askhuman-activation.sh" activationHome.config.home.activation.askhuman.data;
    in
    {
      checks.module-eval = import ../tests/module-eval.nix { inherit inputs pkgs system; };
      checks.askhuman-reconcile =
        pkgs.runCommand "askhuman-reconcile"
          {
            nativeBuildInputs = [ pkgs.python3 ];
          }
          ''
            cp -r ${testSource} source
            chmod -R u+w source
            cd source
            python -m unittest discover -s tests -p test_askhuman_reconcile.py -v
            mkdir -p "$out"
            printf 'Ordinary reconciliation tests passed.\n' > "$out/results.txt"
          '';
      checks.askhuman-activation =
        pkgs.runCommand "askhuman-activation"
          (
            {
              nativeBuildInputs = [ python ];
            }
            // lib.optionalAttrs (system == "x86_64-linux") {
              ASKHUMAN_EXECUTABLE = "${config.packages."as/askhuman"}/bin/AskHuman";
              ASKHUMAN_ACTIVATION_SCRIPT = activationScript;
              ASKHUMAN_ACTIVATION_HOME = "/build/askhuman-activation-home";
              ASKHUMAN_ACTIVATION_STATE = "/build/askhuman-activation-home/.local/state/my-nixpkgs/askhuman";
            }
          )
          ''
            cp -r ${testSource} source
            chmod -R u+w source
            cd source
            test -f tests/test_askhuman_runtime.py
            python -m unittest discover -s tests -p test_askhuman_runtime.py -v
            ${lib.optionalString (system == "x86_64-linux") ''
              test -f tests/test_askhuman_activation.py
              python -m unittest discover -s tests -p test_askhuman_activation.py -v
            ''}
            mkdir -p "$out"
            printf 'Runtime adapter and activation checks passed.\n' > "$out/results.txt"
          '';
    };
}
