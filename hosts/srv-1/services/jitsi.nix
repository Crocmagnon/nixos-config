{ ... }:
{
  nixpkgs.config.permittedInsecurePackages = [
    "jitsi-meet-1.0.8792"
  ];
  services.jitsi-meet = {
    enable = true;
    hostName = "visio.g4b.ovh";
    nginx.enable = false;
    caddy.enable = true;
    #config = {
    # Add your custom configuration here
    #};
    #secureDomain.enable = true;
    #prosody.lockdown = true;
    #excalidraw.enable = true;
  };
  services.jitsi-videobridge.openFirewall = true;
}
