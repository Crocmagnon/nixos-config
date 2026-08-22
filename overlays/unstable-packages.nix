{ nixpkgs-unstable }:
final: prev: {
  inherit
    (import nixpkgs-unstable {
      system = final.stdenv.hostPlatform.system;
      config.allowUnfree = true;
    })
    btop
    gokrazy
    uv
    claude-code
    prek
    esphome
    ha-mcp
    fresh-editor
    gh

    gotools
    gopls
    golangci-lint
    golangci-lint-langserver
    delve

    koreader
    ;
}
