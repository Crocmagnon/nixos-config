{ pkgs, ... }:
{
  imports = [
    ./save-disk.nix
    ./home-manager.nix
    ./users.nix
  ];

  environment.systemPackages = with pkgs; [
    vim
    git
    ripgrep
  ];

  environment.localBinInPath = true;

  time.timeZone = "Europe/Paris";

  programs.fish.enable = true;
  documentation.man.generateCaches = false; # speeds up rebuild by skipping "building man-cache", enabled by default by fish

  nixpkgs.config.allowUnfree = true;

  nix.settings.experimental-features = [
    "nix-command"
    "flakes"
  ];

  programs.nh = {
    enable = true;
  };

  programs.gnupg.agent = {
    enable = true;
  };
}
