# Rotatrix, 3D trackball for CAD. Proprietary AppImage, not in nixpkgs, downloadable only with a
# license key -> the key is not committed here (public repo). See "Proprietary AppImages" in
# README.md for the one-time per-machine setup of /etc/rotatrix-key.
{ pkgs, ... }:
let
  version = "1.5.1";
  pname = "rotatrix";
  # The key only gates the download, so it stays out of the derivation: the builder reads it from a
  # file bind-mounted into the sandbox (extra-sandbox-paths below). It never enters the store.
  keyFile = "/etc/rotatrix-key";
  src =
    pkgs.runCommand "Rotatrix-${version}-linux-x86_64.AppImage"
      {
        outputHashAlgo = "sha256";
        outputHashMode = "flat";
        outputHash = "sha256-fg5cuuBVJiunI8WUBFSRB9GGqM8SF8/USc/z5G9oBZo=";
        nativeBuildInputs = [ pkgs.curl ];
        SSL_CERT_FILE = "${pkgs.cacert}/etc/ssl/certs/ca-bundle.crt";
      }
      ''
        test -r ${keyFile} || { echo "missing ${keyFile}, see README 'Proprietary AppImages'"; exit 1; }
        # URL through --config, not argv: the key would otherwise sit in `ps` for the whole download.
        printf 'url = "https://download.rotatrix.com/download?path=rotatrix%%2FRotatrix-${version}-linux-x86_64.AppImage&key=%s&name=Rotatrix-linux-x86_64.AppImage"\n' \
          "$(cat ${keyFile})" | curl -fsSL --retry 3 -o $out --config -
      '';
  contents = pkgs.appimageTools.extract { inherit version src pname; };
  rotatrix = pkgs.appimageTools.wrapType2 {
    inherit version src pname;
    meta.license = pkgs.lib.licenses.unfree;
    # wrapType2 only symlinks the binary; the .desktop (already `Exec=rotatrix`) and icons are on
    # us. It doubles as the autostart entry — leave the app's own "start on login" off, it writes a
    # ~/.config/autostart entry that points past the FHS wrapper, under a name that wouldn't
    # shadow ours.
    extraInstallCommands = ''
      install -Dm444 ${contents}/RotatrixApp.desktop -t $out/share/applications
      install -Dm444 ${contents}/RotatrixApp.desktop -t $out/etc/xdg/autostart
      cp -r ${contents}/usr/share/icons $out/share
    '';
    # Its `app:` profile triggers match /proc/<pid>/comm, so FreeCAD reads as `.FreeCAD-wrappe` and
    # the built-in profile (`app:freecad tag:app.freecad`) silently never fires. Not fixable here:
    # in the app, Customize the profile and add the wrapped name as a second alternative. Dropping
    # `app:` is not equivalent — `tag:` alone also matches FreeCAD sitting in the background.
  };
in
{
  # Set here too so Rotatrix keeps building if nrfconnect.nix ever goes away.
  nixpkgs.config.allowUnfree = true;

  # Trailing `?` = optional, so a machine without the key still evaluates and builds everything
  # else; only the fetch above fails, with the message it prints. Note this is a daemon-wide
  # setting: every sandboxed build on the machine gets the file mounted, so keep it 440 root:nixbld
  # and don't put anything more valuable than a download key there.
  nix.settings.extra-sandbox-paths = [ "${keyFile}?" ];

  environment.systemPackages = [ rotatrix ];

  # uinput for the virtual scroll/keyboard devices it creates (Steam's rules happen to grant it too,
  # don't rely on that), input for /dev/input/event*, already root:input 0660, read for hotkeys.
  hardware.uinput.enable = true;
  users.users.gaugendre.extraGroups = [
    "input"
    "uinput"
  ];

  # Stands in for the 70-rotatrix.rules the app fails to install itself on NixOS. Its TAG+="uaccess"
  # becomes GROUP/MODE: extraRules lands in 99-local.rules, too late for the uaccess builtin.
  services.udev.extraRules = ''
    KERNEL=="hidraw*", SUBSYSTEM=="hidraw", ATTRS{idVendor}=="2e8a", ATTRS{idProduct}=="1108", GROUP="input", MODE="0660"
  '';
}
