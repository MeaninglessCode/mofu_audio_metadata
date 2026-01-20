import 'dart:convert';
import 'dart:typed_data';

import 'package:mofu_audio_metadata/src/utils/binary_utils.dart';

/// Vorbis Comment metadata format parser.
///
/// Vorbis Comments are used by Ogg-based formats (Vorbis, OPUS, FLAC in Ogg)
/// and native FLAC files. The format consists of:
/// - Vendor string (length-prefixed UTF-8)
/// - Comment count (32-bit LE)
/// - Comments as "KEY=value" pairs (length-prefixed UTF-8, case-insensitive keys)
class VorbisCommentParser {
  /// Parse Vorbis Comments from binary data.
  ///
  /// Returns a map of uppercase keys to lists of values (multiple values per key allowed).
  static Map<String, List<String>> parse(Uint8List data) {
    final comments = <String, List<String>>{};
    var offset = 0;

    try {
      // Read vendor string length (4 bytes, little-endian)
      if (offset + 4 > data.length) return comments;
      final vendorLength = BinaryUtils.readUint32LE(data, offset);
      offset += 4;

      // Validate vendor length to prevent overflow
      if (vendorLength > data.length - offset) return comments;

      // Skip vendor string
      offset += vendorLength;

      // Read number of comments (4 bytes, little-endian)
      if (offset + 4 > data.length) return comments;
      final commentCount = BinaryUtils.readUint32LE(data, offset);
      offset += 4;

      // Read each comment
      for (var i = 0; i < commentCount; i++) {
        if (offset + 4 > data.length) break;

        final commentLength = BinaryUtils.readUint32LE(data, offset);
        offset += 4;

        // Validate comment length
        if (commentLength > data.length - offset) break;

        final commentBytes = data.sublist(offset, offset + commentLength);
        offset += commentLength;

        try {
          final comment = utf8.decode(commentBytes);
          final equalsIndex = comment.indexOf('=');
          if (equalsIndex > 0) {
            final key = comment.substring(0, equalsIndex).toUpperCase();
            final value = comment.substring(equalsIndex + 1);
            comments.putIfAbsent(key, () => []).add(value);
          }
        }
        catch (e) {
          // Skip invalid UTF-8
          continue;
        }
      }
    }
    catch (e) {
      // Return what we have so far
      return comments;
    }

    return comments;
  }

  /// Get the vendor string from Vorbis Comments data.
  static String? parseVendor(Uint8List data) {
    if (data.length < 4) return null;

    try {
      final vendorLength = BinaryUtils.readUint32LE(data, 0);
      if (4 + vendorLength > data.length) return null;

      return utf8.decode(data.sublist(4, 4 + vendorLength));
    }
    catch (e) {
      return null;
    }
  }
}
