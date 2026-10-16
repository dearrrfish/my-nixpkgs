{
  config,
  lib,
  pkgs,
  options,
  ...
}:
let
  inherit (lib) mkOption types;
  cfg = config.programs.askhuman;
  runtimePath = types.addCheck types.str (
    value: lib.hasPrefix "/" value && value != "/nix/store" && !(lib.hasPrefix "/nix/store/" value)
  );
  secret =
    name:
    mkOption {
      type = types.nullOr runtimePath;
      default = null;
      description = "Absolute runtime path to ${name}, outside the Nix store. Contents are read only during real activation, trimmed by upstream, and may fall back to private plaintext config if the keychain is unavailable. Null preserves existing credentials. Do not use a Nix path literal.";
      example = "/run/secrets/askhuman-token";
    };
  hyprlandSupported = lib.hasAttrByPath [ "wayland" "windowManager" "hyprland" "settings" ] options;
in
{
  imports = [
    ./settings.nix
    ./integrations.nix
    ./activation.nix
  ];
  options.programs.askhuman = {
    enable = lib.mkEnableOption "AskHuman with sparse writable configuration management";
    package = mkOption {
      type = types.package;
      default = pkgs.callPackage ../../../pkgs/by-name/as/askhuman/package.nix { };
      defaultText = lib.literalExpression "pkgs.callPackage <my-nixpkgs>/pkgs/by-name/as/askhuman/package.nix {}";
      description = "AskHuman package providing bin/AskHuman. The default currently supports x86_64-linux; use a compatible override on other platforms. No overlay is required.";
    };
    secretFiles = mkOption {
      default = { };
      description = "Runtime secret source paths. Neither secret values nor source files are copied to the Nix store. Omission preserves existing credentials; no secret rollback or deletion is performed.";
      type = types.submodule {
        options.channels = {
          telegram.botToken = secret "Telegram bot token";
          dingding.clientSecret = secret "DingTalk client secret";
          feishu.appSecret = secret "Feishu app secret";
          slack.botToken = secret "Slack bot token";
          slack.appToken = secret "Slack app token";
        };
      };
    };
    compatibility = {
      webKitSessionEnvironment = lib.mkEnableOption "the session-wide WEBKIT_DISABLE_DMABUF_RENDERER=1 workaround (the package wrapper already supplies it for wrapped launches)";
      hyprland.enable = lib.mkEnableOption "an AskHuman floating-window rule in the existing Home Manager Hyprland configuration";
    };
  };
  config = lib.mkMerge [
    {
      assertions = [
        {
          assertion = !cfg.enable || lib.meta.availableOn pkgs.stdenv.hostPlatform cfg.package;
          message = "programs.askhuman.package is unavailable on ${pkgs.stdenv.hostPlatform.system}; provide a compatible package override or disable AskHuman.";
        }
        {
          assertion = !cfg.enable || !cfg.compatibility.hyprland.enable || hyprlandSupported;
          message = "programs.askhuman.compatibility.hyprland.enable requires Home Manager Hyprland settings support.";
        }
        {
          assertion =
            !cfg.enable
            || !cfg.compatibility.hyprland.enable
            || (config.wayland.windowManager.hyprland.enable or false);
          message = "programs.askhuman.compatibility.hyprland.enable requires wayland.windowManager.hyprland.enable.";
        }
      ];
    }
    (lib.mkIf cfg.enable {
      home.packages = [ cfg.package ];
      home.sessionVariables = lib.optionalAttrs cfg.compatibility.webKitSessionEnvironment {
        WEBKIT_DISABLE_DMABUF_RENDERER = "1";
      };
    })
    (lib.mkIf (cfg.enable && cfg.compatibility.hyprland.enable) {
      wayland.windowManager.hyprland.settings.window_rule = lib.mkAfter [
        {
          match.class = "^(\\.)?AskHuman(-wrapped)?$";
          float = true;
        }
      ];
    })
  ];
}
