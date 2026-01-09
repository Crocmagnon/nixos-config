let
  # put the machine you want to deploy to here
  systems = {
    vps-3 = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIG5wkVojnWXHMmmW8JtCm8KNevjn95H6pphuS3ES9yWv";
  };
  # put which users should also be able to decrypt the secret
  users = {
    gaugendre = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIIBZRv1LUKsDbrjGJh051NCu40x9edBpERi68PgSzDW4";
  };
  allUsers = builtins.attrValues users;
in
{
  "ovh-keys.age".publicKeys = allUsers ++ [ systems.vps-3 ];
  "miniflux-db.age".publicKeys = allUsers ++ [ systems.vps-3 ];
  "ovh-ldp-token.age".publicKeys = allUsers ++ [ systems.vps-3 ];
  "wallabag-env.age".publicKeys = allUsers ++ [ systems.vps-3 ];
  "paperless-s3-creds.age".publicKeys = allUsers ++ [ systems.vps-3 ];
  "paperless-env.age".publicKeys = allUsers ++ [ systems.vps-3 ];
  "restic-password.age".publicKeys = allUsers ++ [ systems.vps-3 ];
  "syncthing-gui-password.age".publicKeys = allUsers ++ [ systems.vps-3 ];
  "downloader-creds-env.age".publicKeys = allUsers ++ [ systems.vps-3 ];
  "healthchecks-api-key.age".publicKeys = allUsers ++ [ systems.vps-3 ];
  "tailscale-auth-key.age".publicKeys = allUsers ++ [ systems.vps-3 ];
  "rclone-config.age".publicKeys = allUsers ++ [ systems.vps-3 ];
}
