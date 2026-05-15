{ ... }:
{
  accounts.email.accounts.Migadu = {
    enable = true;
    flavor = "migadu.com";
    primary = true;
    realName = "Gabriel Augendre";
    thunderbird.enable = true;
    userName = "gabriel@augendre.info";
    address = "gabriel@augendre.info";
  };
  programs.thunderbird = {
    enable = true;
    profiles.migadu.isDefault = true;
  };
}
