{ pkgs, ... }: {
  environment.systemPackages = with pkgs; [
    nrfconnect
    nrfutil
  ];
  services.udev.packages = with pkgs; [
    nrf-udev
  ];
  nixpkgs.config.segger-jlink.acceptLicense = true;
  nixpkgs.config.allowUnfree = true;
}
