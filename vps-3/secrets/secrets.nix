let
  # put the machine you want to deploy to here
  systems = {
    vps-3 = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIM8fhdlCTZLy1utuLtkV1oF3TX5HQ/1YRp62g1lKS8GP";
  };
  # put which users should also be able to decrypt the secret
  users = {
    gaugendre = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIIBZRv1LUKsDbrjGJh051NCu40x9edBpERi68PgSzDW4";
  };
  allUsers = builtins.attrValues users;
  allSystems = builtins.attrValues systems;
in {
  "ovh-keys.age".publicKeys = allUsers ++ [systems.vps-3];
  "miniflux-db.age".publicKeys = allUsers ++ [systems.vps-3];
  "ovh-ldp-token.age".publicKeys = allUsers ++ [systems.vps-3];
}
