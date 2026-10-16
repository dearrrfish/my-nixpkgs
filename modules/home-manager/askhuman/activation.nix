{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.programs.askhuman;
  # Null alone means unmanaged. Keep explicit false, zero and empty strings.
  stripNulls =
    value:
    if builtins.isAttrs value then
      lib.filterAttrs (_: item: item != null && item != { }) (lib.mapAttrs (_: stripNulls) value)
    else
      value;
  flatten =
    prefix: value:
    lib.concatMapAttrs (
      key: item:
      let
        path = if prefix == "" then key else "${prefix}.${key}";
      in
      if builtins.isAttrs item then
        flatten path item
      else
        lib.optionalAttrs (item != null) { ${path} = item; }
    ) value;
  integrations = lib.mapAttrs (
    _agent: value:
    {
      inherit (value) mode lifecycle;
      env = value.mcpEnvironment or { };
    }
    // lib.optionalAttrs (value ? permission) { inherit (value) permission; }
    // lib.optionalAttrs (value ? stop) { inherit (value) stop; }
    // lib.optionalAttrs (value ? askQuestion) { inherit (value) askQuestion; }
  ) (lib.filterAttrs (_: value: value.enable) cfg.integrations);
  manifest = pkgs.writeText "askhuman-manifest.json" (
    builtins.toJSON {
      enabled = cfg.enable;
      settings = if cfg.enable then stripNulls cfg.settings else { };
      executable = if cfg.enable then "${cfg.package}/bin/AskHuman" else null;
      secretFiles = if cfg.enable then flatten "" cfg.secretFiles else { };
      integrations = if cfg.enable then integrations else { };
      inherit (cfg) compatibility;
    }
  );
  python = pkgs.python3.withPackages (packages: [ packages.tomlkit ]);
  # Keep the adapter and its ordinary reconciliation import in one store directory.
  helpers = builtins.path {
    path = ./.;
    name = "askhuman-activation-helpers";
    filter =
      path: type:
      type == "directory"
      || builtins.elem (baseNameOf path) [
        "runtime.py"
        "reconcile.py"
      ];
  };
in
{
  # Keep this entry even when disabled, so a still-imported disabled generation
  # can release ordinary managed leaves without evaluating the default package.
  config.home.activation.askhuman = config.lib.dag.entryAfter [ "writeBoundary" ] ''
    askhumanDryRun=()
    if [[ -v DRY_RUN ]] || [ -n "''${DRY_RUN_CMD:-}" ]; then
      askhumanDryRun+=(--dry-run)
    fi
    ${python}/bin/python ${helpers}/runtime.py \
      --manifest ${lib.escapeShellArg (toString manifest)} \
      --home ${lib.escapeShellArg config.home.homeDirectory} \
      --state-dir ${lib.escapeShellArg "${config.xdg.stateHome}/my-nixpkgs/askhuman"} \
      "''${askhumanDryRun[@]}"
  '';
}
