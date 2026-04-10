{ ... }:
{
  imports = [
    ./common.nix
    ./locale.nix
    ./fonts.nix
    ./audio.nix
    ./iphone.nix
    ./boot.nix
    ./docker.nix
  ];

  services.fwupd.enable = true;
}
