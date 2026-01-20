/// Options for controlling what metadata to parse.
class ParseOptions {
  final bool includeMetadata;
  final bool includeAlbumArt;

  const ParseOptions({
    this.includeMetadata = true,
    this.includeAlbumArt = true
  });

  static const all = ParseOptions();
  static const noAlbumArt = ParseOptions(includeAlbumArt: false);
  static const albumArtOnly = ParseOptions(includeMetadata: false);
}
