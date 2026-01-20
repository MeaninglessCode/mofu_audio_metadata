/// Class to hold all metadata extracted from a particular audio file. Has a custom Map for storing
/// raw tags that aren't mapped to any standard metadata field.
class AudioMetadata {
  final String? title;
  final String? artist;
  final String? album;
  final String? albumArtist;
  final String? date;
  final int? trackNumber;
  final int? totalTracks;
  final int? discNumber;
  final int? totalDiscs;
  final String? genre;
  final String? comment;
  final String? composer;
  final String? publisher;
  final String? lyrics;
  final AlbumArt? albumArt;

  /// Raw tags that weren't mapped to standard fields
  final Map<String, List<String>> rawTags;

  const AudioMetadata({
    this.title,
    this.artist,
    this.album,
    this.albumArtist,
    this.date,
    this.trackNumber,
    this.totalTracks,
    this.discNumber,
    this.totalDiscs,
    this.genre,
    this.comment,
    this.composer,
    this.publisher,
    this.lyrics,
    this.albumArt,
    this.rawTags = const {}
  });

  /// Creates a copy of this AudioMetadata with the given fields replaced.
  AudioMetadata copyWith({
    String? title,
    String? artist,
    String? album,
    String? albumArtist,
    String? date,
    int? trackNumber,
    int? totalTracks,
    int? discNumber,
    int? totalDiscs,
    String? genre,
    String? comment,
    String? composer,
    String? publisher,
    String? lyrics,
    AlbumArt? albumArt,
    Map<String, List<String>>? rawTags,
    bool clearTitle = false,
    bool clearArtist = false,
    bool clearAlbum = false,
    bool clearAlbumArtist = false,
    bool clearDate = false,
    bool clearTrackNumber = false,
    bool clearTotalTracks = false,
    bool clearDiscNumber = false,
    bool clearTotalDiscs = false,
    bool clearGenre = false,
    bool clearComment = false,
    bool clearComposer = false,
    bool clearPublisher = false,
    bool clearLyrics = false,
    bool clearAlbumArt = false
  }) {
    return AudioMetadata(
      title: clearTitle ? null : (title ?? this.title),
      artist: clearArtist ? null : (artist ?? this.artist),
      album: clearAlbum ? null : (album ?? this.album),
      albumArtist: clearAlbumArtist ? null : (albumArtist ?? this.albumArtist),
      date: clearDate ? null : (date ?? this.date),
      trackNumber: clearTrackNumber ? null : (trackNumber ?? this.trackNumber),
      totalTracks: clearTotalTracks ? null : (totalTracks ?? this.totalTracks),
      discNumber: clearDiscNumber ? null : (discNumber ?? this.discNumber),
      totalDiscs: clearTotalDiscs ? null : (totalDiscs ?? this.totalDiscs),
      genre: clearGenre ? null : (genre ?? this.genre),
      comment: clearComment ? null : (comment ?? this.comment),
      composer: clearComposer ? null : (composer ?? this.composer),
      publisher: clearPublisher ? null : (publisher ?? this.publisher),
      lyrics: clearLyrics ? null : (lyrics ?? this.lyrics),
      albumArt: clearAlbumArt ? null : (albumArt ?? this.albumArt),
      rawTags: rawTags ?? this.rawTags
    );
  }

  /// Converts the audio metadata into a string output for easy printing.
  @override
  String toString() {
    final buffer = StringBuffer('AudioMetadata(\n');
    if (title != null) buffer.writeln('  title: $title');
    if (artist != null) buffer.writeln('  artist: $artist');
    if (album != null) buffer.writeln('  album: $album');
    if (albumArtist != null) buffer.writeln('  albumArtist: $albumArtist');
    if (date != null) buffer.writeln('  date: $date');
    if (trackNumber != null) buffer.writeln('  trackNumber: $trackNumber');
    if (totalTracks != null) buffer.writeln('  totalTracks: $totalTracks');
    if (discNumber != null) buffer.writeln('  discNumber: $discNumber');
    if (totalDiscs != null) buffer.writeln('  totalDiscs: $totalDiscs');
    if (genre != null) buffer.writeln('  genre: $genre');
    if (comment != null) buffer.writeln('  comment: $comment');
    if (composer != null) buffer.writeln('  composer: $composer');
    if (publisher != null) buffer.writeln('  publisher: $publisher');
    if (lyrics != null) buffer.writeln('  lyrics: ${lyrics!.length} chars');
    if (albumArt != null) buffer.writeln('  albumArt: ${albumArt!.mimeType}');
    if (rawTags.isNotEmpty) buffer.writeln('  rawTags: ${rawTags.length} tags');
    buffer.write(')');
    return buffer.toString();
  }
}

/// Class to hold an album's extracted art metadata.
class AlbumArt {
  final String mimeType;
  final List<int> data;
  final String? description;

  const AlbumArt({
    required this.mimeType,
    required this.data,
    this.description
  });
}
