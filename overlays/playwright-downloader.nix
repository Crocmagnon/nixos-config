{ playwright, downloader }:
final: prev: {
  inherit (playwright.packages.${prev.system}) playwright-driver;
  inherit (downloader.packages.${prev.system}) downloader-go;
}
