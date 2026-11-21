{ readlist-tagger }:
final: prev: {
  inherit (readlist-tagger.packages.${prev.stdenv.hostPlatform.system}) readeck-tagger wallabag-tagger;
}
