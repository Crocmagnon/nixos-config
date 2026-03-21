{ config, pkgs, ... }:
{
  programs.coolercontrol.enable = true;

  environment.systemPackages = with pkgs; [
    liquidctl
    lm_sensors
  ];

  boot.kernelModules = [
    "it87"
    "coretemp"
  ];
  boot.extraModulePackages = with config.boot.kernelPackages; [
    it87
  ];
  boot.kernelParams = [
    "acpi_enforce_resources=lax"
  ];
  boot.extraModprobeConfig = ''
    options it87 force_id=0x8628
  '';

}
