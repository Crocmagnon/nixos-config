{ ... }:
{
  programs.vscode = {
    enable = true;
    profiles.default.userSettings = {
      "python.analysis.typeCheckingMode" = "standard";
      "claudeCode.preferredLocation" = "panel";
    };
  };
}
