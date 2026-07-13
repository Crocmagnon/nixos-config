{ pkgs, ... }:
let
  arsenik = pkgs.fetchFromGitHub {
    owner = "OneDeadKey";
    repo = "arsenik";
    rev = "47809b86fdc7bf8b13d377be6d5c12df7f1ad7d1";
    sha256 = "sha256-nneF5aGenfvA7A/JOFOzAUa3psa40kkEhZRfdKuLrHE=";
  };
in
{
  services.kanata = {
    enable = true;
    keyboards.arsenik = {
      configFile = "${arsenik}/kanata/kanata.kbd";
    };
  };

  environment.systemPackages = with pkgs; [
    kanata
  ];
}
