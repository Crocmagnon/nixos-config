{ ... }:
{
  imports = [
    ./save-disk.nix
  ];

  time.timeZone = "Europe/Paris";

  programs.fish.enable = true;
  documentation.man.generateCaches = false; # speeds up rebuild by skiping "building man-cache", enabled by default by fish

  nixpkgs.config.allowUnfree = true;

  nix.settings.experimental-features = [
    "nix-command"
    "flakes"
  ];

  programs.nh = {
    enable = true;
  };
}
