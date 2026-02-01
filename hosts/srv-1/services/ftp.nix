{ ... }:
{
  services.vsftpd = {
    enable = true;
    localUsers = true;
    userlist = [ "printer" ];
    writeEnable = true;
    localRoot = "/var/ftp";
    extraConfig = ''
      local_umask=007
    '';
  };

  users.users.printer = {
    isNormalUser = true;
    password = "example-password";
    extraGroups = [ "vsftpd" ];
  };

  systemd.tmpfiles.rules = [ "d /var/ftp 2770 vsftpd vsftpd - -" ];
}
