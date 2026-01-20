import 'dart:typed_data';

import 'package:mofu_audio_metadata/src/models/audio_metadata.dart';
import 'package:mofu_audio_metadata/src/models/parse_options.dart';
import 'package:mofu_audio_metadata/src/formats/id3/id3v1_parser.dart';
import 'package:mofu_audio_metadata/src/formats/id3/id3v2_parser.dart';
import 'package:mofu_audio_metadata/src/parsers/metadata_parser.dart';
import 'package:mofu_audio_metadata/src/utils/binary_utils.dart';
import 'package:mofu_audio_metadata/src/utils/tag_utils.dart';

/// Parser for AAC audio files encapsulated in the Audio Data Transport Stream (ADTS) container.
class AacParser implements MetadataParser {
  /// Returns true if the given bytes are a valid AAC format, false otherwise.
  @override
  bool canParse(Uint8List bytes) {
    if (bytes.length < 10) return false;

    // Check for ID3v2 tag at beginning
    var offset = 0;
    if (ID3v2Parser.hasID3v2Tag(bytes)) {
      // Skip ID3v2 tag
      final tagSize = BinaryUtils.parseSynchsafeInt32(bytes, 6);
      offset = 10 + tagSize;

      if (offset >= bytes.length) return false;
    }

    // Check for ADTS sync word (0xFFF)
    if (offset + 2 <= bytes.length) {
      final syncWord = (bytes[offset] << 4) | (bytes[offset + 1] >> 4);
      if (syncWord == 0xFFF) {
        return true;
      }
    }

    // Also check for ID3v1 at end with ADTS frames
    if (bytes.length >= 128) {
      if (ID3v1Parser.hasID3v1Tag(bytes)) {
        // Check for ADTS frames before ID3v1
        final beforeTag = bytes.length - 128 - 2;
        if (beforeTag >= 0) {
          final syncWord = (bytes[beforeTag] << 4) | (bytes[beforeTag + 1] >> 4);
          return syncWord == 0xFFF;
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
    if (!canParse(bytes)) {
      throw FormatException('Invalid AAC file');
    }

    Map<String, List<String>> id3v2Frames = {};
    List<AlbumArt> pictures = [];
    Map<String, String?> id3v1Tags = {};

    // Check for ID3v2 at beginning
    if (ID3v2Parser.hasID3v2Tag(bytes)) {
      final id3v2Data = ID3v2Parser.parse(bytes, options);
      id3v2Frames = id3v2Data['frames'] as Map<String, List<String>>? ?? {};
      pictures = id3v2Data['pictures'] as List<AlbumArt>? ?? [];
    }

    // Check for ID3v1 at end (only if metadata requested)
    if (options.includeMetadata && ID3v1Parser.hasID3v1Tag(bytes)) {
      id3v1Tags = ID3v1Parser.parse(bytes);
    }

    return _buildMetadata(id3v2Frames, id3v1Tags, pictures);
  }

  AudioMetadata _buildMetadata(
    Map<String, List<String>> id3v2Frames, Map<String, String?> id3v1Tags, List<AlbumArt> pictures
  ) {
    // Prefer ID3v2, fallback to ID3v1
    final title =
        TagUtils.getFirstMatchingValue(id3v2Frames, ['TIT2', 'TT2']) ??
        id3v1Tags['title'];

    final artist =
        TagUtils.getFirstMatchingValue(id3v2Frames, ['TPE1', 'TP1']) ??
        id3v1Tags['artist'];

    final album =
        TagUtils.getFirstMatchingValue(id3v2Frames, ['TALB', 'TAL']) ??
        id3v1Tags['album'];

    final albumArtist = TagUtils.getFirstMatchingValue(id3v2Frames, [
      'TPE2',
      'TP2'
    ]);

    final date =
        TagUtils.getFirstMatchingValue(id3v2Frames, ['TDRC', 'TYER', 'TYE']) ??
        id3v1Tags['date'];

    final genre =
        TagUtils.getFirstMatchingValue(id3v2Frames, ['TCON', 'TCO']) ??
        id3v1Tags['genre'];

    final comment =
        TagUtils.getFirstMatchingValue(id3v2Frames, ['COMM', 'COM']) ??
        id3v1Tags['comment'];

    final composer = TagUtils.getFirstMatchingValue(id3v2Frames, [
      'TCOM',
      'TCM'
    ]);

    final publisher = TagUtils.getFirstMatchingValue(id3v2Frames, [
      'TPUB',
      'TPB'
    ]);

    final lyrics = TagUtils.getFirstMatchingValue(id3v2Frames, [
      'USLT',
      'ULT'
    ]);

    // Parse track number
    final trackStr =
        TagUtils.getFirstMatchingValue(id3v2Frames, ['TRCK', 'TRK']) ??
        id3v1Tags['trackNumber'];

    final (trackNumber, totalTracks) = TagUtils.parseNumberSlashTotal(trackStr);

    // Parse disc number
    final discStr = TagUtils.getFirstMatchingValue(id3v2Frames, [
      'TPOS',
      'TPA'
    ]);

    final (discNumber, totalDiscs) = TagUtils.parseNumberSlashTotal(discStr);

    // Get album art
    final albumArt = pictures.isNotEmpty ? pictures.first : null;

    // Combine tags for raw output
    final rawTags = <String, List<String>>{};

    id3v2Frames.forEach((key, value) {
      rawTags[key] = value;
    });

    id3v1Tags.forEach((key, value) {
      if (value != null) {
        rawTags['ID3v1:$key'] = [value];
      }
    });

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
      rawTags: rawTags
    );
  }
}
