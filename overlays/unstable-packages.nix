{ nixpkgs-unstable }:
final: prev: {
  inherit
    (import nixpkgs-unstable {
      system = final.stdenv.hostPlatform.system;
      config.allowUnfree = true;
    })
    btop
    amp-cli
    jetbrains
    ;
}
