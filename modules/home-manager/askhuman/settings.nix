{ lib, ... }:
let
  inherit (lib) mkOption types;
  leaf =
    type: name:
    mkOption {
      type = types.nullOr type;
      default = null;
      description = "Declare upstream ${name}. Null leaves this setting unmanaged; removing a declaration conditionally restores its original value.";
    };
  u32 = types.ints.between 0 4294967295;
  number = types.addCheck (types.either types.int types.float) (value: value - value == 0);
in
{
  options.programs.askhuman.settings = mkOption {
    default = { };
    description = "Sparse non-secret AskHuman v0.17.3 settings. Undeclared and unknown settings are preserved in the writable application config.";
    type = types.submodule {
      options = {
        general.theme = leaf (types.enum [
          "system"
          "light"
          "dark"
        ]) "general.theme";
        general.language = leaf types.str "general.language";
        general.alwaysOnTop = leaf types.bool "general.alwaysOnTop";
        general.appearAnimation = leaf (types.enum [
          "none"
          "document"
          "alert"
        ]) "general.appearAnimation";
        general.windowEffect = leaf (types.enum [
          "glass"
          "blur"
          "solid"
        ]) "general.windowEffect";
        general.speechLanguage = leaf types.str "general.speechLanguage";
        general.speechShortcut = leaf types.str "general.speechShortcut";
        general.popupSubmitKey = leaf (types.enum [
          "cmdEnter"
          "enter"
        ]) "general.popupSubmitKey";
        general.collaborationStyle = leaf (types.enum [
          "aligned"
          "autonomous"
          "custom"
        ]) "general.collaborationStyle";
        general.collaborationStyleCustomText = leaf types.str "general.collaborationStyleCustomText";
        general.agentCollaborationStyles = mkOption {
          default = { };
          description = "Per-agent collaboration style overrides. Unset agents inherit general.collaborationStyle.";
          type = types.attrsOf (
            types.submodule {
              options = {
                style = leaf (types.enum [
                  "aligned"
                  "autonomous"
                  "custom"
                ]) "general.agentCollaborationStyles.<agent>.style";
                customText = leaf types.str "general.agentCollaborationStyles.<agent>.customText";
              };
            }
          );
        };
        general.historyLimit = leaf u32 "general.historyLimit";
        general.todoHistoryLimit = leaf u32 "general.todoHistoryLimit";
        general.popupSound = leaf types.str "general.popupSound";
        general.menuBarIcon = leaf (types.enum [
          "off"
          "active"
          "always"
        ]) "general.menuBarIcon";
        general.popupPrewarm = leaf types.bool "general.popupPrewarm";
        general.daemonLifecycle = leaf (types.enum [
          "activity"
          "keepalive"
        ]) "general.daemonLifecycle";
        general.away.capsule = leaf types.bool "general.away.capsule";
        general.away.welcomeBack = leaf types.bool "general.away.welcomeBack";
        general.away.pushAfterSecs = leaf (types.ints.between 0 86400) "general.away.pushAfterSecs";
        general.quickReplies = leaf (types.listOf types.str) "general.quickReplies";
        channels.popup.enabled = leaf types.bool "channels.popup.enabled";
        channels.popup.windowMode = leaf (types.enum [
          "merged"
          "independent"
        ]) "channels.popup.windowMode";
        channels.popup.width = leaf number "channels.popup.width";
        channels.popup.height = leaf number "channels.popup.height";
        channels.popup.rememberSize = leaf types.bool "channels.popup.rememberSize";
        channels.popup.previewWidth = leaf number "channels.popup.previewWidth";
        channels.popup.sidebarWidth = leaf number "channels.popup.sidebarWidth";
        channels.telegram.enabled = leaf types.bool "channels.telegram.enabled";
        channels.telegram.chatId = leaf types.str "channels.telegram.chatId";
        channels.telegram.apiBaseUrl = leaf types.str "channels.telegram.apiBaseUrl";
        channels.dingding.enabled = leaf types.bool "channels.dingding.enabled";
        channels.dingding.clientId = leaf types.str "channels.dingding.clientId";
        channels.dingding.userId = leaf types.str "channels.dingding.userId";
        channels.dingding.cardTemplateId = leaf types.str "channels.dingding.cardTemplateId";
        channels.dingding.confirmCardTemplateId = leaf types.str "channels.dingding.confirmCardTemplateId";
        channels.dingding.permissionConfirmCardTemplateId = leaf types.str "channels.dingding.permissionConfirmCardTemplateId";
        channels.dingding.inlineSmallText = leaf types.bool "channels.dingding.inlineSmallText";
        channels.dingding.convertTextToDocx = leaf types.bool "channels.dingding.convertTextToDocx";
        channels.feishu.enabled = leaf types.bool "channels.feishu.enabled";
        channels.feishu.appId = leaf types.str "channels.feishu.appId";
        channels.feishu.openId = leaf types.str "channels.feishu.openId";
        channels.feishu.baseUrl = leaf types.str "channels.feishu.baseUrl";
        channels.slack.enabled = leaf types.bool "channels.slack.enabled";
        channels.slack.userId = leaf types.str "channels.slack.userId";
        channels.autoActivation = leaf types.bool "channels.autoActivation";
        channels.autoEndWatch = leaf types.bool "channels.autoEndWatch";
        agentTasks.enabled = leaf types.bool "agentTasks.enabled";
        agentTasks.permissionPrompt = leaf (types.enum [
          "ask"
          "agent-default"
          "yolo"
        ]) "agentTasks.permissionPrompt";
        agentTasks.cursorMax.policy = leaf (types.enum [
          "enforce-off"
          "inherit"
        ]) "agentTasks.cursorMax.policy";
        agentTasks.cursorMax.plan = leaf (types.enum [
          "auto"
          "legacy"
          "token-based"
        ]) "agentTasks.cursorMax.plan";
        permissions.codexRelaxedShell = leaf types.bool "permissions.codexRelaxedShell";
        experimental.enabled = leaf types.bool "experimental.enabled";
        experimental.verticalQuestions = leaf types.bool "experimental.verticalQuestions";
        cursorDesktop.suppressBackgroundCompletionFollowUp = leaf types.bool "cursorDesktop.suppressBackgroundCompletionFollowUp";
        cursorDesktop.endEscalationsWhileAway = leaf types.bool "cursorDesktop.endEscalationsWhileAway";
        cursorDesktop.launchPreference = leaf (types.enum [
          "terminal"
          "desktop"
        ]) "cursorDesktop.launchPreference";
        codexDesktop.appPath = leaf types.str "codexDesktop.appPath";
        codexDesktop.codexHome = leaf types.str "codexDesktop.codexHome";
        codexDesktop.launchPreference = leaf (types.enum [
          "terminal"
          "desktop"
        ]) "codexDesktop.launchPreference";
        antigravityDesktop.launchPreference = leaf (types.enum [
          "terminal"
          "desktop"
        ]) "antigravityDesktop.launchPreference";
        antigravityDesktop.manageSidecars = leaf types.bool "antigravityDesktop.manageSidecars";
      };
    };
  };
}
