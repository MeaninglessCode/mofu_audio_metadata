import 'dart:typed_data';

import 'package:mofu_audio_metadata/src/models/audio_metadata.dart';
import 'package:mofu_audio_metadata/src/models/parse_options.dart';
import 'package:mofu_audio_metadata/src/parsers/metadata_parser.dart';
import 'package:mofu_audio_metadata/src/formats/id3/id3v1_parser.dart';
import 'package:mofu_audio_metadata/src/formats/id3/id3v2_parser.dart';
import 'package:mofu_audio_metadata/src/utils/tag_utils.dart';

/// Parser for MP3 audio files
class Mp3Parser implements MetadataParser {
  /// Returns true if the given bytes are a valid MP3 format, false otherwise.
  @override
  bool canParse(Uint8List bytes) {
    // Check for ID3v2 tag at start
    if (ID3v2Parser.hasID3v2Tag(bytes)) {
      return true;
    }

    // Check for MP3 frame sync at the start of the file
    // Only check first few bytes, not entire file to avoid false positives
    if (_hasMp3FrameSyncAtStart(bytes)) {
      return true;
    }

    // Check for ID3v1 tag at end (without ID3v2 or frame sync, this is rare)
    // Only return true if we also find a frame sync before the ID3v1 tag
    if (ID3v1Parser.hasID3v1Tag(bytes) && bytes.length > 128) {
      // Check for frame sync before ID3v1 tag
      final audioEnd = bytes.length - 128;
      for (var i = 0; i + 1 < audioEnd && i < 4096; i++) {
        if (bytes[i] == 0xFF && (bytes[i + 1] & 0xE0) == 0xE0) {
          return true;
        }
      }
    }

    return false;
  }

  bool _hasMp3FrameSyncAtStart(Uint8List bytes) {
    if (bytes.length < 2) return false;

    // Check first few bytes for frame sync
    // MP3 files typically start with frame sync right away (unless ID3v2 exists)
    for (var i = 0; i < bytes.length - 1 && i < 16; i++) {
      if (bytes[i] == 0xFF && (bytes[i + 1] & 0xE0) == 0xE0) {
        // Additional validation: check MPEG audio layer bits
        final layerBits = (bytes[i + 1] >> 1) & 0x03;
        // Layer must be 01, 10, or 11 (not 00 which is reserved)
        if (layerBits != 0) {
          return true;
        }
      }
    }
    return false;
  }

  /// Parse byte array and return AudioMetadata if the format is supported.
  /// 
  /// Options are set using the [ParseOptions] parameter, defaulting to [ParseOptions.all].
  @override
  AudioMetadata parse(Uint8List bytes, [ParseOptions options = ParseOptions.all]) {
    Map<String, List<String>> frames = {};
    List<AlbumArt> pictures = [];

    // Parse ID3v2 tag (priority: most detailed)
    if (ID3v2Parser.hasID3v2Tag(bytes)) {
      final id3v2Data = ID3v2Parser.parse(bytes, options);

      frames = id3v2Data['frames'] as Map<String, List<String>>? ?? {};
      pictures = id3v2Data['pictures'] as List<AlbumArt>? ?? [];
    }

    // Parse ID3v1 tag as fallback for missing fields (only if metadata requested)
    Map<String, String?> id3v1Data = {};
    if (options.includeMetadata && ID3v1Parser.hasID3v1Tag(bytes)) {
      id3v1Data = ID3v1Parser.parse(bytes);
    }

    return _buildMetadata(frames, pictures, id3v1Data);
  }

  AudioMetadata _buildMetadata(
    Map<String, List<String>> id3v2Frames, List<AlbumArt> pictures, Map<String, String?> id3v1Data
  ) {
    // ID3v2.3/v2.4 frame mappings
    final title =
        TagUtils.getFirstMatchingValue(id3v2Frames, ['TIT2', 'TT2']) ??
        id3v1Data['title'];

    final artist =
        TagUtils.getFirstMatchingValue(id3v2Frames, ['TPE1', 'TP1']) ??
        id3v1Data['artist'];

    final album =
        TagUtils.getFirstMatchingValue(id3v2Frames, ['TALB', 'TAL']) ??
        id3v1Data['album'];

    final albumArtist = TagUtils.getFirstMatchingValue(id3v2Frames, [
      'TPE2',
      'TP2'
    ]);

    final date =
        TagUtils.getFirstMatchingValue(id3v2Frames, ['TDRC', 'TYER', 'TYE']) ??
        id3v1Data['date'];

    final genre =
        TagUtils.getFirstMatchingValue(id3v2Frames, ['TCON', 'TCO']) ??
        id3v1Data['genre'];

    final comment =
        TagUtils.getFirstMatchingValue(id3v2Frames, ['COMM', 'COM']) ??
        id3v1Data['comment'];

    final composer = TagUtils.getFirstMatchingValue(id3v2Frames, [
      'TCOM',
      'TCM'
    ]);

    final publisher = TagUtils.getFirstMatchingValue(id3v2Frames, [
      'TPUB',
      'TPB'
    ]);

    // Lyrics (USLT = v2.3+, ULT = v2.2)
    final lyrics = TagUtils.getFirstMatchingValue(id3v2Frames, [
      'USLT',
      'ULT'
    ]);

    // Parse track number
    final trackStr =
        TagUtils.getFirstMatchingValue(id3v2Frames, ['TRCK', 'TRK']) ??
        id3v1Data['trackNumber'];

    final (trackNumber, totalTracks) = TagUtils.parseNumberSlashTotal(trackStr);

    // Parse disc number
    final discStr = TagUtils.getFirstMatchingValue(id3v2Frames, [
      'TPOS',
      'TPA'
    ]);

    final (discNumber, totalDiscs) = TagUtils.parseNumberSlashTotal(discStr);

    // Get album art
    final albumArt = pictures.isNotEmpty ? pictures.first : null;

    return AudioMetadata(
      title: title,
      artist: artist,
      album: album,
      albumArtist: albumArtist,
      date: date,
      trackNumber: trackNumber,
      totalTracks: totalTracks,
      discNumber: discNumber,
      totalDiscs: totalDiscs,
      genre: genre,
      comment: comment,
      composer: composer,
      publisher: publisher,
      lyrics: lyrics,
      albumArt: albumArt,
      rawTags: id3v2Frames
    );
  }
}
