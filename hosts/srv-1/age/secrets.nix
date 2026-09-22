let
  # put the machine you want to deploy to here
  systems = {
    srv-1 = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIOYUgVy/1tek8HFNIHmYsmTdisPMDTQI/l1Y8SP7zsxZ";
  };
  # put which users should also be able to decrypt the secret
  users = {
    gaugendre-laptop = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIIBZRv1LUKsDbrjGJh051NCu40x9edBpERi68PgSzDW4";
    gaugendre-desktop = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIK5cJpHZTB9Sf6vmFAtieZ/8ffzs5Q4m8n9XVfkcZxG/";
    gaugendre-age = "age1el8d8hfa76kta040rhva7u64pfkuc8d6sujttqrq0tf7je0wqetqkz5hd9";
  };
  allUsers = builtins.attrValues users;
in
{
  "ovh-keys.age".publicKeys = allUsers ++ [ systems.srv-1 ];
  "miniflux-db.age".publicKeys = allUsers ++ [ systems.srv-1 ];
  "ovh-ldp-token.age".publicKeys = allUsers ++ [ systems.srv-1 ];
  "wallabag-env.age".publicKeys = allUsers ++ [ systems.srv-1 ];
  "s3-restic-srv-1-creds.age".publicKeys = allUsers ++ [ systems.srv-1 ];
  "paperless-env.age".publicKeys = allUsers ++ [ systems.srv-1 ];
  "restic-password.age".publicKeys = allUsers ++ [ systems.srv-1 ];
  "downloader-creds-env.age".publicKeys = allUsers ++ [ systems.srv-1 ];
  "healthchecks-api-key.age".publicKeys = allUsers ++ [ systems.srv-1 ];
  "tailscale-auth-key.age".publicKeys = allUsers ++ [ systems.srv-1 ];
  "rclone-config.age".publicKeys = allUsers ++ [ systems.srv-1 ];
  "transmission-credentials.age".publicKeys = allUsers ++ [ systems.srv-1 ];
}
