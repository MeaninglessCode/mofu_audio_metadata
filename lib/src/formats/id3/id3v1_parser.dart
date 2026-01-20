import 'dart:convert';
import 'dart:typed_data';

import 'package:mofu_audio_metadata/src/utils/tag_utils.dart';

/// Parser for ID3v1 and ID3v1.1 tags.
///
/// ID3v1 is a legacy, fixed-length field format that only supports ISO-8859-1 encoding. ID3v1.1
/// adds track number support by taking the last two bytes from the comment field. Data is stored
/// in the last 128 bytes of an MP3 file.
class ID3v1Parser {
  static const _tagSignature = [0x54, 0x41, 0x47]; // "TAG"

  /// Check if the bytes contain an ID3v1 tag at the end.
  static bool hasID3v1Tag(Uint8List bytes) {
    if (bytes.length < 128) return false;

    final offset = bytes.length - 128;
    return bytes[offset] == _tagSignature[0] && bytes[offset + 1] == _tagSignature[1] && bytes[offset + 2] == _tagSignature[2];
  }

  /// Parses the ID3v1 tag from the end of the bytes.
  ///
  /// Returns a map with the following keys:
  /// - `title`
  /// - `artist`
  /// - `album`
  /// - `date`
  /// - `comment`
  /// - `trackNumber` (v1.1 only)
  /// - `genre`
  static Map<String, String?> parse(Uint8List bytes) {
    if (!hasID3v1Tag(bytes)) return {};

    final offset = bytes.length - 128;
    final tag = bytes.sublist(offset, bytes.length);

    String readString(int start, int length) {
      final data = tag.sublist(start, start + length);

      // Find null terminator
      var end = 0;
      while (end < data.length && data[end] != 0) {
        end++;
      }

      final trimmed = data.sublist(0, end);
      return latin1.decode(trimmed).trim();
    }

    final title = readString(3, 30);
    final artist = readString(33, 30);
    final album = readString(63, 30);
    final year = readString(93, 4);
    final comment = readString(97, 28);

    // If ID3v1.1, check for track number in the comment field.
    int? trackNumber;
    if (tag[125] == 0 && tag[126] != 0) {
      trackNumber = tag[126];
    }

    final genre = tag[127];

    return {
      'title': title.isNotEmpty ? title : null,
      'artist': artist.isNotEmpty ? artist : null,
      'album': album.isNotEmpty ? album : null,
      'date': year.isNotEmpty ? year : null,
      'comment': comment.isNotEmpty ? comment : null,
      'trackNumber': trackNumber?.toString(),
      'genre': GenreRegistry.getGenreName(genre)
    };
  }
}
