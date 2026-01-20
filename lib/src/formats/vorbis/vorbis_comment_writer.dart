import 'dart:convert';
import 'dart:typed_data';

import 'package:mofu_audio_metadata/src/models/audio_metadata.dart';
import 'package:mofu_audio_metadata/src/utils/binary_utils.dart';

/// Writer for Vorbis Comments.
///
/// Vorbis Comments are used by FLAC, OPUS, and Ogg Vorbis files.
/// This writer creates the comment block data without format-specific headers.
class VorbisCommentWriter {
  static const String _defaultVendor = 'mofu_audio_metadata';

  /// Build a Vorbis Comment block from the given metadata.
  ///
  /// Returns a Uint8List containing the Vorbis Comment data.
  /// Does not include format-specific headers (e.g., FLAC metadata block header).
  static Uint8List build(AudioMetadata metadata, {String? vendor}) {
    final comments = <String>[];

    // Standard tags
    _addComment(comments, 'TITLE', metadata.title);
    _addComment(comments, 'ARTIST', metadata.artist);
    _addComment(comments, 'ALBUM', metadata.album);
    _addComment(comments, 'ALBUMARTIST', metadata.albumArtist);
    _addComment(comments, 'DATE', metadata.date);
    _addComment(comments, 'GENRE', metadata.genre);
    _addComment(comments, 'COMMENT', metadata.comment);
    _addComment(comments, 'COMPOSER', metadata.composer);
    _addComment(comments, 'PUBLISHER', metadata.publisher);
    _addComment(comments, 'LYRICS', metadata.lyrics);

    // Track number
    if (metadata.trackNumber != null) {
      _addComment(comments, 'TRACKNUMBER', metadata.trackNumber.toString());
    }
    if (metadata.totalTracks != null) {
      _addComment(comments, 'TOTALTRACKS', metadata.totalTracks.toString());
    }

    // Disc number
    if (metadata.discNumber != null) {
      _addComment(comments, 'DISCNUMBER', metadata.discNumber.toString());
    }
    if (metadata.totalDiscs != null) {
      _addComment(comments, 'TOTALDISCS', metadata.totalDiscs.toString());
    }

    // Album art (as METADATA_BLOCK_PICTURE, base64 encoded)
    if (metadata.albumArt != null) {
      final pictureData = _buildMetadataBlockPicture(metadata.albumArt!);
      final base64Picture = base64.encode(pictureData);
      _addComment(comments, 'METADATA_BLOCK_PICTURE', base64Picture);
    }

    return _buildCommentBlock(vendor ?? _defaultVendor, comments);
  }

  /// Build raw Vorbis Comment block from vendor string and comment list.
  static Uint8List _buildCommentBlock(String vendor, List<String> comments) {
    final builder = BytesBuilder();

    // Vendor string (length + string, little-endian)
    final vendorBytes = utf8.encode(vendor);
    builder.add(BinaryUtils.encodeUint32LE(vendorBytes.length));
    builder.add(vendorBytes);

    // Comment count
    builder.add(BinaryUtils.encodeUint32LE(comments.length));

    // Each comment (length + string)
    for (final comment in comments) {
      final commentBytes = utf8.encode(comment);
      builder.add(BinaryUtils.encodeUint32LE(commentBytes.length));
      builder.add(commentBytes);
    }

    return builder.toBytes();
  }

  /// Build a FLAC METADATA_BLOCK_PICTURE structure.
  static Uint8List _buildMetadataBlockPicture(AlbumArt albumArt) {
    final builder = BytesBuilder();

    // Picture type (4 bytes, big-endian): 3 = Cover (front)
    builder.add(BinaryUtils.encodeUint32BE(3));

    // MIME type length and string
    final mimeBytes = utf8.encode(albumArt.mimeType);
    builder.add(BinaryUtils.encodeUint32BE(mimeBytes.length));
    builder.add(mimeBytes);

    // Description length and string
    final descBytes = albumArt.description != null
        ? utf8.encode(albumArt.description!)
        : <int>[];
    builder.add(BinaryUtils.encodeUint32BE(descBytes.length));
    builder.add(descBytes);

    // Width, height, color depth, colors used (all 0 for unknown)
    builder.add(BinaryUtils.encodeUint32BE(0)); // width
    builder.add(BinaryUtils.encodeUint32BE(0)); // height
    builder.add(BinaryUtils.encodeUint32BE(0)); // color depth
    builder.add(BinaryUtils.encodeUint32BE(0)); // colors used

    // Picture data length and data
    builder.add(BinaryUtils.encodeUint32BE(albumArt.data.length));
    builder.add(albumArt.data);

    return builder.toBytes();
  }

  static void _addComment(List<String> comments, String key, String? value) {
    if (value == null || value.isEmpty) return;
    comments.add('$key=$value');
  }
}
