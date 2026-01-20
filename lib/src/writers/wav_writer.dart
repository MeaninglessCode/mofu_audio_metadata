import 'dart:typed_data';

import 'package:mofu_audio_metadata/src/models/audio_metadata.dart';
import 'package:mofu_audio_metadata/src/writers/metadata_writer.dart';
import 'package:mofu_audio_metadata/src/formats/id3/id3v2_writer.dart';
import 'package:mofu_audio_metadata/src/utils/binary_utils.dart';

/// Writer for WAV audio files.
///
/// Writes ID3v2 tags to WAV files as an 'id3 ' chunk.
/// Can also write RIFF INFO tags in a LIST chunk.
class WavWriter implements MetadataWriter {
  static const _riffSignature = [0x52, 0x49, 0x46, 0x46]; // "RIFF"
  static const _waveSignature = [0x57, 0x41, 0x56, 0x45]; // "WAVE"

  @override
  bool canWrite(Uint8List bytes) {
    if (bytes.length < 12) return false;

    // Check for RIFF signature
    if (bytes[0] != _riffSignature[0] || bytes[1] != _riffSignature[1] || bytes[2] != _riffSignature[2] || bytes[3] != _riffSignature[3]) {
      return false;
    }

    // Check for WAVE signature
    return bytes[8] == _waveSignature[0] && bytes[9] == _waveSignature[1] && bytes[10] == _waveSignature[2] && bytes[11] == _waveSignature[3];
  }

  @override
  Uint8List write(Uint8List bytes, AudioMetadata metadata) {
    if (!canWrite(bytes)) {
      throw FormatException('Invalid WAV file');
    }

    // Build ID3v2 tag
    final id3Tag = ID3v2Writer.build(metadata);

    // Parse existing chunks
    final chunks = _parseChunks(bytes);

    // Build new file
    final result = BytesBuilder();

    // RIFF header (will update size later)
    result.add(_riffSignature);
    result.add([0, 0, 0, 0]); // Placeholder for size
    result.add(_waveSignature);

    // Add chunks (excluding existing id3/ID3 and LIST INFO)
    for (final chunk in chunks) {
      if (chunk.id == 'id3 ' || chunk.id == 'ID3 ') continue;
      if (chunk.id == 'LIST' && _isInfoChunk(chunk.data)) continue;

      result.add(chunk.id.codeUnits);
      result.add(BinaryUtils.encodeUint32LE(chunk.data.length));
      result.add(chunk.data);

      // Word alignment
      if (chunk.data.length % 2 == 1) {
        result.addByte(0);
      }
    }

    // Add ID3 chunk
    result.add('id3 '.codeUnits);
    result.add(BinaryUtils.encodeUint32LE(id3Tag.length));
    result.add(id3Tag);

    // Word alignment
    if (id3Tag.length % 2 == 1) {
      result.addByte(0);
    }

    // Update RIFF size
    final resultBytes = result.toBytes();
    final riffSize = resultBytes.length - 8;
    resultBytes[4] = riffSize & 0xFF;
    resultBytes[5] = (riffSize >> 8) & 0xFF;
    resultBytes[6] = (riffSize >> 16) & 0xFF;
    resultBytes[7] = (riffSize >> 24) & 0xFF;

    return resultBytes;
  }

  @override
  Uint8List strip(Uint8List bytes) {
    if (!canWrite(bytes)) {
      throw FormatException('Invalid WAV file');
    }

    // Parse existing chunks
    final chunks = _parseChunks(bytes);

    // Build new file without metadata chunks
    final result = BytesBuilder();

    // RIFF header
    result.add(_riffSignature);
    result.add([0, 0, 0, 0]); // Placeholder for size
    result.add(_waveSignature);

    // Add chunks (excluding id3 and LIST INFO)
    for (final chunk in chunks) {
      if (chunk.id == 'id3 ' || chunk.id == 'ID3 ') continue;
      if (chunk.id == 'LIST' && _isInfoChunk(chunk.data)) continue;

      result.add(chunk.id.codeUnits);
      result.add(BinaryUtils.encodeUint32LE(chunk.data.length));
      result.add(chunk.data);

      // Word alignment
      if (chunk.data.length % 2 == 1) {
        result.addByte(0);
      }
    }

    // Update RIFF size
    final resultBytes = result.toBytes();
    final riffSize = resultBytes.length - 8;

    resultBytes[4] = riffSize & 0xFF;
    resultBytes[5] = (riffSize >> 8) & 0xFF;
    resultBytes[6] = (riffSize >> 16) & 0xFF;
    resultBytes[7] = (riffSize >> 24) & 0xFF;

    return resultBytes;
  }

  List<_Chunk> _parseChunks(Uint8List bytes) {
    final chunks = <_Chunk>[];
    var offset = 12; // Skip RIFF header and WAVE signature

    while (offset + 8 <= bytes.length) {
      final chunkId = String.fromCharCodes(bytes.sublist(offset, offset + 4));
      final chunkSize = BinaryUtils.readUint32LE(bytes, offset + 4);

      offset += 8;

      if (offset + chunkSize > bytes.length) break;

      final chunkData = bytes.sublist(offset, offset + chunkSize);
      chunks.add(_Chunk(id: chunkId, data: chunkData));

      offset += chunkSize;

      // Word alignment
      if (chunkSize % 2 == 1) {
        offset++;
      }
    }

    return chunks;
  }

  bool _isInfoChunk(Uint8List data) {
    if (data.length < 4) return false;
    final listType = String.fromCharCodes(data.sublist(0, 4));
    return listType == 'INFO';
  }
}

class _Chunk {
  final String id;
  final Uint8List data;

  _Chunk({required this.id, required this.data});
}
