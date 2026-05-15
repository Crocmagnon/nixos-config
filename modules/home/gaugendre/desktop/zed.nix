{ config, ... }:
{
  programs.zed-editor = {
    enable = true;
    extensions = [
      "nix"
      "toml"
      "terraform"
      "yaml"
      "json"
      "markdown"
    ];
    extraPackages = config.programs.helix.extraPackages;
  };
}
