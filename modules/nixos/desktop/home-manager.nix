{ ... }:
{
  home-manager.users.gaugendre = {
    imports = [
      ../../home/gaugendre/desktop
    ];
  };
}
