{ wallabag-tagger }:
final: prev: {
  inherit (wallabag-tagger.packages.${prev.stdenv.hostPlatform.system}) wallabag-tagger;
}
