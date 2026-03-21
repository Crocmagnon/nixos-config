{
  pkgs,
  lib,
  ...
}:
{
  systemd.user.enable = lib.mkDefault true;
  systemd.user.services.krunner-daemon = {
    Unit = {
      Description = "Auto start krunner in daemon mode so first manual invocation is fast.";
    };
    Install = {
      WantedBy = [ "graphical-session.target" ];
    };
    Service = {
      ExecStart = "${pkgs.kdePackages.plasma-workspace}/bin/krunner --daemon";
    };
  };
}
