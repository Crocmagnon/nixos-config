{ pkgs, ... }:
{
  home.packages = with pkgs; [
    luajit
    lua51Packages.luarocks
    lua51Packages.luacheck
    lua51Packages.busted
    stylua
    lua-language-server
  ];

  programs.helix.languages = {
    language = [
      {
        name = "lua";
        auto-format = true;
        formatter.command = "stylua";
        formatter.args = [ "-" ];
      }
    ];
    language-server = {
      lua-language-server.config.Lua = {
        runtime.version = "LuaJIT";
        diagnostics.globals = [ "vim" ];
      };
    };
  };
}
