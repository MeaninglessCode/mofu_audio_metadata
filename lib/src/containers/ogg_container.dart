import 'dart:typed_data';

import 'package:mofu_audio_metadata/src/utils/binary_utils.dart';
import 'package:mofu_audio_metadata/src/utils/tag_utils.dart';

/// Represents an Ogg page within an Ogg bitstream.
class OggPage {
  final int version;
  final int headerType;
  final int granulePosition;
  final int serialNumber;
  final int sequenceNumber;
  final int checksum;
  final List<int> segments;
  final Uint8List data;

  OggPage({
    required this.version,
    required this.headerType,
    required this.granulePosition,
    required this.serialNumber,
    required this.sequenceNumber,
    required this.checksum,
    required this.segments,
    required this.data
  });

  /// Returns true if this page is a continuation of the previous page.
  bool get isContinued => (headerType & 0x01) != 0;

  /// Returns true if this is the first page of the logical bitstream.
  bool get isFirstPage => (headerType & 0x02) != 0;

  /// Returns true if this is the last page of the logical bitstream.
  bool get isLastPage => (headerType & 0x04) != 0;
}

/// Low-level Ogg container parser.
///
/// Ogg is a container format used by Vorbis, OPUS, FLAC, and other codecs. This parser extracts
/// pages from an Ogg bistream without interpreting the codec-specific payload data.
class OggContainer {
  static const _oggSignature = [0x4F, 0x67, 0x67, 0x53]; // "OggS"

  /// Parse all Ogg pages from the given bytes.
  static List<OggPage> parsePages(Uint8List bytes) {
    final pages = <OggPage>[];
    var offset = 0;

    while (offset < bytes.length - 27) {
      // Check for OggS signature
      if (!_hasOggSignature(bytes, offset)) {
        offset++;
        continue;
      }

      try {
        final page = _parsePage(bytes, offset);
        pages.add(page);
        offset += _getPageSize(bytes, offset);
      }
      catch (e) {
        // Skip malformed pages
        offset++;
      }
    }

    return pages;
  }

  static bool _hasOggSignature(Uint8List bytes, int offset) {
    return TagUtils.matchesSignature(bytes, offset, _oggSignature);
  }

  static OggPage _parsePage(Uint8List bytes, int offset) {
    if (offset + 27 > bytes.length) {
      throw FormatException('Incomplete Ogg page header');
    }

    final version = bytes[offset + 4];
    final headerType = bytes[offset + 5];

    // Granule position (8 bytes, little-endian)
    var granulePosition = 0;
    for (var i = 0; i < 8; i++) {
      granulePosition |= bytes[offset + 6 + i] << (i * 8);
    }

    // Serial number (4 bytes, little-endian)
    final serialNumber = BinaryUtils.readUint32LE(bytes, offset + 14);

    // Sequence number (4 bytes, little-endian)
    final sequenceNumber = BinaryUtils.readUint32LE(bytes, offset + 18);

    // Checksum (4 bytes, little-endian)
    final checksum = BinaryUtils.readUint32LE(bytes, offset + 22);

    // Number of segments
    final numSegments = bytes[offset + 26];

    if (offset + 27 + numSegments > bytes.length) {
      throw FormatException('Incomplete Ogg segment table');
    }

    // Read segment table
    final segments = <int>[];
    for (var i = 0; i < numSegments; i++) {
      segments.add(bytes[offset + 27 + i]);
    }

    // Calculate total data size
    final dataSize = segments.fold<int>(0, (sum, len) => sum + len);
    final dataOffset = offset + 27 + numSegments;

    if (dataOffset + dataSize > bytes.length) {
      throw FormatException('Incomplete Ogg page data');
    }

    final data = Uint8List.sublistView(bytes, dataOffset, dataOffset + dataSize);

    return OggPage(
      version: version,
      headerType: headerType,
      granulePosition: granulePosition,
      serialNumber: serialNumber,
      sequenceNumber: sequenceNumber,
      checksum: checksum,
      segments: segments,
      data: data
    );
  }

  static int _getPageSize(Uint8List bytes, int offset) {
    final numSegments = bytes[offset + 26];
    var dataSize = 0;
    for (var i = 0; i < numSegments; i++) {
      dataSize += bytes[offset + 27 + i];
    }
    return 27 + numSegments + dataSize;
  }

  /// Check if bytes start with Ogg signature.
  static bool isOggFile(Uint8List bytes) {
    return bytes.length >= 4 && _hasOggSignature(bytes, 0);
  }
}
