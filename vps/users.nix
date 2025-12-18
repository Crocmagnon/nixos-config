{pkgs, ...} : {
  users.users.gaugendre = {
    isNormalUser = true;
    description = "Gabriel Augendre";
    extraGroups = ["wheel"];
    shell = pkgs.fish;
    openssh.authorizedKeys.keys = [
      "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQDtkKhQocnBS3QlYhxRQNbiCvTSrtpn1hp+KywkNY/RrKHKUkqMVkBJO31UMsReOu0rlbGZ2VRgvK+3JC7TidEQGpjnP60oSqJFvM3z8oboBP2Kdd14JN1HlWNDZmeVy5wk9HUsFPwXAxPgV7cmagOSFufB40Z95+LimTeDceNF9V/Dllw0nDzOOCc7zHlsjDT2YCPfKDUT6uDbr/xK/RxDgv6KMd0I61B9hOg8BTjUfqBq52mqOVO/EOLQt9+pb2IAxDRmQ1wEo07S0Jci+PDYAtyDezKbyg7jImn6H53GamHMUh9hyc7BDMRb/71FL630zvZrWLA/dqbvqpBgCKqsyzNdSqPNSi5qb5EABmdYJOSIE5zGlKS94qGfKAwg+CyzpTE7r1scTcCcCXaJOQI6cHUtznSoy1biFeyDl0Z7lHFuXIJw1jN6Z3l3KGmsm/5Byz3aU0Ny4A4MdBAcOnxymoQXG0TORQTGo33aACLf3+Migb3f9x+DtaCEEsaXoqSbBqGCJV8yLoW2AyrIevWRdjhTHT8A/t3p+tsjD6sGY7cgrZZhuqtQfnyCQlWtvvQ7vdegA5E7Os2ZPPvi4J6g0Pye6uhVlRAQDSlu+kAAkcOdw4p3HjViMmNWOZqEqF7B9pLcqNzO5oIHvBVaNoZhBYCEOdxFR/nm3KoNjZdYeQ== gaugendre@bw"
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAICrYej4+TVx8lPx5SPpSHRyOPhYW+aVKk9sujfOMs9Sf gabriel@augendre.info"
    ];
  };

  users.users.root = {
    shell = pkgs.fish;
    openssh.authorizedKeys.keys = [
      "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQDtkKhQocnBS3QlYhxRQNbiCvTSrtpn1hp+KywkNY/RrKHKUkqMVkBJO31UMsReOu0rlbGZ2VRgvK+3JC7TidEQGpjnP60oSqJFvM3z8oboBP2Kdd14JN1HlWNDZmeVy5wk9HUsFPwXAxPgV7cmagOSFufB40Z95+LimTeDceNF9V/Dllw0nDzOOCc7zHlsjDT2YCPfKDUT6uDbr/xK/RxDgv6KMd0I61B9hOg8BTjUfqBq52mqOVO/EOLQt9+pb2IAxDRmQ1wEo07S0Jci+PDYAtyDezKbyg7jImn6H53GamHMUh9hyc7BDMRb/71FL630zvZrWLA/dqbvqpBgCKqsyzNdSqPNSi5qb5EABmdYJOSIE5zGlKS94qGfKAwg+CyzpTE7r1scTcCcCXaJOQI6cHUtznSoy1biFeyDl0Z7lHFuXIJw1jN6Z3l3KGmsm/5Byz3aU0Ny4A4MdBAcOnxymoQXG0TORQTGo33aACLf3+Migb3f9x+DtaCEEsaXoqSbBqGCJV8yLoW2AyrIevWRdjhTHT8A/t3p+tsjD6sGY7cgrZZhuqtQfnyCQlWtvvQ7vdegA5E7Os2ZPPvi4J6g0Pye6uhVlRAQDSlu+kAAkcOdw4p3HjViMmNWOZqEqF7B9pLcqNzO5oIHvBVaNoZhBYCEOdxFR/nm3KoNjZdYeQ== gaugendre@bw"
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAICrYej4+TVx8lPx5SPpSHRyOPhYW+aVKk9sujfOMs9Sf gabriel@augendre.info"
    ];
  };

  # passwordless sudo
  security.sudo.extraRules = [{
    users = [ "gaugendre" ];
    commands = [
      {
        command = "ALL";
        options = [ "SETENV" "NOPASSWD" ];
      }
    ];
  }];

  # allow deploying config from non-root user
  nix.settings.trusted-users = [
    "gaugendre"
  ];
}