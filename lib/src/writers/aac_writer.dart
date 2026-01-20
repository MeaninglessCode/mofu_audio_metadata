import 'dart:typed_data';

import 'package:mofu_audio_metadata/src/models/audio_metadata.dart';
import 'package:mofu_audio_metadata/src/writers/metadata_writer.dart';
import 'package:mofu_audio_metadata/src/formats/id3/id3v2_parser.dart';
import 'package:mofu_audio_metadata/src/formats/id3/id3v2_writer.dart';
import 'package:mofu_audio_metadata/src/utils/binary_utils.dart';

/// Writer for AAC audio files (ADTS container).
///
/// Writes ID3v2 tags at the beginning of AAC/ADTS files.
class AacWriter implements MetadataWriter {
  @override
  bool canWrite(Uint8List bytes) {
    if (bytes.length < 10) return false;

    // Check for ID3v2 tag at beginning
    var offset = 0;
    if (ID3v2Parser.hasID3v2Tag(bytes)) {
      // Skip ID3v2 tag
      final tagSize = BinaryUtils.parseSynchsafeInt32(bytes, 6);
      offset = 10 + tagSize;

      if (offset >= bytes.length) return false;
    }

    // Check for ADTS sync word (0xFFF)
    if (offset + 2 <= bytes.length) {
      final syncWord = (bytes[offset] << 4) | (bytes[offset + 1] >> 4);
      return syncWord == 0xFFF;
    }

    return false;
  }

  @override
  Uint8List write(Uint8List bytes, AudioMetadata metadata) {
    if (!canWrite(bytes)) {
      throw FormatException('Invalid AAC file');
    }

    // Build new ID3v2 tag
    final newTag = ID3v2Writer.build(metadata);

    // Find where the ADTS audio data starts
    int audioStart = 0;

    if (ID3v2Parser.hasID3v2Tag(bytes)) {
      // Skip existing ID3v2 tag
      final tagSize = ID3v2Parser.getTagSize(bytes);
      audioStart = 10 + tagSize;

      // Check for footer (rare)
      if (bytes.length >= 10 && (bytes[5] & 0x10) != 0) {
        audioStart += 10;
      }
    }

    // Build new file with new tag and ADTS data
    final result = BytesBuilder();
    result.add(newTag);
    result.add(bytes.sublist(audioStart));

    return result.toBytes();
  }

  @override
  Uint8List strip(Uint8List bytes) {
    if (!canWrite(bytes)) {
      return bytes;
    }

    // AAC files can exist without ID3 tags - just remove the tag
    if (!ID3v2Parser.hasID3v2Tag(bytes)) {
      return bytes;
    }

    final tagSize = ID3v2Parser.getTagSize(bytes);
    var audioStart = 10 + tagSize;

    // Check for footer
    if (bytes.length >= 10 && (bytes[5] & 0x10) != 0) {
      audioStart += 10;
    }

    return Uint8List.fromList(bytes.sublist(audioStart));
  }
}
