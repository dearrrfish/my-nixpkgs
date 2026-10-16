{
  inputs,
  pkgs,
  system,
}:
let
  inherit (pkgs) lib;
  fixturePackage =
    pkgs.runCommand "askhuman-module-fixture"
      {
        meta = {
          platforms = lib.platforms.all;
          mainProgram = "AskHuman";
        };
      }
      ''
        mkdir -p "$out/bin"
        printf '#!/bin/sh\nexit 0\n' > "$out/bin/AskHuman"
        chmod +x "$out/bin/AskHuman"
      '';
  standalonePkgs = import inputs.nixpkgs { inherit system; };
  homeUsing =
    module: extraModules:
    inputs.home-manager.lib.homeManagerConfiguration {
      pkgs = standalonePkgs;
      modules = [
        module
        {
          home.username = "module-test";
          home.homeDirectory = "/home/module-test";
          home.stateVersion = "26.05";
        }
      ]
      ++ extraModules;
    };
  home = homeUsing inputs.self.homeManagerModules.default;
  configured =
    extra:
    home (
      [
        {
          programs.askhuman = {
            enable = true;
            package = fixturePackage;
          };
        }
      ]
      ++ extra
    );
  evaluates = configuration: (builtins.tryEval configuration.activationPackage.drvPath).success;
  rejects = module: !(evaluates (configured [ module ]));
  disabled = home [ { programs.askhuman.package = throw "Disabled import forced the package"; } ];
  enabled = configured [ { programs.askhuman.settings.general.theme = "dark"; } ];
  merged = configured [
    { programs.askhuman.settings.general.theme = lib.mkDefault "light"; }
    { programs.askhuman.settings.general.theme = "dark"; }
    { programs.askhuman.settings.general.theme = lib.mkForce "system"; }
    { programs.askhuman.settings.general.popupPrewarm = false; }
    { programs.askhuman.settings.channels.popup.width = 600; }
  ];
  inventory = builtins.fromJSON (builtins.readFile ./askhuman-schema.json);
  optionPaths =
    type:
    builtins.sort builtins.lessThan (
      map (option: lib.concatStringsSep "." option.loc) (
        builtins.filter (option: builtins.head option.loc != "_module") (
          lib.collect lib.isOption (type.getSubOptions [ ])
        )
      )
    );
  withDefaultPackage = home [ { programs.askhuman.enable = true; } ];
  compatibility = configured [
    {
      programs.askhuman.compatibility.hyprland.enable = true;
      programs.askhuman.compatibility.webKitSessionEnvironment = true;
      wayland.windowManager.hyprland.enable = true;
    }
  ];
  unsupportedPackage = fixturePackage.overrideAttrs (_: {
    meta.platforms = [ ];
  });
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
    "as/askhuman"
    "cl/cli-proxy-api"
    "de/deepseek-harness"
    "do/doubao-murmur"
    "es/escrcpy"
    "fc/fcitx5-vocotype"
  ];
  overlayPkgs = import inputs.nixpkgs {
    inherit system;
    overlays = [ inputs.self.overlays.default ];
  };
  results = {
    disabledDoesNotForcePackage = evaluates disabled;
    standalonePackageOverride = evaluates enabled;
    mergedOptions =
      evaluates merged
      && merged.config.programs.askhuman.settings.general.theme == "system"
      && merged.config.programs.askhuman.settings.general.popupPrewarm == false
      && merged.config.programs.askhuman.settings.channels.popup.width == 600;
    standalonePkgsHasNoConsumerOverlay = !(standalonePkgs ? local);
    namedModuleExport = evaluates (homeUsing inputs.self.homeManagerModules.askhuman [ ]);
    defaultNativeIntegrationsDisabled = lib.all (entry: !entry.enable) (
      builtins.attrValues enabled.config.programs.askhuman.integrations
    );
    integerBounds = rejects { programs.askhuman.settings.general.historyLimit = -1; };
    completeSettingsInventory =
      optionPaths enabled.options.programs.askhuman.settings.type
      == builtins.sort builtins.lessThan inventory.settings;
    completeSecretsInventory =
      optionPaths enabled.options.programs.askhuman.secretFiles.type
      == builtins.sort builtins.lessThan inventory.secretFiles;
    defaultPackagePlatform =
      if system == "x86_64-linux" then evaluates withDefaultPackage else !(evaluates withDefaultPackage);
    compatibilityOptIn =
      if pkgs.stdenv.hostPlatform.isLinux then
        evaluates compatibility
        && compatibility.config.home.sessionVariables.WEBKIT_DISABLE_DMABUF_RENDERER == "1"
        && builtins.length compatibility.config.wayland.windowManager.hyprland.settings.window_rule > 0
      else
        true;
    compatibilityRequiresHyprland = rejects { programs.askhuman.compatibility.hyprland.enable = true; };
    defaultDisabled = !(home [ ]).config.programs.askhuman.enable;
    nixosAggregation =
      nixos.config.networking.hostName == "module-test"
      && builtins.isString nixos.config.system.build.toplevel.drvPath;
    packageNames = builtins.attrNames inputs.self.packages.${system} == expectedPackages;
    overlayNames = builtins.attrNames overlayPkgs.local == expectedPackages;
    wrongType = rejects { programs.askhuman.settings.general.popupPrewarm = "false"; };
    invalidEnum = rejects { programs.askhuman.settings.general.theme = "invalid-theme"; };
    unknownSetting = rejects { programs.askhuman.settings.general.nonexistent = true; };
    secretInSettings = rejects { programs.askhuman.settings.channels.telegram.botToken = "secret"; };
    relativeSecret = rejects {
      programs.askhuman.secretFiles.channels.telegram.botToken = "relative/token";
    };
    storeSecret = rejects {
      programs.askhuman.secretFiles.channels.telegram.botToken = "/nix/store/token";
    };
    invalidGrokMode = rejects {
      programs.askhuman.integrations.grok = {
        enable = true;
        mode = "cli";
      };
    };
    invalidPiMode = rejects {
      programs.askhuman.integrations.pi = {
        enable = true;
        mode = "mcp";
      };
    };
    invalidPermission = rejects { programs.askhuman.integrations.cursor.permission = true; };
    unavailablePackage = rejects { programs.askhuman.package = lib.mkForce unsupportedPackage; };
    mcpEnvironmentOnlyInMcp = rejects {
      programs.askhuman.integrations.codex = {
        enable = true;
        mode = "cli";
        mcpEnvironment.TEST = "value";
      };
    };
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
      homeManagerActivation = builtins.unsafeDiscardStringContext enabled.activationPackage.drvPath;
      nixosSystem = builtins.unsafeDiscardStringContext nixos.config.system.build.toplevel.drvPath;
    };
  }
  ''
    mkdir -p "$out"
    printf '%s\n' "$evidence" > "$out/results.json"
  ''
