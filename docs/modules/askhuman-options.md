# AskHuman Home Manager options

<!-- Generated from evaluated module options. Run nix run .#generate-module-docs to update. -->

## programs.askhuman.enable

Whether to enable AskHuman with sparse writable configuration management.

*Type:*
boolean

*Default:*

```nix
false
```

*Example:*

```nix
true
```

*Declared by:*

- [modules/home-manager/askhuman](https://github.com/dearrrfish/my-nixpkgs/blob/main/modules/home-manager/askhuman)

## programs.askhuman.package

AskHuman package providing bin/AskHuman. The default currently supports x86_64-linux; use a compatible override on other platforms. No overlay is required.

*Type:*
package

*Default:*

```nix
pkgs.callPackage <my-nixpkgs>/pkgs/by-name/as/askhuman/package.nix {}
```

*Declared by:*

- [modules/home-manager/askhuman](https://github.com/dearrrfish/my-nixpkgs/blob/main/modules/home-manager/askhuman)

## programs.askhuman.compatibility.hyprland.enable

Whether to enable an AskHuman floating-window rule in the existing Home Manager Hyprland configuration.

*Type:*
boolean

*Default:*

```nix
false
```

*Example:*

```nix
true
```

*Declared by:*

- [modules/home-manager/askhuman](https://github.com/dearrrfish/my-nixpkgs/blob/main/modules/home-manager/askhuman)

## programs.askhuman.compatibility.webKitSessionEnvironment

Whether to enable the session-wide WEBKIT_DISABLE_DMABUF_RENDERER=1 workaround (the package wrapper already supplies it for wrapped launches).

*Type:*
boolean

*Default:*

```nix
false
```

*Example:*

```nix
true
```

*Declared by:*

- [modules/home-manager/askhuman](https://github.com/dearrrfish/my-nixpkgs/blob/main/modules/home-manager/askhuman)

## programs.askhuman.integrations.claude

Opt-in upstream claude integration. Activation backs up affected private paths. Disabling stops reconciliation and does not uninstall native artifacts.

*Type:*
submodule

*Default:*

```nix
{ }
```

*Declared by:*

- [modules/home-manager/askhuman/integrations.nix](https://github.com/dearrrfish/my-nixpkgs/blob/main/modules/home-manager/askhuman/integrations.nix)

## programs.askhuman.integrations.claude.enable

Whether to enable native AskHuman claude integration (the complete upstream rules, hooks and MCP bundle).

*Type:*
boolean

*Default:*

```nix
false
```

*Example:*

```nix
true
```

*Declared by:*

- [modules/home-manager/askhuman/integrations.nix](https://github.com/dearrrfish/my-nixpkgs/blob/main/modules/home-manager/askhuman/integrations.nix)

## programs.askhuman.integrations.claude.askQuestion

Declare Claude native AskUserQuestion interception. Null preserves the existing preference.

*Type:*
null or boolean

*Default:*

```nix
null
```

*Declared by:*

- [modules/home-manager/askhuman/integrations.nix](https://github.com/dearrrfish/my-nixpkgs/blob/main/modules/home-manager/askhuman/integrations.nix)

## programs.askhuman.integrations.claude.lifecycle

Declare lifecycle tracking. Null preserves the existing upstream preference.

*Type:*
null or boolean

*Default:*

```nix
null
```

*Declared by:*

- [modules/home-manager/askhuman/integrations.nix](https://github.com/dearrrfish/my-nixpkgs/blob/main/modules/home-manager/askhuman/integrations.nix)

## programs.askhuman.integrations.claude.mode

Native integration mode. Grok supports only mcp; Pi supports only cli.

*Type:*
one of “cli”, “mcp”

*Default:*

```nix
"cli"
```

*Declared by:*

- [modules/home-manager/askhuman/integrations.nix](https://github.com/dearrrfish/my-nixpkgs/blob/main/modules/home-manager/askhuman/integrations.nix)

## programs.askhuman.integrations.claude.permission

Declare permission interception. Null preserves the existing upstream preference.

*Type:*
null or boolean

*Default:*

```nix
null
```

*Declared by:*

- [modules/home-manager/askhuman/integrations.nix](https://github.com/dearrrfish/my-nixpkgs/blob/main/modules/home-manager/askhuman/integrations.nix)

## programs.askhuman.integrations.claude.stop

Declare stop interception. Null preserves the existing upstream preference.

*Type:*
null or boolean

*Default:*

```nix
null
```

*Declared by:*

- [modules/home-manager/askhuman/integrations.nix](https://github.com/dearrrfish/my-nixpkgs/blob/main/modules/home-manager/askhuman/integrations.nix)

## programs.askhuman.integrations.codex

Opt-in upstream codex integration. Activation backs up affected private paths. Disabling stops reconciliation and does not uninstall native artifacts.

*Type:*
submodule

*Default:*

```nix
{ }
```

*Declared by:*

- [modules/home-manager/askhuman/integrations.nix](https://github.com/dearrrfish/my-nixpkgs/blob/main/modules/home-manager/askhuman/integrations.nix)

## programs.askhuman.integrations.codex.enable

Whether to enable native AskHuman codex integration (the complete upstream rules, hooks and MCP bundle).

*Type:*
boolean

*Default:*

```nix
false
```

*Example:*

```nix
true
```

*Declared by:*

- [modules/home-manager/askhuman/integrations.nix](https://github.com/dearrrfish/my-nixpkgs/blob/main/modules/home-manager/askhuman/integrations.nix)

## programs.askhuman.integrations.codex.lifecycle

Declare lifecycle tracking. Null preserves the existing upstream preference.

*Type:*
null or boolean

*Default:*

```nix
null
```

*Declared by:*

- [modules/home-manager/askhuman/integrations.nix](https://github.com/dearrrfish/my-nixpkgs/blob/main/modules/home-manager/askhuman/integrations.nix)

## programs.askhuman.integrations.codex.mcpEnvironment

Non-secret Codex MCP environment. Valid only in MCP mode. Values enter the Nix store; never put credentials here.

*Type:*
attribute set of string

*Default:*

```nix
{ }
```

*Declared by:*

- [modules/home-manager/askhuman/integrations.nix](https://github.com/dearrrfish/my-nixpkgs/blob/main/modules/home-manager/askhuman/integrations.nix)

## programs.askhuman.integrations.codex.mode

Native integration mode. Grok supports only mcp; Pi supports only cli.

*Type:*
one of “cli”, “mcp”

*Default:*

```nix
"cli"
```

*Declared by:*

- [modules/home-manager/askhuman/integrations.nix](https://github.com/dearrrfish/my-nixpkgs/blob/main/modules/home-manager/askhuman/integrations.nix)

## programs.askhuman.integrations.codex.permission

Declare permission interception. Null preserves the existing upstream preference.

*Type:*
null or boolean

*Default:*

```nix
null
```

*Declared by:*

- [modules/home-manager/askhuman/integrations.nix](https://github.com/dearrrfish/my-nixpkgs/blob/main/modules/home-manager/askhuman/integrations.nix)

## programs.askhuman.integrations.codex.stop

Declare stop interception. Null preserves the existing upstream preference.

*Type:*
null or boolean

*Default:*

```nix
null
```

*Declared by:*

- [modules/home-manager/askhuman/integrations.nix](https://github.com/dearrrfish/my-nixpkgs/blob/main/modules/home-manager/askhuman/integrations.nix)

## programs.askhuman.integrations.cursor

Opt-in upstream cursor integration. Activation backs up affected private paths. Disabling stops reconciliation and does not uninstall native artifacts.

*Type:*
submodule

*Default:*

```nix
{ }
```

*Declared by:*

- [modules/home-manager/askhuman/integrations.nix](https://github.com/dearrrfish/my-nixpkgs/blob/main/modules/home-manager/askhuman/integrations.nix)

## programs.askhuman.integrations.cursor.enable

Whether to enable native AskHuman cursor integration (the complete upstream rules, hooks and MCP bundle).

*Type:*
boolean

*Default:*

```nix
false
```

*Example:*

```nix
true
```

*Declared by:*

- [modules/home-manager/askhuman/integrations.nix](https://github.com/dearrrfish/my-nixpkgs/blob/main/modules/home-manager/askhuman/integrations.nix)

## programs.askhuman.integrations.cursor.lifecycle

Declare lifecycle tracking. Null preserves the existing upstream preference.

*Type:*
null or boolean

*Default:*

```nix
null
```

*Declared by:*

- [modules/home-manager/askhuman/integrations.nix](https://github.com/dearrrfish/my-nixpkgs/blob/main/modules/home-manager/askhuman/integrations.nix)

## programs.askhuman.integrations.cursor.mode

Native integration mode. Grok supports only mcp; Pi supports only cli.

*Type:*
one of “cli”, “mcp”

*Default:*

```nix
"cli"
```

*Declared by:*

- [modules/home-manager/askhuman/integrations.nix](https://github.com/dearrrfish/my-nixpkgs/blob/main/modules/home-manager/askhuman/integrations.nix)

## programs.askhuman.integrations.cursor.stop

Declare stop interception. Null preserves the existing upstream preference.

*Type:*
null or boolean

*Default:*

```nix
null
```

*Declared by:*

- [modules/home-manager/askhuman/integrations.nix](https://github.com/dearrrfish/my-nixpkgs/blob/main/modules/home-manager/askhuman/integrations.nix)

## programs.askhuman.integrations.grok

Opt-in upstream grok integration. Activation backs up affected private paths. Disabling stops reconciliation and does not uninstall native artifacts.

*Type:*
submodule

*Default:*

```nix
{ }
```

*Declared by:*

- [modules/home-manager/askhuman/integrations.nix](https://github.com/dearrrfish/my-nixpkgs/blob/main/modules/home-manager/askhuman/integrations.nix)

## programs.askhuman.integrations.grok.enable

Whether to enable native AskHuman grok integration (the complete upstream rules, hooks and MCP bundle).

*Type:*
boolean

*Default:*

```nix
false
```

*Example:*

```nix
true
```

*Declared by:*

- [modules/home-manager/askhuman/integrations.nix](https://github.com/dearrrfish/my-nixpkgs/blob/main/modules/home-manager/askhuman/integrations.nix)

## programs.askhuman.integrations.grok.lifecycle

Declare lifecycle tracking. Null preserves the existing upstream preference.

*Type:*
null or boolean

*Default:*

```nix
null
```

*Declared by:*

- [modules/home-manager/askhuman/integrations.nix](https://github.com/dearrrfish/my-nixpkgs/blob/main/modules/home-manager/askhuman/integrations.nix)

## programs.askhuman.integrations.grok.mode

Native integration mode. Grok supports only mcp; Pi supports only cli.

*Type:*
one of “cli”, “mcp”

*Default:*

```nix
"mcp"
```

*Declared by:*

- [modules/home-manager/askhuman/integrations.nix](https://github.com/dearrrfish/my-nixpkgs/blob/main/modules/home-manager/askhuman/integrations.nix)

## programs.askhuman.integrations.pi

Opt-in upstream pi integration. Activation backs up affected private paths. Disabling stops reconciliation and does not uninstall native artifacts.

*Type:*
submodule

*Default:*

```nix
{ }
```

*Declared by:*

- [modules/home-manager/askhuman/integrations.nix](https://github.com/dearrrfish/my-nixpkgs/blob/main/modules/home-manager/askhuman/integrations.nix)

## programs.askhuman.integrations.pi.enable

Whether to enable native AskHuman pi integration (the complete upstream rules, hooks and MCP bundle).

*Type:*
boolean

*Default:*

```nix
false
```

*Example:*

```nix
true
```

*Declared by:*

- [modules/home-manager/askhuman/integrations.nix](https://github.com/dearrrfish/my-nixpkgs/blob/main/modules/home-manager/askhuman/integrations.nix)

## programs.askhuman.integrations.pi.lifecycle

Declare lifecycle tracking. Null preserves the existing upstream preference.

*Type:*
null or boolean

*Default:*

```nix
null
```

*Declared by:*

- [modules/home-manager/askhuman/integrations.nix](https://github.com/dearrrfish/my-nixpkgs/blob/main/modules/home-manager/askhuman/integrations.nix)

## programs.askhuman.integrations.pi.mode

Native integration mode. Grok supports only mcp; Pi supports only cli.

*Type:*
one of “cli”, “mcp”

*Default:*

```nix
"cli"
```

*Declared by:*

- [modules/home-manager/askhuman/integrations.nix](https://github.com/dearrrfish/my-nixpkgs/blob/main/modules/home-manager/askhuman/integrations.nix)

## programs.askhuman.integrations.pi.stop

Declare stop interception. Null preserves the existing upstream preference.

*Type:*
null or boolean

*Default:*

```nix
null
```

*Declared by:*

- [modules/home-manager/askhuman/integrations.nix](https://github.com/dearrrfish/my-nixpkgs/blob/main/modules/home-manager/askhuman/integrations.nix)

## programs.askhuman.secretFiles

Runtime secret source paths. Neither secret values nor source files are copied to the Nix store. Omission preserves existing credentials; no secret rollback or deletion is performed.

*Type:*
submodule

*Default:*

```nix
{ }
```

*Declared by:*

- [modules/home-manager/askhuman](https://github.com/dearrrfish/my-nixpkgs/blob/main/modules/home-manager/askhuman)

## programs.askhuman.secretFiles.channels.dingding.clientSecret

Absolute runtime path to DingTalk client secret, outside the Nix store. Contents are read only during real activation, trimmed by upstream, and may fall back to private plaintext config if the keychain is unavailable. Null preserves existing credentials. Do not use a Nix path literal.

*Type:*
null or string

*Default:*

```nix
null
```

*Example:*

```nix
"/run/secrets/askhuman-token"
```

*Declared by:*

- [modules/home-manager/askhuman](https://github.com/dearrrfish/my-nixpkgs/blob/main/modules/home-manager/askhuman)

## programs.askhuman.secretFiles.channels.feishu.appSecret

Absolute runtime path to Feishu app secret, outside the Nix store. Contents are read only during real activation, trimmed by upstream, and may fall back to private plaintext config if the keychain is unavailable. Null preserves existing credentials. Do not use a Nix path literal.

*Type:*
null or string

*Default:*

```nix
null
```

*Example:*

```nix
"/run/secrets/askhuman-token"
```

*Declared by:*

- [modules/home-manager/askhuman](https://github.com/dearrrfish/my-nixpkgs/blob/main/modules/home-manager/askhuman)

## programs.askhuman.secretFiles.channels.slack.appToken

Absolute runtime path to Slack app token, outside the Nix store. Contents are read only during real activation, trimmed by upstream, and may fall back to private plaintext config if the keychain is unavailable. Null preserves existing credentials. Do not use a Nix path literal.

*Type:*
null or string

*Default:*

```nix
null
```

*Example:*

```nix
"/run/secrets/askhuman-token"
```

*Declared by:*

- [modules/home-manager/askhuman](https://github.com/dearrrfish/my-nixpkgs/blob/main/modules/home-manager/askhuman)

## programs.askhuman.secretFiles.channels.slack.botToken

Absolute runtime path to Slack bot token, outside the Nix store. Contents are read only during real activation, trimmed by upstream, and may fall back to private plaintext config if the keychain is unavailable. Null preserves existing credentials. Do not use a Nix path literal.

*Type:*
null or string

*Default:*

```nix
null
```

*Example:*

```nix
"/run/secrets/askhuman-token"
```

*Declared by:*

- [modules/home-manager/askhuman](https://github.com/dearrrfish/my-nixpkgs/blob/main/modules/home-manager/askhuman)

## programs.askhuman.secretFiles.channels.telegram.botToken

Absolute runtime path to Telegram bot token, outside the Nix store. Contents are read only during real activation, trimmed by upstream, and may fall back to private plaintext config if the keychain is unavailable. Null preserves existing credentials. Do not use a Nix path literal.

*Type:*
null or string

*Default:*

```nix
null
```

*Example:*

```nix
"/run/secrets/askhuman-token"
```

*Declared by:*

- [modules/home-manager/askhuman](https://github.com/dearrrfish/my-nixpkgs/blob/main/modules/home-manager/askhuman)

## programs.askhuman.settings

Sparse non-secret AskHuman v0.14.4 settings. Undeclared and unknown settings are preserved in the writable application config.

*Type:*
submodule

*Default:*

```nix
{ }
```

*Declared by:*

- [modules/home-manager/askhuman/settings.nix](https://github.com/dearrrfish/my-nixpkgs/blob/main/modules/home-manager/askhuman/settings.nix)

## programs.askhuman.settings.agentTasks.enabled

Declare upstream agentTasks.enabled. Null leaves this setting unmanaged; removing a declaration conditionally restores its original value.

*Type:*
null or boolean

*Default:*

```nix
null
```

*Declared by:*

- [modules/home-manager/askhuman/settings.nix](https://github.com/dearrrfish/my-nixpkgs/blob/main/modules/home-manager/askhuman/settings.nix)

## programs.askhuman.settings.agentTasks.permissionPrompt

Declare upstream agentTasks.permissionPrompt. Null leaves this setting unmanaged; removing a declaration conditionally restores its original value.

*Type:*
null or one of “ask”, “agent-default”, “yolo”

*Default:*

```nix
null
```

*Declared by:*

- [modules/home-manager/askhuman/settings.nix](https://github.com/dearrrfish/my-nixpkgs/blob/main/modules/home-manager/askhuman/settings.nix)

## programs.askhuman.settings.channels.autoActivation

Declare upstream channels.autoActivation. Null leaves this setting unmanaged; removing a declaration conditionally restores its original value.

*Type:*
null or boolean

*Default:*

```nix
null
```

*Declared by:*

- [modules/home-manager/askhuman/settings.nix](https://github.com/dearrrfish/my-nixpkgs/blob/main/modules/home-manager/askhuman/settings.nix)

## programs.askhuman.settings.channels.autoEndWatch

Declare upstream channels.autoEndWatch. Null leaves this setting unmanaged; removing a declaration conditionally restores its original value.

*Type:*
null or boolean

*Default:*

```nix
null
```

*Declared by:*

- [modules/home-manager/askhuman/settings.nix](https://github.com/dearrrfish/my-nixpkgs/blob/main/modules/home-manager/askhuman/settings.nix)

## programs.askhuman.settings.channels.dingding.enabled

Declare upstream channels.dingding.enabled. Null leaves this setting unmanaged; removing a declaration conditionally restores its original value.

*Type:*
null or boolean

*Default:*

```nix
null
```

*Declared by:*

- [modules/home-manager/askhuman/settings.nix](https://github.com/dearrrfish/my-nixpkgs/blob/main/modules/home-manager/askhuman/settings.nix)

## programs.askhuman.settings.channels.dingding.cardTemplateId

Declare upstream channels.dingding.cardTemplateId. Null leaves this setting unmanaged; removing a declaration conditionally restores its original value.

*Type:*
null or string

*Default:*

```nix
null
```

*Declared by:*

- [modules/home-manager/askhuman/settings.nix](https://github.com/dearrrfish/my-nixpkgs/blob/main/modules/home-manager/askhuman/settings.nix)

## programs.askhuman.settings.channels.dingding.clientId

Declare upstream channels.dingding.clientId. Null leaves this setting unmanaged; removing a declaration conditionally restores its original value.

*Type:*
null or string

*Default:*

```nix
null
```

*Declared by:*

- [modules/home-manager/askhuman/settings.nix](https://github.com/dearrrfish/my-nixpkgs/blob/main/modules/home-manager/askhuman/settings.nix)

## programs.askhuman.settings.channels.dingding.confirmCardTemplateId

Declare upstream channels.dingding.confirmCardTemplateId. Null leaves this setting unmanaged; removing a declaration conditionally restores its original value.

*Type:*
null or string

*Default:*

```nix
null
```

*Declared by:*

- [modules/home-manager/askhuman/settings.nix](https://github.com/dearrrfish/my-nixpkgs/blob/main/modules/home-manager/askhuman/settings.nix)

## programs.askhuman.settings.channels.dingding.convertTextToDocx

Declare upstream channels.dingding.convertTextToDocx. Null leaves this setting unmanaged; removing a declaration conditionally restores its original value.

*Type:*
null or boolean

*Default:*

```nix
null
```

*Declared by:*

- [modules/home-manager/askhuman/settings.nix](https://github.com/dearrrfish/my-nixpkgs/blob/main/modules/home-manager/askhuman/settings.nix)

## programs.askhuman.settings.channels.dingding.inlineSmallText

Declare upstream channels.dingding.inlineSmallText. Null leaves this setting unmanaged; removing a declaration conditionally restores its original value.

*Type:*
null or boolean

*Default:*

```nix
null
```

*Declared by:*

- [modules/home-manager/askhuman/settings.nix](https://github.com/dearrrfish/my-nixpkgs/blob/main/modules/home-manager/askhuman/settings.nix)

## programs.askhuman.settings.channels.dingding.permissionConfirmCardTemplateId

Declare upstream channels.dingding.permissionConfirmCardTemplateId. Null leaves this setting unmanaged; removing a declaration conditionally restores its original value.

*Type:*
null or string

*Default:*

```nix
null
```

*Declared by:*

- [modules/home-manager/askhuman/settings.nix](https://github.com/dearrrfish/my-nixpkgs/blob/main/modules/home-manager/askhuman/settings.nix)

## programs.askhuman.settings.channels.dingding.userId

Declare upstream channels.dingding.userId. Null leaves this setting unmanaged; removing a declaration conditionally restores its original value.

*Type:*
null or string

*Default:*

```nix
null
```

*Declared by:*

- [modules/home-manager/askhuman/settings.nix](https://github.com/dearrrfish/my-nixpkgs/blob/main/modules/home-manager/askhuman/settings.nix)

## programs.askhuman.settings.channels.feishu.enabled

Declare upstream channels.feishu.enabled. Null leaves this setting unmanaged; removing a declaration conditionally restores its original value.

*Type:*
null or boolean

*Default:*

```nix
null
```

*Declared by:*

- [modules/home-manager/askhuman/settings.nix](https://github.com/dearrrfish/my-nixpkgs/blob/main/modules/home-manager/askhuman/settings.nix)

## programs.askhuman.settings.channels.feishu.appId

Declare upstream channels.feishu.appId. Null leaves this setting unmanaged; removing a declaration conditionally restores its original value.

*Type:*
null or string

*Default:*

```nix
null
```

*Declared by:*

- [modules/home-manager/askhuman/settings.nix](https://github.com/dearrrfish/my-nixpkgs/blob/main/modules/home-manager/askhuman/settings.nix)

## programs.askhuman.settings.channels.feishu.baseUrl

Declare upstream channels.feishu.baseUrl. Null leaves this setting unmanaged; removing a declaration conditionally restores its original value.

*Type:*
null or string

*Default:*

```nix
null
```

*Declared by:*

- [modules/home-manager/askhuman/settings.nix](https://github.com/dearrrfish/my-nixpkgs/blob/main/modules/home-manager/askhuman/settings.nix)

## programs.askhuman.settings.channels.feishu.openId

Declare upstream channels.feishu.openId. Null leaves this setting unmanaged; removing a declaration conditionally restores its original value.

*Type:*
null or string

*Default:*

```nix
null
```

*Declared by:*

- [modules/home-manager/askhuman/settings.nix](https://github.com/dearrrfish/my-nixpkgs/blob/main/modules/home-manager/askhuman/settings.nix)

## programs.askhuman.settings.channels.popup.enabled

Declare upstream channels.popup.enabled. Null leaves this setting unmanaged; removing a declaration conditionally restores its original value.

*Type:*
null or boolean

*Default:*

```nix
null
```

*Declared by:*

- [modules/home-manager/askhuman/settings.nix](https://github.com/dearrrfish/my-nixpkgs/blob/main/modules/home-manager/askhuman/settings.nix)

## programs.askhuman.settings.channels.popup.height

Declare upstream channels.popup.height. Null leaves this setting unmanaged; removing a declaration conditionally restores its original value.

*Type:*
null or signed integer or floating point number

*Default:*

```nix
null
```

*Declared by:*

- [modules/home-manager/askhuman/settings.nix](https://github.com/dearrrfish/my-nixpkgs/blob/main/modules/home-manager/askhuman/settings.nix)

## programs.askhuman.settings.channels.popup.previewWidth

Declare upstream channels.popup.previewWidth. Null leaves this setting unmanaged; removing a declaration conditionally restores its original value.

*Type:*
null or signed integer or floating point number

*Default:*

```nix
null
```

*Declared by:*

- [modules/home-manager/askhuman/settings.nix](https://github.com/dearrrfish/my-nixpkgs/blob/main/modules/home-manager/askhuman/settings.nix)

## programs.askhuman.settings.channels.popup.rememberSize

Declare upstream channels.popup.rememberSize. Null leaves this setting unmanaged; removing a declaration conditionally restores its original value.

*Type:*
null or boolean

*Default:*

```nix
null
```

*Declared by:*

- [modules/home-manager/askhuman/settings.nix](https://github.com/dearrrfish/my-nixpkgs/blob/main/modules/home-manager/askhuman/settings.nix)

## programs.askhuman.settings.channels.popup.sidebarWidth

Declare upstream channels.popup.sidebarWidth. Null leaves this setting unmanaged; removing a declaration conditionally restores its original value.

*Type:*
null or signed integer or floating point number

*Default:*

```nix
null
```

*Declared by:*

- [modules/home-manager/askhuman/settings.nix](https://github.com/dearrrfish/my-nixpkgs/blob/main/modules/home-manager/askhuman/settings.nix)

## programs.askhuman.settings.channels.popup.width

Declare upstream channels.popup.width. Null leaves this setting unmanaged; removing a declaration conditionally restores its original value.

*Type:*
null or signed integer or floating point number

*Default:*

```nix
null
```

*Declared by:*

- [modules/home-manager/askhuman/settings.nix](https://github.com/dearrrfish/my-nixpkgs/blob/main/modules/home-manager/askhuman/settings.nix)

## programs.askhuman.settings.channels.popup.windowMode

Declare upstream channels.popup.windowMode. Null leaves this setting unmanaged; removing a declaration conditionally restores its original value.

*Type:*
null or one of “merged”, “independent”

*Default:*

```nix
null
```

*Declared by:*

- [modules/home-manager/askhuman/settings.nix](https://github.com/dearrrfish/my-nixpkgs/blob/main/modules/home-manager/askhuman/settings.nix)

## programs.askhuman.settings.channels.slack.enabled

Declare upstream channels.slack.enabled. Null leaves this setting unmanaged; removing a declaration conditionally restores its original value.

*Type:*
null or boolean

*Default:*

```nix
null
```

*Declared by:*

- [modules/home-manager/askhuman/settings.nix](https://github.com/dearrrfish/my-nixpkgs/blob/main/modules/home-manager/askhuman/settings.nix)

## programs.askhuman.settings.channels.slack.userId

Declare upstream channels.slack.userId. Null leaves this setting unmanaged; removing a declaration conditionally restores its original value.

*Type:*
null or string

*Default:*

```nix
null
```

*Declared by:*

- [modules/home-manager/askhuman/settings.nix](https://github.com/dearrrfish/my-nixpkgs/blob/main/modules/home-manager/askhuman/settings.nix)

## programs.askhuman.settings.channels.telegram.enabled

Declare upstream channels.telegram.enabled. Null leaves this setting unmanaged; removing a declaration conditionally restores its original value.

*Type:*
null or boolean

*Default:*

```nix
null
```

*Declared by:*

- [modules/home-manager/askhuman/settings.nix](https://github.com/dearrrfish/my-nixpkgs/blob/main/modules/home-manager/askhuman/settings.nix)

## programs.askhuman.settings.channels.telegram.apiBaseUrl

Declare upstream channels.telegram.apiBaseUrl. Null leaves this setting unmanaged; removing a declaration conditionally restores its original value.

*Type:*
null or string

*Default:*

```nix
null
```

*Declared by:*

- [modules/home-manager/askhuman/settings.nix](https://github.com/dearrrfish/my-nixpkgs/blob/main/modules/home-manager/askhuman/settings.nix)

## programs.askhuman.settings.channels.telegram.chatId

Declare upstream channels.telegram.chatId. Null leaves this setting unmanaged; removing a declaration conditionally restores its original value.

*Type:*
null or string

*Default:*

```nix
null
```

*Declared by:*

- [modules/home-manager/askhuman/settings.nix](https://github.com/dearrrfish/my-nixpkgs/blob/main/modules/home-manager/askhuman/settings.nix)

## programs.askhuman.settings.codexDesktop.appPath

Declare upstream codexDesktop.appPath. Null leaves this setting unmanaged; removing a declaration conditionally restores its original value.

*Type:*
null or string

*Default:*

```nix
null
```

*Declared by:*

- [modules/home-manager/askhuman/settings.nix](https://github.com/dearrrfish/my-nixpkgs/blob/main/modules/home-manager/askhuman/settings.nix)

## programs.askhuman.settings.codexDesktop.codexHome

Declare upstream codexDesktop.codexHome. Null leaves this setting unmanaged; removing a declaration conditionally restores its original value.

*Type:*
null or string

*Default:*

```nix
null
```

*Declared by:*

- [modules/home-manager/askhuman/settings.nix](https://github.com/dearrrfish/my-nixpkgs/blob/main/modules/home-manager/askhuman/settings.nix)

## programs.askhuman.settings.codexDesktop.launchPreference

Declare upstream codexDesktop.launchPreference. Null leaves this setting unmanaged; removing a declaration conditionally restores its original value.

*Type:*
null or one of “terminal”, “desktop”

*Default:*

```nix
null
```

*Declared by:*

- [modules/home-manager/askhuman/settings.nix](https://github.com/dearrrfish/my-nixpkgs/blob/main/modules/home-manager/askhuman/settings.nix)

## programs.askhuman.settings.experimental.enabled

Declare upstream experimental.enabled. Null leaves this setting unmanaged; removing a declaration conditionally restores its original value.

*Type:*
null or boolean

*Default:*

```nix
null
```

*Declared by:*

- [modules/home-manager/askhuman/settings.nix](https://github.com/dearrrfish/my-nixpkgs/blob/main/modules/home-manager/askhuman/settings.nix)

## programs.askhuman.settings.experimental.verticalQuestions

Declare upstream experimental.verticalQuestions. Null leaves this setting unmanaged; removing a declaration conditionally restores its original value.

*Type:*
null or boolean

*Default:*

```nix
null
```

*Declared by:*

- [modules/home-manager/askhuman/settings.nix](https://github.com/dearrrfish/my-nixpkgs/blob/main/modules/home-manager/askhuman/settings.nix)

## programs.askhuman.settings.general.alwaysOnTop

Declare upstream general.alwaysOnTop. Null leaves this setting unmanaged; removing a declaration conditionally restores its original value.

*Type:*
null or boolean

*Default:*

```nix
null
```

*Declared by:*

- [modules/home-manager/askhuman/settings.nix](https://github.com/dearrrfish/my-nixpkgs/blob/main/modules/home-manager/askhuman/settings.nix)

## programs.askhuman.settings.general.appearAnimation

Declare upstream general.appearAnimation. Null leaves this setting unmanaged; removing a declaration conditionally restores its original value.

*Type:*
null or one of “none”, “document”, “alert”

*Default:*

```nix
null
```

*Declared by:*

- [modules/home-manager/askhuman/settings.nix](https://github.com/dearrrfish/my-nixpkgs/blob/main/modules/home-manager/askhuman/settings.nix)

## programs.askhuman.settings.general.collaborationStyle

Declare upstream general.collaborationStyle. Null leaves this setting unmanaged; removing a declaration conditionally restores its original value.

*Type:*
null or one of “aligned”, “autonomous”, “custom”

*Default:*

```nix
null
```

*Declared by:*

- [modules/home-manager/askhuman/settings.nix](https://github.com/dearrrfish/my-nixpkgs/blob/main/modules/home-manager/askhuman/settings.nix)

## programs.askhuman.settings.general.collaborationStyleCustomText

Declare upstream general.collaborationStyleCustomText. Null leaves this setting unmanaged; removing a declaration conditionally restores its original value.

*Type:*
null or string

*Default:*

```nix
null
```

*Declared by:*

- [modules/home-manager/askhuman/settings.nix](https://github.com/dearrrfish/my-nixpkgs/blob/main/modules/home-manager/askhuman/settings.nix)

## programs.askhuman.settings.general.daemonLifecycle

Declare upstream general.daemonLifecycle. Null leaves this setting unmanaged; removing a declaration conditionally restores its original value.

*Type:*
null or one of “activity”, “keepalive”

*Default:*

```nix
null
```

*Declared by:*

- [modules/home-manager/askhuman/settings.nix](https://github.com/dearrrfish/my-nixpkgs/blob/main/modules/home-manager/askhuman/settings.nix)

## programs.askhuman.settings.general.historyLimit

Declare upstream general.historyLimit. Null leaves this setting unmanaged; removing a declaration conditionally restores its original value.

*Type:*
null or integer between 0 and 4294967295 (both inclusive)

*Default:*

```nix
null
```

*Declared by:*

- [modules/home-manager/askhuman/settings.nix](https://github.com/dearrrfish/my-nixpkgs/blob/main/modules/home-manager/askhuman/settings.nix)

## programs.askhuman.settings.general.language

Declare upstream general.language. Null leaves this setting unmanaged; removing a declaration conditionally restores its original value.

*Type:*
null or string

*Default:*

```nix
null
```

*Declared by:*

- [modules/home-manager/askhuman/settings.nix](https://github.com/dearrrfish/my-nixpkgs/blob/main/modules/home-manager/askhuman/settings.nix)

## programs.askhuman.settings.general.menuBarIcon

Declare upstream general.menuBarIcon. Null leaves this setting unmanaged; removing a declaration conditionally restores its original value.

*Type:*
null or one of “off”, “active”, “always”

*Default:*

```nix
null
```

*Declared by:*

- [modules/home-manager/askhuman/settings.nix](https://github.com/dearrrfish/my-nixpkgs/blob/main/modules/home-manager/askhuman/settings.nix)

## programs.askhuman.settings.general.popupPrewarm

Declare upstream general.popupPrewarm. Null leaves this setting unmanaged; removing a declaration conditionally restores its original value.

*Type:*
null or boolean

*Default:*

```nix
null
```

*Declared by:*

- [modules/home-manager/askhuman/settings.nix](https://github.com/dearrrfish/my-nixpkgs/blob/main/modules/home-manager/askhuman/settings.nix)

## programs.askhuman.settings.general.popupSound

Declare upstream general.popupSound. Null leaves this setting unmanaged; removing a declaration conditionally restores its original value.

*Type:*
null or string

*Default:*

```nix
null
```

*Declared by:*

- [modules/home-manager/askhuman/settings.nix](https://github.com/dearrrfish/my-nixpkgs/blob/main/modules/home-manager/askhuman/settings.nix)

## programs.askhuman.settings.general.popupSubmitKey

Declare upstream general.popupSubmitKey. Null leaves this setting unmanaged; removing a declaration conditionally restores its original value.

*Type:*
null or one of “cmdEnter”, “enter”

*Default:*

```nix
null
```

*Declared by:*

- [modules/home-manager/askhuman/settings.nix](https://github.com/dearrrfish/my-nixpkgs/blob/main/modules/home-manager/askhuman/settings.nix)

## programs.askhuman.settings.general.speechLanguage

Declare upstream general.speechLanguage. Null leaves this setting unmanaged; removing a declaration conditionally restores its original value.

*Type:*
null or string

*Default:*

```nix
null
```

*Declared by:*

- [modules/home-manager/askhuman/settings.nix](https://github.com/dearrrfish/my-nixpkgs/blob/main/modules/home-manager/askhuman/settings.nix)

## programs.askhuman.settings.general.speechShortcut

Declare upstream general.speechShortcut. Null leaves this setting unmanaged; removing a declaration conditionally restores its original value.

*Type:*
null or string

*Default:*

```nix
null
```

*Declared by:*

- [modules/home-manager/askhuman/settings.nix](https://github.com/dearrrfish/my-nixpkgs/blob/main/modules/home-manager/askhuman/settings.nix)

## programs.askhuman.settings.general.theme

Declare upstream general.theme. Null leaves this setting unmanaged; removing a declaration conditionally restores its original value.

*Type:*
null or one of “system”, “light”, “dark”

*Default:*

```nix
null
```

*Declared by:*

- [modules/home-manager/askhuman/settings.nix](https://github.com/dearrrfish/my-nixpkgs/blob/main/modules/home-manager/askhuman/settings.nix)

## programs.askhuman.settings.general.todoHistoryLimit

Declare upstream general.todoHistoryLimit. Null leaves this setting unmanaged; removing a declaration conditionally restores its original value.

*Type:*
null or integer between 0 and 4294967295 (both inclusive)

*Default:*

```nix
null
```

*Declared by:*

- [modules/home-manager/askhuman/settings.nix](https://github.com/dearrrfish/my-nixpkgs/blob/main/modules/home-manager/askhuman/settings.nix)

## programs.askhuman.settings.general.windowEffect

Declare upstream general.windowEffect. Null leaves this setting unmanaged; removing a declaration conditionally restores its original value.

*Type:*
null or one of “glass”, “blur”, “solid”

*Default:*

```nix
null
```

*Declared by:*

- [modules/home-manager/askhuman/settings.nix](https://github.com/dearrrfish/my-nixpkgs/blob/main/modules/home-manager/askhuman/settings.nix)

## programs.askhuman.settings.permissions.codexRelaxedShell

Declare upstream permissions.codexRelaxedShell. Null leaves this setting unmanaged; removing a declaration conditionally restores its original value.

*Type:*
null or boolean

*Default:*

```nix
null
```

*Declared by:*

- [modules/home-manager/askhuman/settings.nix](https://github.com/dearrrfish/my-nixpkgs/blob/main/modules/home-manager/askhuman/settings.nix)
