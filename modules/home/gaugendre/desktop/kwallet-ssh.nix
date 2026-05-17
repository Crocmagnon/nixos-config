{ pkgs, lib, ... }:
{
  home.sessionVariables = {
    SSH_ASKPASS = "${lib.getExe pkgs.kdePackages.ksshaskpass}";
    SSH_ASKPASS_REQUIRE = "prefer";
    PINENTRY_KDE_USE_WALLET = "1";
  };

  services.gpg-agent.pinentry.package = pkgs.pinentry-qt;
}
