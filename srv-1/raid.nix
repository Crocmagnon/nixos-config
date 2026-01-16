{ pkgs, ... }:

{
  environment.systemPackages = with pkgs; [
    mdadm
  ];

  boot.swraid = {
    enable = true;
  };

  # Timer to run a RAID scrub (check) every Sunday at 2 AM
  systemd.services.mdadm-scrub = {
    description = "Scrub mdadm arrays";
    serviceConfig = {
      Type = "oneshot";
      # Iterate over all md devices and trigger a check
      ExecStart = pkgs.writeShellScript "mdadm-scrub" ''
        for md in /sys/block/md*/md/sync_action; do
          if [ -f "$md" ]; then
            echo check > "$md"
          fi
        done
      '';
    };
  };

  systemd.timers.mdadm-scrub = {
    description = "Scrub mdadm arrays weekly";
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnCalendar = "Sun 02:00:00";
      Persistent = true;
    };
  };
}
