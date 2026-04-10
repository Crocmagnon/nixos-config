{ ... }:
{
  virtualisation.docker.enable = true;
  users.users.gaugendre.extraGroups = [ "docker" ];
}
