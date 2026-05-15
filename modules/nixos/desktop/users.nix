{ pkgs, ... }:
{
  users.users.gaugendre = {
    extraGroups = [
      "networkmanager"
    ];
  };
}
