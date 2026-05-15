{ pkgs, ... }:
{
  # https://github.com/NixOS/nixpkgs/issues/239770
  security.pam.services.login.fprintAuth = false;

  services.fprintd = {
    enable = true;
    #  tod.enable = true;
    #  tod.driver = pkgs.libfprint-2-tod1-goodix;
  };

  # https://github.com/NixOS/nixpkgs/issues/432276
  # Stop fprintd before suspend so pam_fprintd does not retain a stale D-Bus
  # connection across the suspend/resume cycle.
  powerManagement.powerDownCommands = ''
    ${pkgs.systemd}/bin/systemctl stop fprintd.service 2>/dev/null || true
  '';

  # On resume, actively restart fprintd and kill kscreenlocker_greet so Plasma
  # respawns the greeter with a fresh PAM session against the new fprintd
  # instance. Without this, pam_fprintd in the lock screen keeps a dead D-Bus
  # connection and fingerprint auth fails until the user logs out.
  systemd.services.fprintd-resume = {
    description = "Restart fprintd and refresh Plasma lock screen PAM after resume";
    after = [
      "suspend.target"
      "sleep.target"
    ];
    wantedBy = [
      "suspend.target"
      "sleep.target"
    ];
    serviceConfig = {
      Type = "oneshot";
      TimeoutStartSec = "15";
      ExecStart = pkgs.writeShellScript "fprintd-resume" ''
        ${pkgs.systemd}/bin/systemctl restart fprintd.service

        for i in {1..10}; do
          if ${pkgs.systemd}/bin/systemctl is-active fprintd.service >/dev/null 2>&1; then
            break
          fi
          sleep 1
        done

        ${pkgs.psmisc}/bin/killall -TERM kscreenlocker_greet 2>/dev/null || true
      '';
    };
  };
}
