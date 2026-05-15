{ ... }:
{
  home-manager.users.gaugendre = {
    imports = [
      ../../../home/desktop
    ];
  };
}
