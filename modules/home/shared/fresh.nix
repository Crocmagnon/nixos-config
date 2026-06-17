{
  pkgs,
  ...
}:
{
  programs.fresh-editor = {
    enable = true;
    defaultEditor = false;
    package = pkgs.fresh-editor;
  };
}
