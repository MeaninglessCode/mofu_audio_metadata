import 'dart:typed_data';

import 'package:mofu_audio_metadata/src/models/audio_metadata.dart';
import 'package:mofu_audio_metadata/src/models/parse_options.dart';
import 'package:mofu_audio_metadata/src/parsers/metadata_parser.dart';
import 'package:mofu_audio_metadata/src/containers/ogg_container.dart';
import 'package:mofu_audio_metadata/src/formats/vorbis/vorbis_comment_parser.dart';
import 'package:mofu_audio_metadata/src/utils/binary_utils.dart';
import 'package:mofu_audio_metadata/src/utils/picture_utils.dart';
import 'package:mofu_audio_metadata/src/utils/tag_utils.dart';

/// Parser for FLAC audio files.
class FlacParser implements MetadataParser {
  static const _flacSignature = [0x66, 0x4C, 0x61, 0x43]; // "fLaC"

  /// Returns true if the given bytes are a valid FLAC format, false otherwise.
  @override
  bool canParse(Uint8List bytes) {
    // Check for native FLAC
    if (bytes.length >= 4 && _hasFlacSignature(bytes, 0)) {
      return true;
    }

    // Check for Ogg FLAC
    if (OggContainer.isOggFile(bytes)) {
      final pages = OggContainer.parsePages(bytes);

      if (pages.isNotEmpty && pages.first.data.length >= 5) {
        final signature = pages.first.data.sublist(1, 5);
        return signature[0] == 0x46 && signature[1] == 0x4C && signature[2] == 0x41 && signature[3] == 0x43; // "\x7FLAC"
      }
    }

    return false;
  }

  /// Parse byte array and return AudioMetadata if the format is supported.
  /// 
  /// Options are set using the [ParseOptions] parameter, defaulting to [ParseOptions.all].
  @override
  AudioMetadata parse(Uint8List bytes, [ParseOptions options = ParseOptions.all]) {
    // Check if it's Ogg FLAC
    if (OggContainer.isOggFile(bytes)) {
      return _parseOggFlac(bytes, options);
    }

    // Parse native FLAC
    return _parseNativeFlac(bytes, options);
  }

  /// Parses native FLAC from the given bytes and returns the contained AudioMetadata.
  ///
  /// Options are set using the [ParseOptions] parameter, defaulting to [ParseOptions.all].
  AudioMetadata _parseNativeFlac(Uint8List bytes, ParseOptions options) {
    if (!_hasFlacSignature(bytes, 0)) {
      throw FormatException('Invalid FLAC file: missing signature');
    }

    var offset = 4; // Skip "fLaC"

    Map<String, List<String>>? vorbisComments;
    AlbumArt? albumArt;

    // Read metadata blocks
    while (offset < bytes.length) {
      if (offset + 4 > bytes.length) break;

      final header = bytes[offset];
      final isLast = (header & 0x80) != 0;
      final blockType = header & 0x7F;
      final blockSize = BinaryUtils.readUint24BE(bytes, offset + 1);

      offset += 4;

      if (offset + blockSize > bytes.length) break;

      switch (blockType) {
        case 4: // VORBIS_COMMENT
          if (options.includeMetadata) {
            final blockData = bytes.sublist(offset, offset + blockSize);
            vorbisComments = VorbisCommentParser.parse(blockData);
          }
          break;
        case 6: // PICTURE
          if (options.includeAlbumArt) {
            final blockData = bytes.sublist(offset, offset + blockSize);
            albumArt = _parsePictureBlock(blockData);
          }
          break;
      }

      offset += blockSize;

      if (isLast) break;
    }

    return _buildMetadata(vorbisComments ?? {}, albumArt);
  }

  /// Parses Ogg format FLAC from the given bytes and returns the contained AudioMetadata.
  ///
  /// Options are set using the [ParseOptions] parameter, defaulting to [ParseOptions.all].
  AudioMetadata _parseOggFlac(Uint8List bytes, ParseOptions options) {
    final pages = OggContainer.parsePages(bytes);

    if (pages.isEmpty) {
      throw FormatException('No valid Ogg pages found');
    }

    Map<String, List<String>>? vorbisComments;
    AlbumArt? albumArt;

    // Process packets from pages
    for (final page in pages) {
      if (page.data.isEmpty) continue;

      // Skip first page (FLAC header)
      if (page.sequenceNumber == 0) continue;

      // Check for metadata block
      final packetType = page.data[0];

      if ((packetType & 0x7F) == 4 && options.includeMetadata) {
        // VORBIS_COMMENT
        vorbisComments = VorbisCommentParser.parse(page.data.sublist(1));
      }
      else if ((packetType & 0x7F) == 6 && options.includeAlbumArt) {
        // PICTURE
        albumArt = _parsePictureBlock(page.data.sublist(1));
      }
    }

    return _buildMetadata(vorbisComments ?? {}, albumArt);
  }

  AlbumArt? _parsePictureBlock(Uint8List data) {
    return PictureUtils.parseFLACMetadataBlockPicture(data);
  }

  AudioMetadata _buildMetadata(
    Map<String, List<String>> rawTags, AlbumArt? albumArt
  ) {
    // Parse track number
    final trackNumStr = TagUtils.getFirstValue(rawTags, 'TRACKNUMBER');

    final (trackNumber, totalTracks1) = TagUtils.parseNumberSlashTotal(
      trackNumStr
    );

    final totalTracks =
        totalTracks1 ??
        int.tryParse(TagUtils.getFirstValue(rawTags, 'TOTALTRACKS') ?? '');

    // Parse disc number
    final discNumStr = TagUtils.getFirstValue(rawTags, 'DISCNUMBER');

    final (discNumber, totalDiscs1) = TagUtils.parseNumberSlashTotal(
      discNumStr
    );

    final totalDiscs =
        totalDiscs1 ??
        int.tryParse(TagUtils.getFirstValue(rawTags, 'TOTALDISCS') ?? '');

    return AudioMetadata(
      title: TagUtils.getFirstValue(rawTags, 'TITLE'),
      artist: TagUtils.getFirstValue(rawTags, 'ARTIST'),
      album: TagUtils.getFirstValue(rawTags, 'ALBUM'),
      albumArtist:
          TagUtils.getFirstValue(rawTags, 'ALBUMARTIST') ??
          TagUtils.getFirstValue(rawTags, 'ALBUM ARTIST'),
      date: TagUtils.getFirstValue(rawTags, 'DATE'),
      trackNumber: trackNumber,
      totalTracks: totalTracks,
      discNumber: discNumber,
      totalDiscs: totalDiscs,
      genre: TagUtils.getFirstValue(rawTags, 'GENRE'),
      comment:
          TagUtils.getFirstValue(rawTags, 'COMMENT') ??
          TagUtils.getFirstValue(rawTags, 'DESCRIPTION'),
      composer: TagUtils.getFirstValue(rawTags, 'COMPOSER'),
      publisher:
          TagUtils.getFirstValue(rawTags, 'PUBLISHER') ??
          TagUtils.getFirstValue(rawTags, 'LABEL'),
      lyrics:
          TagUtils.getFirstValue(rawTags, 'LYRICS') ??
          TagUtils.getFirstValue(rawTags, 'UNSYNCEDLYRICS'),
      albumArt: albumArt,
      rawTags: rawTags
    );
  }

  bool _hasFlacSignature(Uint8List bytes, int offset) {
    return TagUtils.matchesSignature(bytes, offset, _flacSignature);
  }
}
