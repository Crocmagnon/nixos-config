{ pkgs, ... }:
{
  imports = [
    ./krunner-autostart.nix
    ./konsole
    ./kwallet-ssh.nix
    ./email.nix
    ./zed.nix
    ./vscode.nix
    ./plasma.nix
    ./rust.nix
    ./gh.nix
    ./go.nix
    ./lua.nix
    ./devenv.nix
    ./github-token.nix
    ./ai-agents.nix
  ];

  home.packages = with pkgs; [
    terraform
  ];
}
