{ downloader }:
final: prev: {
  inherit (downloader.packages.${prev.stdenv.hostPlatform.system}) downloader-go;
}
