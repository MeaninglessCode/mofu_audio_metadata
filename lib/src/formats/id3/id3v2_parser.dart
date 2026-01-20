import 'dart:convert';
import 'dart:typed_data';

import 'package:mofu_audio_metadata/src/models/audio_metadata.dart';
import 'package:mofu_audio_metadata/src/models/parse_options.dart';
import 'package:mofu_audio_metadata/src/utils/binary_utils.dart';

/// Parser for ID3v2 tags versions 2.2, 2.3, and 2.4.
/// 
/// ID3v2 is a commonly used format for MP3 files as well as being used in ADTS AAC and WAV files.
/// The format supports ISO-8859-1, UTF-8, and UTF-16 text encodings. Embedded pictures are declared
/// in the APIC/PIC frame. Comments with language codes are stored in the COMM/COM frames. Lyrics
/// are stored in the USLT/ULT frames. Lyrics are unsynchronized.
class ID3v2Parser {
  static const _id3Signature = [0x49, 0x44, 0x33]; // "ID3"

  /// Check if the bytes start with an ID3v2 tag.
  static bool hasID3v2Tag(Uint8List bytes) {
    if (bytes.length < 10) return false;

    return bytes[0] == _id3Signature[0] && bytes[1] == _id3Signature[1] && bytes[2] == _id3Signature[2];
  }

  /// Get the total size of the ID3v2 tag including header.
  static int getTagSize(Uint8List bytes) {
    if (!hasID3v2Tag(bytes)) return 0;

    return 10 + BinaryUtils.parseSynchsafeInt32(bytes, 6);
  }

  /// Returns a map containing the following keys:
  /// - `frames`: Map<String, List<String>> of text frame values
  /// - `pictures`: List<AlbumArt> of embedded pictures
  /// - `version`: integer major version number
  /// - `revision`: integer minor revision number
  /// 
  /// Options are set using the [ParseOptions] parameter, defaulting to [ParseOptions.all].
  static Map<String, dynamic> parse(
    Uint8List bytes,
    [ParseOptions options = ParseOptions.all]
  ) {
    if (!hasID3v2Tag(bytes)) {
      return {};
    }

    final version = bytes[3];
    final revision = bytes[4];
    final flags = bytes[5];

    // Parse tag size (synchsafe integer)
    final tagSize = BinaryUtils.parseSynchsafeInt32(bytes, 6);

    if (tagSize <= 0 || tagSize + 10 > bytes.length) {
      return {};
    }

    final hasExtendedHeader = (flags & 0x40) != 0;

    var offset = 10; // Skip header

    // Skip extended header if present
    if (hasExtendedHeader && version >= 3) {
      if (offset + 4 > bytes.length) return {};

      final extHeaderSize = version == 4
          ? BinaryUtils.parseSynchsafeInt32(bytes, offset)
          : BinaryUtils.readUint32BE(bytes, offset);

      // Validate extended header size to prevent overflow
      if (extHeaderSize < 0 || offset + extHeaderSize > bytes.length) {
        return {};
      }

      offset += extHeaderSize;
    }

    final frames = <String, List<String>>{};
    final pictures = <AlbumArt>[];

    // Parse frames
    final tagEnd = 10 + tagSize;

    while (offset < tagEnd - 10) {
      // Check for padding (all zeros)
      if (bytes[offset] == 0) break;

      final frameResult = _parseFrame(
        bytes, offset, version, options
      );

      if (frameResult == null) break;

      final frameId = frameResult['id'] as String;
      final frameSize = frameResult['size'] as int;
      final frameData = frameResult['data'];

      if (frameData is String && frameData.isNotEmpty) {
        frames.putIfAbsent(frameId, () => []).add(frameData);
      }
      else if (frameData is AlbumArt) {
        pictures.add(frameData);
      }

      offset += frameSize + (version >= 3 ? 10 : 6);
    }

    return {
      'frames': frames,
      'pictures': pictures,
      'version': version,
      'revision': revision
    };
  }

  /// Parses the frame at the given offset from the given bytes and returns  a map containing the
  /// data at that location.
  /// 
  /// Options are set using the [ParseOptions] parameter, defaulting to [ParseOptions.all].
  static Map<String, dynamic>? _parseFrame(
    Uint8List bytes, int offset, int version, ParseOptions options
  ) {
    if (offset + (version >= 3 ? 10 : 6) > bytes.length) return null;

    // Frame ID (4 bytes for v2.3+, 3 bytes for v2.2)
    final frameIdLength = version >= 3 ? 4 : 3;

    final frameId = String.fromCharCodes(
      bytes.sublist(offset, offset + frameIdLength)
    );

    // Check if valid frame ID
    if (!_isValidFrameId(frameId)) return null;

    offset += frameIdLength;

    int frameSize;

    if (version >= 3) {
      frameSize = version == 4
          ? BinaryUtils.parseSynchsafeInt32(bytes, offset)
          : BinaryUtils.readUint32BE(bytes, offset);

      offset += 4;
    }
    else {
      frameSize = BinaryUtils.readUint24BE(bytes, offset);
      offset += 3;
    }

    if (frameSize <= 0 || offset + frameSize > bytes.length) return null;

    // Frame flags (only in v2.3+)
    if (version >= 3) {
      offset += 2; // Skip flags
    }

    // Parse frame content based on given options. Frame info is still needed for offset
    // calculation.
    final isPicture = _isPictureFrame(frameId);
    final isText = _isTextFrame(frameId) || _isCommentFrame(frameId) || _isLyricsFrame(frameId);

    // Skip album art frames if not requested
    if (isPicture && !options.includeAlbumArt) {
      return {'id': frameId, 'size': frameSize, 'data': null};
    }

    // Skip text frames if not requested
    if (isText && !options.includeMetadata) {
      return {'id': frameId, 'size': frameSize, 'data': null};
    }

    final frameData = bytes.sublist(offset, offset + frameSize);

    // Parse frame content
    dynamic content;
    if (_isTextFrame(frameId)) {
      content = _parseTextFrame(frameData);
    }
    else if (isPicture) {
      content = _parsePictureFrame(frameData, version);
    }
    else if (_isCommentFrame(frameId) || _isLyricsFrame(frameId)) {
      // COMM and USLT frames have the same structure
      content = _parseCommentFrame(frameData);
    }

    return {'id': frameId, 'size': frameSize, 'data': content};
  }

  static bool _isValidFrameId(String id) {
    if (id.isEmpty) return false;

    for (var i = 0; i < id.length; i++) {
      final code = id.codeUnitAt(i);
      // 0-9 || A-Z
      if (!((code >= 0x30 && code <= 0x39) || (code >= 0x41 && code <= 0x5A))) {
        return false;
      }
    }

    return true;
  }

  static bool _isTextFrame(String id) {
    // COMM/COM are not text frames and must be handled separately.
    return id.startsWith('T') || id.startsWith('W');
  }

  static bool _isPictureFrame(String id) {
    return id == 'APIC' || id == 'PIC';
  }

  static bool _isCommentFrame(String id) {
    return id == 'COMM' || id == 'COM';
  }

  static bool _isLyricsFrame(String id) {
    return id == 'USLT' || id == 'ULT';
  }

  static String? _parseTextFrame(Uint8List data) {
    if (data.isEmpty) return null;

    final encoding = data[0];
    final textData = data.sublist(1);

    return _decodeText(textData, encoding);
  }

  static String? _parseCommentFrame(Uint8List data) {
    if (data.length < 4) return null;

    final encoding = data[0];
    // Skip language (3 bytes)
    var offset = 4;

    // Skip null-terminated short description
    // For UTF-16 (encoding 1), there may be a BOM before the description
    if (encoding == 1) {
      // Check for BOM in short description
      if (offset + 2 <= data.length &&
          ((data[offset] == 0xFF && data[offset + 1] == 0xFE) ||
           (data[offset] == 0xFE && data[offset + 1] == 0xFF))) {
        offset += 2; // Skip BOM
      }

      // UTF-16: look for double-null terminator (aligned)
      while (offset + 1 < data.length) {
        if (data[offset] == 0 && data[offset + 1] == 0) {
          offset += 2; // Skip double-null terminator
          break;
        }
        offset += 2;
      }
    }
    else if (encoding == 2) {
      // UTF-16BE without BOM: look for double-null terminator
      while (offset + 1 < data.length) {
        if (data[offset] == 0 && data[offset + 1] == 0) {
          offset += 2;
          break;
        }
        offset += 2;
      }
    }
    else {
      // ISO-8859-1 or UTF-8: single null terminator
      while (offset < data.length && data[offset] != 0) {
        offset++;
      }
      offset++; // Skip null terminator
    }

    if (offset >= data.length) return null;

    final textData = data.sublist(offset);
    return _decodeText(textData, encoding);
  }

  static AlbumArt? _parsePictureFrame(Uint8List data, int version) {
    try {
      if (data.isEmpty) return null;

      final encoding = data[0];
      var offset = 1;

      String mimeType;
      if (version >= 3) {
        // APIC: null-terminated MIME type
        final mimeStart = offset;

        while (offset < data.length && data[offset] != 0) {
          offset++;
        }

        mimeType = String.fromCharCodes(data.sublist(mimeStart, offset));
        offset++; // Skip null terminator
      }
      else {
        // PIC: 3-character format (like "JPG" or "PNG")
        if (offset + 3 > data.length) return null;

        final format = String.fromCharCodes(data.sublist(offset, offset + 3));
        mimeType = format == 'PNG' ? 'image/png' : 'image/jpeg';
        offset += 3;
      }

      // Picture type
      if (offset >= data.length) return null;
      offset++; // Skip picture type byte

      // Description (null-terminated)
      final descStart = offset;
      while (offset < data.length && data[offset] != 0) {
        offset++;
      }

      final description = _decodeText(data.sublist(descStart, offset), encoding);
      offset++; // Skip null terminator

      if (offset >= data.length) return null;

      // Picture data
      final pictureData = data.sublist(offset);

      return AlbumArt(
        mimeType: mimeType,
        data: pictureData,
        description: description?.isNotEmpty == true ? description : null
      );
    }
    catch (e) {
      return null;
    }
  }

  static String? _decodeText(Uint8List data, int encoding) {
    if (data.isEmpty) return null;

    try {
      String result;
      switch (encoding) {
        case 0: // ISO-8859-1
          result = latin1.decode(data);
          break;
        case 1: // UTF-16 with BOM
          result = _decodeUTF16(data);
          break;
        case 2: // UTF-16BE (no BOM)
          result = _decodeUTF16BE(data);
          break;
        case 3: // UTF-8
          result = utf8.decode(data);
          break;
        default:
          result = latin1.decode(data);
      }

      // Strip trailing null characters
      var endIndex = result.length;

      while (endIndex > 0 && result.codeUnitAt(endIndex - 1) == 0) {
        endIndex--;
      }

      return endIndex < result.length ? result.substring(0, endIndex) : result;
    }
    catch (e) {
      return null;
    }
  }

  static String _decodeUTF16(Uint8List data) {
    // Check for BOM and decode accordingly
    if (data.length >= 2) {
      if (data[0] == 0xFF && data[1] == 0xFE) {
        // UTF-16LE
        return _decodeUTF16LE(data.sublist(2));
      }
      else if (data[0] == 0xFE && data[1] == 0xFF) {
        // UTF-16BE
        return _decodeUTF16BE(data.sublist(2));
      }
    }

    // Default to UTF-16LE if no BOM
    return _decodeUTF16LE(data);
  }

  static String _decodeUTF16LE(Uint8List data) {
    final units = <int>[];

    for (var i = 0; i < data.length - 1; i += 2) {
      units.add(data[i] | (data[i + 1] << 8));
    }

    return String.fromCharCodes(units);
  }

  static String _decodeUTF16BE(Uint8List data) {
    final units = <int>[];

    for (var i = 0; i < data.length - 1; i += 2) {
      units.add((data[i] << 8) | data[i + 1]);
    }

    return String.fromCharCodes(units);
  }
}
