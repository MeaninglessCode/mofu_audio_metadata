import 'dart:convert';
import 'dart:typed_data';

import 'package:mofu_audio_metadata/src/models/audio_metadata.dart';
import 'package:mofu_audio_metadata/src/models/parse_options.dart';
import 'package:mofu_audio_metadata/src/utils/binary_utils.dart';
import 'package:mofu_audio_metadata/src/utils/tag_utils.dart';

/// Represents an MP4/M4A atom.
class Mp4Atom {
  final String type;
  final int size;
  final Uint8List data;

  Mp4Atom({required this.type, required this.size, required this.data});
}

/// Parser for MP4/M4A atoms and iTunes metadata.
/// 
/// MP4 files consist of hierarchical atoms containing metadata. This parser handles the low-level
/// atom parsing and iTunes-style metadata extraction from the ILST (item list) atom.
class Mp4AtomParser {
  /// Parses a single atom at the given offset and returns null if there's insufficient data for a
  /// valid atom.
  static Mp4Atom? parseAtom(Uint8List data, int offset) {
    if (offset + 8 > data.length) return null;

    var size = BinaryUtils.readUint32BE(data, offset);
    final type = String.fromCharCodes(data.sublist(offset + 4, offset + 8));

    var headerSize = 8;

    // Handle extended size (size == 1)
    if (size == 1) {
      if (offset + 16 > data.length) return null;

      // Extended size is 64-bit, but only the lower 32 bits are needed
      size = BinaryUtils.readUint32BE(data, offset + 12);
      headerSize = 16;
    }

    // Handle size to end of file (size == 0)
    if (size == 0) {
      size = data.length - offset;
    }

    if (offset + size > data.length) {
      size = data.length - offset;
    }

    final atomData = data.sublist(offset + headerSize, offset + size);

    return Mp4Atom(type: type, size: size, data: atomData);
  }

  /// Find an atom of the given type within the data, starting at startOffset.
  static Mp4Atom? findAtom(Uint8List data, String type, int startOffset) {
    var offset = startOffset;

    while (offset + 8 <= data.length) {
      final atom = parseAtom(data, offset);
      if (atom == null) break;

      if (atom.type == type) {
        return atom;
      }

      offset += atom.size;
    }

    return null;
  }

  /// Parses iTunes metadata from an ILST atom and returns a map of atom types to their parsed
  /// values.
  /// 
  /// Options are set using the [ParseOptions] parameter, defaulting to [ParseOptions.all].
  static Map<String, dynamic> parseIlst(
    Uint8List data,
    ParseOptions options
  ) {
    final metadata = <String, dynamic>{};
    var offset = 0;

    while (offset + 8 <= data.length) {
      final atom = parseAtom(data, offset);
      if (atom == null) break;

      // Skip based on options
      final isCover = atom.type == 'covr';
      if (isCover && !options.includeAlbumArt) {
        offset += atom.size;
        continue;
      }
      if (!isCover && !options.includeMetadata) {
        offset += atom.size;
        continue;
      }

      // Find 'data' atom within this metadata atom
      final dataAtom = findAtom(atom.data, 'data', 0);

      if (dataAtom != null && dataAtom.data.length >= 8) {
        // Atom format: 4 bytes type indicator + 4 bytes locale
        final typeIndicator = BinaryUtils.readUint32BE(dataAtom.data, 0);
        final valueData = dataAtom.data.sublist(8);

        final value = parseDataValue(valueData, typeIndicator, atom.type);
        metadata[atom.type] = value;
      }

      offset += atom.size;
    }

    return metadata;
  }

  /// Parse the value from an atom based on the type indicator.
  static dynamic parseDataValue(Uint8List data, int typeIndicator, String atomType) {
    try {
      switch (typeIndicator) {
        case 0: // Reserved/implicit - depends on atom type
          // gnre atom uses type 0 with 16-bit genre ID
          if (atomType == 'gnre' && data.length >= 2) {
            return BinaryUtils.readUint16BE(data, 0);
          }
          // Otherwise treat as UTF-8 string
          return utf8.decode(data);
        case 1: // UTF-8 string
          return utf8.decode(data);
        case 2: // UTF-16 string
        case 3: // S/JIS string
          return utf8.decode(data); // Fallback to UTF-8
        case 13: // JPEG image
          return {'albumArt': AlbumArt(mimeType: 'image/jpeg', data: data)};
        case 14: // PNG image
          return {'albumArt': AlbumArt(mimeType: 'image/png', data: data)};
        case 21: // Signed integer (1 byte)
          return data.isNotEmpty ? data[0] : null;
        case 22: // Unsigned integer (variable)
          if (data.isEmpty) return null;
          if (data.length == 1) return data[0];
          if (data.length == 2) return BinaryUtils.readUint16BE(data, 0);
          if (data.length >= 4) return BinaryUtils.readUint32BE(data, 0);
          return null;
        default:
          return utf8.decode(data, allowMalformed: true);
      }
    }
    catch (e) {
      return null;
    }
  }

  /// Extracts metadata atoms from the given M4A/MP4 file bytes.
  ///
  /// Navigates the atom hierarchy: MOOV -> UDTA -> META -> ILIST.
  /// Returns the parsed metadata map from ILIST.
  /// 
  /// Options are set using the [ParseOptions] parameter, defaulting to [ParseOptions.all].
  static Map<String, dynamic> extractMetadata(
    Uint8List bytes,
    [ParseOptions options = ParseOptions.all]
  ) {
    // Find MOOV atom (movie metadata container)
    final moovAtom = findAtom(bytes, 'moov', 0);
    if (moovAtom == null) return {};

    // Find UDTA (user data) atom within MOOV
    final udtaAtom = findAtom(moovAtom.data, 'udta', 0);
    if (udtaAtom == null) return {};

    // Find META atom within udta
    final metaAtom = findAtom(udtaAtom.data, 'meta', 0);
    if (metaAtom == null) return {};

    // META atom has 4-byte version/flags header
    final metaData = metaAtom.data.length > 4
        ? metaAtom.data.sublist(4)
        : metaAtom.data;

    // Find ILST (item list) atom within the META atom
    final ilstAtom = findAtom(metaData, 'ilst', 0);
    if (ilstAtom == null) return {};

    return parseIlst(ilstAtom.data, options);
  }

  /// Parse genre from metadata atoms.
  ///
  /// Checks GNRE (numeric genre) first, then falls back to ©gen (text genre).
  static String? parseGenre(Map<String, dynamic> atoms) {
    final gnreData = atoms['gnre'];

    if (gnreData is int) {
      // ID3v1 genre code (1-indexed in MP4)
      return GenreRegistry.getGenreName(gnreData - 1);
    }

    final genValue = atoms['\u00a9gen'];
    return genValue is String ? genValue : null;
  }

  /// Parse track number and total tracks from the TRKN atom.
  static ({int? trackNumber, int? totalTracks}) parseTrackNumber(Map<String, dynamic> atoms) {
    final trknData = atoms['trkn'];

    if (trknData is String && trknData.length >= 6) {
      final bytes = trknData.codeUnits;

      if (bytes.length >= 6) {
        var trackNumber = (bytes[2] << 8) | bytes[3];
        var totalTracks = (bytes[4] << 8) | bytes[5];

        return (
          trackNumber: trackNumber == 0 ? null : trackNumber,
          totalTracks: totalTracks == 0 ? null : totalTracks
        );
      }
    }

    return (trackNumber: null, totalTracks: null);
  }

  /// Parse disc number and total discs from disk atom.
  static ({int? discNumber, int? totalDiscs}) parseDiscNumber(Map<String, dynamic> atoms) {
    final diskData = atoms['disk'];

    if (diskData is String && diskData.length >= 6) {
      final bytes = diskData.codeUnits;

      if (bytes.length >= 6) {
        var discNumber = (bytes[2] << 8) | bytes[3];
        var totalDiscs = (bytes[4] << 8) | bytes[5];

        return (
          discNumber: discNumber == 0 ? null : discNumber,
          totalDiscs: totalDiscs == 0 ? null : totalDiscs
        );
      }
    }

    return (discNumber: null, totalDiscs: null);
  }

  /// Extract album art from metadata atoms.
  static AlbumArt? extractAlbumArt(Map<String, dynamic> atoms) {
    final coverData = atoms['covr'];

    if (coverData != null && coverData is Map<String, dynamic>) {
      return coverData['albumArt'] as AlbumArt?;
    }

    return null;
  }
}
