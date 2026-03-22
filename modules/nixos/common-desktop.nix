{ ... }:
{
  imports = [
    ./common.nix
    ./locale.nix
    ./fonts.nix
    ./audio.nix
    ./iphone.nix
    ./boot.nix
  ];

  services.fwupd.enable = true;
}
