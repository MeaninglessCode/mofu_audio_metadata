import 'dart:typed_data';

/// Utility functions for reading and writing various binary data formats.
///
/// All read functions include bounds checking to prevent out-of-bounds access.
/// If the requested bytes are not available, a [RangeError] is thrown.
///
/// Write functions return Uint8List for easy concatenation with BytesBuilder.
class BinaryUtils {
  /// Reads a 32-bit big-endian unsigned integer.
  ///
  /// Throws [RangeError] if there are fewer than 4 bytes available at [offset].
  static int readUint32BE(Uint8List bytes, int offset) {
    if (offset < 0 || offset + 4 > bytes.length) {
      throw RangeError('Cannot read 4 bytes at offset $offset (buffer length: ${bytes.length})');
    }
    return (bytes[offset] << 24) | (bytes[offset + 1] << 16) | (bytes[offset + 2] << 8) | bytes[offset + 3];
  }

  /// Reads a 32-bit little-endian unsigned integer.
  ///
  /// Throws [RangeError] if there are fewer than 4 bytes available at [offset].
  static int readUint32LE(Uint8List bytes, int offset) {
    if (offset < 0 || offset + 4 > bytes.length) {
      throw RangeError('Cannot read 4 bytes at offset $offset (buffer length: ${bytes.length})');
    }
    return bytes[offset] | (bytes[offset + 1] << 8) | (bytes[offset + 2] << 16) | (bytes[offset + 3] << 24);
  }

  /// Reads a 24-bit big-endian unsigned integer.
  ///
  /// Throws [RangeError] if there are fewer than 3 bytes available at [offset].
  static int readUint24BE(Uint8List bytes, int offset) {
    if (offset < 0 || offset + 3 > bytes.length) {
      throw RangeError('Cannot read 3 bytes at offset $offset (buffer length: ${bytes.length})');
    }
    return (bytes[offset] << 16) | (bytes[offset + 1] << 8) | bytes[offset + 2];
  }

  /// Reads a 16-bit big-endian unsigned integer.
  ///
  /// Throws [RangeError] if there are fewer than 2 bytes available at [offset].
  static int readUint16BE(Uint8List bytes, int offset) {
    if (offset < 0 || offset + 2 > bytes.length) {
      throw RangeError('Cannot read 2 bytes at offset $offset (buffer length: ${bytes.length})');
    }
    return (bytes[offset] << 8) | bytes[offset + 1];
  }

  /// Parses a synchsafe 32-bit integer (used in ID3v2 tags).
  ///
  /// Each byte only uses 7 bits, the MSB is always 0.
  /// Throws [RangeError] if there are fewer than 4 bytes available at [offset].
  static int parseSynchsafeInt32(Uint8List bytes, int offset) {
    if (offset < 0 || offset + 4 > bytes.length) {
      throw RangeError('Cannot read 4 bytes at offset $offset (buffer length: ${bytes.length})');
    }
    return ((bytes[offset] & 0x7F) << 21) | ((bytes[offset + 1] & 0x7F) << 14) | ((bytes[offset + 2] & 0x7F) << 7) | (bytes[offset + 3] & 0x7F);
  }

  /// Encodes a 32-bit big-endian unsigned integer.
  ///
  /// Returns a 4-byte Uint8List.
  static Uint8List encodeUint32BE(int value) {
    return Uint8List.fromList([
      (value >> 24) & 0xFF,
      (value >> 16) & 0xFF,
      (value >> 8) & 0xFF,
      value & 0xFF
    ]);
  }

  /// Encodes a 32-bit little-endian unsigned integer.
  ///
  /// Returns a 4-byte Uint8List.
  static Uint8List encodeUint32LE(int value) {
    return Uint8List.fromList([
      value & 0xFF,
      (value >> 8) & 0xFF,
      (value >> 16) & 0xFF,
      (value >> 24) & 0xFF
    ]);
  }

  /// Encodes a 16-bit big-endian unsigned integer.
  ///
  /// Returns a 2-byte Uint8List.
  static Uint8List encodeUint16BE(int value) {
    return Uint8List.fromList([
      (value >> 8) & 0xFF,
      value & 0xFF
    ]);
  }

  /// Encodes a synchsafe 32-bit integer (used in ID3v2 tags).
  ///
  /// Each byte only uses 7 bits, the MSB is always 0.
  /// Returns a 4-byte Uint8List.
  static Uint8List encodeSynchsafeInt32(int value) {
    return Uint8List.fromList([
      (value >> 21) & 0x7F,
      (value >> 14) & 0x7F,
      (value >> 7) & 0x7F,
      value & 0x7F
    ]);
  }
}
