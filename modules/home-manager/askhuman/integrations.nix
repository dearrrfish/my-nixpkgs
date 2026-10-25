{ config, lib, ... }:
let
  inherit (lib) mkOption types;
  cfg = config.programs.askhuman;
  agents = [
    "codex"
    "claude"
    "cursor"
    "grok"
    "pi"
    "antigravity"
  ];
  nullable =
    description:
    mkOption {
      type = types.nullOr types.bool;
      default = null;
      inherit description;
    };
  agentOptions =
    agent:
    {
      enable = lib.mkEnableOption "native AskHuman ${agent} integration (the complete upstream rules, hooks and MCP bundle)";
      mode = mkOption {
        type = types.enum [
          "cli"
          "mcp"
        ];
        default = if agent == "grok" then "mcp" else "cli";
        description = "Native integration mode. Grok supports only mcp; Pi supports only cli.";
      };
    }
    // lib.optionalAttrs (agent != "antigravity") {
      lifecycle = nullable "Declare lifecycle tracking. Null preserves the existing upstream preference.";
    }
    //
      lib.optionalAttrs
        (
          !builtins.elem agent [
            "grok"
            "antigravity"
          ]
        )
        {
          stop = nullable "Declare stop interception. Null preserves the existing upstream preference.";
        }
    //
      lib.optionalAttrs
        (builtins.elem agent [
          "codex"
          "claude"
        ])
        {
          permission = nullable "Declare permission interception. Null preserves the existing upstream preference.";
        }
    // lib.optionalAttrs (agent == "claude") {
      askQuestion = nullable "Declare Claude native AskUserQuestion interception. Null preserves the existing preference.";
    }
    // lib.optionalAttrs (agent == "codex") {
      mcpEnvironment = mkOption {
        type = types.attrsOf types.str;
        default = { };
        description = "Non-secret Codex MCP environment. Valid only in MCP mode. Values enter the Nix store; never put credentials here.";
      };
    };
in
{
  options.programs.askhuman.integrations = lib.genAttrs agents (
    agent:
    mkOption {
      type = types.submodule { options = agentOptions agent; };
      default = { };
      description = "Opt-in upstream ${agent} integration. Activation backs up affected private paths. Disabling stops reconciliation and does not uninstall native artifacts.";
    }
  );
  config.assertions = [
    {
      assertion = !cfg.enable || !cfg.integrations.grok.enable || cfg.integrations.grok.mode == "mcp";
      message = "programs.askhuman.integrations.grok supports only mode = mcp.";
    }
    {
      assertion = !cfg.enable || !cfg.integrations.pi.enable || cfg.integrations.pi.mode == "cli";
      message = "programs.askhuman.integrations.pi supports only mode = cli.";
    }
    {
      assertion =
        !cfg.enable
        || cfg.integrations.codex.mcpEnvironment == { }
        || (cfg.integrations.codex.enable && cfg.integrations.codex.mode == "mcp");
      message = "programs.askhuman.integrations.codex.mcpEnvironment requires enabled Codex MCP integration.";
    }
  ];
}
