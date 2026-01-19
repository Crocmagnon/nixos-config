{ playwright, downloader }:
final: prev: {
  inherit (playwright.packages.${prev.stdenv.hostPlatform.system}) playwright-driver;
  inherit (downloader.packages.${prev.stdenv.hostPlatform.system}) downloader-go;
}
