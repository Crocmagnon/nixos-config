{ ... }:
{
  home-manager.users.gaugendre = {
    imports = [
      ./krunner-autostart.nix
      ./email.nix
      ./ai-agents.nix
    ];
  };
}
