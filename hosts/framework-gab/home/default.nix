{ ... }:
{
  home-manager.users.gaugendre = {
    imports = [
      ./krunner-autostart.nix
      ./email.nix
      ./zed.nix
    ];

    programs.vscode = {
      enable = true;
      profiles.default.userSettings = {
        "python.analysis.typeCheckingMode" = "standard";
        "claudeCode.preferredLocation" = "panel";
      };
    };
  };
}
