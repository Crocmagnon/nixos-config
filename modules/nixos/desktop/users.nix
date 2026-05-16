{ pkgs, ... }:
{
  users.users.gaugendre = {
    extraGroups = [
      "networkmanager"
      "dialout"
    ];
  };
}
