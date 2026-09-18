{ pkgs, ... }:
{
  imports = [
    ./agenix.nix
    ./krunner-autostart.nix
    ./kitty.nix
    ./konsole
    ./kwallet-ssh.nix
    ./email.nix
    ./zed.nix
    ./vscode.nix
    ./plasma.nix
    ./python.nix
    ./rust.nix
    ./gh.nix
    ./go.nix
    ./lua.nix
    ./devenv.nix
    ./fonts.nix
    ./github-token.nix
    ./ai-agents.nix
  ];

  home.packages = with pkgs; [
    terraform
  ];
}
