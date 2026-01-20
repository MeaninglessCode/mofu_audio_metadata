import 'dart:typed_data';

import 'package:mofu_audio_metadata/src/models/audio_metadata.dart';
import 'package:mofu_audio_metadata/src/models/parse_options.dart';
import 'package:mofu_audio_metadata/src/parsers/metadata_parser.dart';
import 'package:mofu_audio_metadata/src/containers/ogg_container.dart';
import 'package:mofu_audio_metadata/src/formats/vorbis/vorbis_comment_parser.dart';
import 'package:mofu_audio_metadata/src/utils/picture_utils.dart';
import 'package:mofu_audio_metadata/src/utils/tag_utils.dart';

/// Parser for OPUS audio files
class OpusParser implements MetadataParser {
  static const _opusHeadSignature = 'OpusHead';
  static const _opusTagsSignature = 'OpusTags';

  /// Returns true if the given bytes are a valid OGG/OPUS format, false otherwise.
  @override
  bool canParse(Uint8List bytes) {
    if (!OggContainer.isOggFile(bytes)) return false;

    // Check for OpusHead in first page
    final pages = OggContainer.parsePages(bytes);
    if (pages.isEmpty) return false;

    final firstPage = pages.first;
    if (firstPage.data.length < 8) return false;

    final signature = String.fromCharCodes(firstPage.data.sublist(0, 8));
    return signature == _opusHeadSignature;
  }

  /// Parse byte array and return AudioMetadata if the format is supported.
  /// 
  /// Options are set using the [ParseOptions] parameter, defaulting to [ParseOptions.all].
  @override
  AudioMetadata parse(Uint8List bytes, [ParseOptions options = ParseOptions.all]) {
    final pages = OggContainer.parsePages(bytes);

    if (pages.isEmpty) {
      throw FormatException('No Ogg pages found');
    }

    // First page should contain OpusHead
    final firstPage = pages.first;
    if (firstPage.data.length < 8) {
      throw FormatException('Invalid OPUS file: first page too short');
    }

    final headSignature = String.fromCharCodes(firstPage.data.sublist(0, 8));
    if (headSignature != _opusHeadSignature) {
      throw FormatException('Invalid OPUS file: missing OpusHead');
    }

    // Second page should contain OpusTags (Vorbis Comments)
    if (pages.length < 2) {
      return const AudioMetadata();
    }

    final secondPage = pages[1];
    if (secondPage.data.length < 8) {
      return const AudioMetadata();
    }

    final tagsSignature = String.fromCharCodes(secondPage.data.sublist(0, 8));
    if (tagsSignature != _opusTagsSignature) {
      return const AudioMetadata();
    }

    // Parse Vorbis Comments (skip 8-byte OpusTags signature)
    final commentData = Uint8List.sublistView(secondPage.data, 8);
    final rawTags = VorbisCommentParser.parse(commentData);

    return _buildMetadata(rawTags, options);
  }


  /// Builds an AudioMetadata object from the given raw tag mappings.
  ///
  /// Options are set using the [ParseOptions] parameter, defaulting to [ParseOptions.all].
  AudioMetadata _buildMetadata(Map<String, List<String>> rawTags, ParseOptions options) {
    // Parse track number (only if metadata requested)
    int? trackNumber;
    int? totalTracks;
    int? discNumber;
    int? totalDiscs;

    if (options.includeMetadata) {
      final trackNumStr = TagUtils.getFirstValue(rawTags, 'TRACKNUMBER');
      final (tn, tt1) = TagUtils.parseNumberSlashTotal(trackNumStr);
      trackNumber = tn;
      totalTracks = tt1 ?? int.tryParse(TagUtils.getFirstValue(rawTags, 'TOTALTRACKS') ?? '');

      final discNumStr = TagUtils.getFirstValue(rawTags, 'DISCNUMBER');
      final (dn, td1) = TagUtils.parseNumberSlashTotal(discNumStr);
      discNumber = dn;
      totalDiscs = td1 ?? int.tryParse(TagUtils.getFirstValue(rawTags, 'TOTALDISCS') ?? '');
    }

    // Parse album art (METADATA_BLOCK_PICTURE) - only if album art requested
    AlbumArt? albumArt;
    if (options.includeAlbumArt) {
      final pictureData = TagUtils.getFirstValue(rawTags, 'METADATA_BLOCK_PICTURE');
      if (pictureData != null) {
        albumArt = PictureUtils.parseFLACMetadataBlockPictureBase64(pictureData);
      }
    }

    return AudioMetadata(
      title: options.includeMetadata ? TagUtils.getFirstValue(rawTags, 'TITLE') : null,
      artist: options.includeMetadata ? TagUtils.getFirstValue(rawTags, 'ARTIST') : null,
      album: options.includeMetadata ? TagUtils.getFirstValue(rawTags, 'ALBUM') : null,
      albumArtist: options.includeMetadata
          ? (TagUtils.getFirstValue(rawTags, 'ALBUMARTIST') ??
             TagUtils.getFirstValue(rawTags, 'ALBUM ARTIST'))
          : null,
      date: options.includeMetadata ? TagUtils.getFirstValue(rawTags, 'DATE') : null,
      trackNumber: trackNumber,
      totalTracks: totalTracks,
      discNumber: discNumber,
      totalDiscs: totalDiscs,
      genre: options.includeMetadata ? TagUtils.getFirstValue(rawTags, 'GENRE') : null,
      comment: options.includeMetadata
          ? (TagUtils.getFirstValue(rawTags, 'COMMENT') ??
             TagUtils.getFirstValue(rawTags, 'DESCRIPTION'))
          : null,
      composer: options.includeMetadata ? TagUtils.getFirstValue(rawTags, 'COMPOSER') : null,
      publisher: options.includeMetadata
          ? (TagUtils.getFirstValue(rawTags, 'PUBLISHER') ??
             TagUtils.getFirstValue(rawTags, 'LABEL'))
          : null,
      lyrics: options.includeMetadata
          ? (TagUtils.getFirstValue(rawTags, 'LYRICS') ??
             TagUtils.getFirstValue(rawTags, 'UNSYNCEDLYRICS'))
          : null,
      albumArt: albumArt,
      rawTags: options.includeMetadata ? rawTags : {}
    );
  }
}
