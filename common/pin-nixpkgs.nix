{ pkgs, ... }:
{
  nix.channel.enable = false;
  nix.nixPath = [ "nixpkgs=/etc/nixos/nixpkgs" ];

  environment.etc = {
    "nixos/nixpkgs".source = builtins.storePath pkgs.path;
  };
}
