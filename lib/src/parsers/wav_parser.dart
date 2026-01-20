import 'dart:typed_data';

import 'package:mofu_audio_metadata/src/models/audio_metadata.dart';
import 'package:mofu_audio_metadata/src/models/parse_options.dart';
import 'package:mofu_audio_metadata/src/formats/id3/id3v2_parser.dart';
import 'package:mofu_audio_metadata/src/parsers/metadata_parser.dart';
import 'package:mofu_audio_metadata/src/utils/binary_utils.dart';
import 'package:mofu_audio_metadata/src/utils/tag_utils.dart';

/// Parser for WAV audio files
class WavParser implements MetadataParser {
  static const _riffSignature = [0x52, 0x49, 0x46, 0x46]; // "RIFF"
  static const _waveSignature = [0x57, 0x41, 0x56, 0x45]; // "WAVE"

  /// Returns true if the given bytes are a valid WAV format, false otherwise.
  @override
  bool canParse(Uint8List bytes) {
    if (bytes.length < 12) return false;

    // Check for RIFF signature
    if (!_hasSignature(bytes, 0, _riffSignature)) return false;

    // Check for WAVE signature
    return _hasSignature(bytes, 8, _waveSignature);
  }

  /// Parse byte array and return AudioMetadata if the format is supported.
  /// 
  /// Options are set using the [ParseOptions] parameter, defaulting to [ParseOptions.all].
  @override
  AudioMetadata parse(Uint8List bytes, [ParseOptions options = ParseOptions.all]) {
    if (!canParse(bytes)) {
      throw FormatException('Invalid WAV file');
    }

    Map<String, List<String>> frames = {};
    List<AlbumArt> pictures = [];
    Map<String, String> listInfoTags = {};

    var offset = 12; // Skip RIFF header and WAVE signature

    // Scan for chunks
    while (offset + 8 <= bytes.length) {
      final chunkId = String.fromCharCodes(bytes.sublist(offset, offset + 4));
      final chunkSize = BinaryUtils.readUint32LE(bytes, offset + 4);

      offset += 8;

      if (offset + chunkSize > bytes.length) break;

      final chunkData = bytes.sublist(offset, offset + chunkSize);

      switch (chunkId) {
        case 'id3 ':
        case 'ID3 ':
          // ID3v2 tag
          if (ID3v2Parser.hasID3v2Tag(chunkData)) {
            final id3v2Data = ID3v2Parser.parse(chunkData, options);
            frames = id3v2Data['frames'] as Map<String, List<String>>? ?? {};
            pictures = id3v2Data['pictures'] as List<AlbumArt>? ?? [];
          }
          break;
        case 'LIST':
          // INFO chunk (RIFF INFO tags) - only parse if metadata requested
          if (options.includeMetadata && chunkData.length >= 4) {
            final listType = String.fromCharCodes(chunkData.sublist(0, 4));
            if (listType == 'INFO') {
              listInfoTags = _parseListInfo(chunkData.sublist(4));
            }
          }
          break;
      }

      offset += chunkSize;

      // Chunks are word-aligned
      if (chunkSize % 2 == 1) {
        offset++;
      }
    }

    return _buildMetadata(frames, pictures, listInfoTags);
  }

  Map<String, String> _parseListInfo(Uint8List data) {
    final tags = <String, String>{};
    var offset = 0;

    while (offset + 8 <= data.length) {
      final chunkId = String.fromCharCodes(data.sublist(offset, offset + 4));
      final chunkSize = BinaryUtils.readUint32LE(data, offset + 4);

      offset += 8;

      if (offset + chunkSize > data.length) break;

      // Read null-terminated string
      var textEnd = offset;
      while (textEnd < offset + chunkSize && data[textEnd] != 0) {
        textEnd++;
      }

      final text = String.fromCharCodes(data.sublist(offset, textEnd));
      if (text.isNotEmpty) {
        tags[chunkId] = text;
      }

      offset += chunkSize;

      // Word-aligned
      if (chunkSize % 2 == 1) {
        offset++;
      }
    }

    return tags;
  }

  AudioMetadata _buildMetadata(
    Map<String, List<String>> id3v2Frames, List<AlbumArt> pictures, Map<String, String> listInfoTags
  ) {
    // Prefer ID3v2 tags, fallback to LIST INFO
    final title =
        TagUtils.getFirstMatchingValue(id3v2Frames, ['TIT2', 'TT2']) ??
        listInfoTags['INAM'];

    final artist =
        TagUtils.getFirstMatchingValue(id3v2Frames, ['TPE1', 'TP1']) ??
        listInfoTags['IART'];

    final album =
        TagUtils.getFirstMatchingValue(id3v2Frames, ['TALB', 'TAL']) ??
        listInfoTags['IPRD'];

    final albumArtist = TagUtils.getFirstMatchingValue(id3v2Frames, [
      'TPE2',
      'TP2'
    ]);

    final date =
        TagUtils.getFirstMatchingValue(id3v2Frames, ['TDRC', 'TYER', 'TYE']) ??
        listInfoTags['ICRD'];

    final genre =
        TagUtils.getFirstMatchingValue(id3v2Frames, ['TCON', 'TCO']) ??
        listInfoTags['IGNR'];

    final comment =
        TagUtils.getFirstMatchingValue(id3v2Frames, ['COMM', 'COM']) ??
        listInfoTags['ICMT'];

    final composer =
        TagUtils.getFirstMatchingValue(id3v2Frames, ['TCOM', 'TCM']) ??
        listInfoTags['IMUS'];

    final publisher = TagUtils.getFirstMatchingValue(id3v2Frames, [
      'TPUB',
      'TPB'
    ]);

    // Lyrics
    final lyrics = TagUtils.getFirstMatchingValue(id3v2Frames, [
      'USLT',
      'ULT'
    ]);

    // Parse track number
    final trackStr =
        TagUtils.getFirstMatchingValue(id3v2Frames, ['TRCK', 'TRK']) ??
        listInfoTags['ITRK'];

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

    listInfoTags.forEach((key, value) {
      rawTags[key] = [value];
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

  bool _hasSignature(Uint8List bytes, int offset, List<int> signature) {
    return TagUtils.matchesSignature(bytes, offset, signature);
  }
}
