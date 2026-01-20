import 'dart:typed_data';

import 'package:mofu_audio_metadata/src/models/audio_metadata.dart';
import 'package:mofu_audio_metadata/src/writers/metadata_writer.dart';
import 'package:mofu_audio_metadata/src/formats/id3/id3v2_parser.dart';
import 'package:mofu_audio_metadata/src/formats/id3/id3v2_writer.dart';

/// Writer for MP3 audio files.
///
/// Writes ID3v2.4 tags to MP3 files. Existing ID3v2 tags are replaced.
/// ID3v1 tags at the end of the file are preserved.
class Mp3Writer implements MetadataWriter {
  @override
  bool canWrite(Uint8List bytes) {
    // Check for ID3v2 tag or MP3 frame sync
    if (ID3v2Parser.hasID3v2Tag(bytes)) {
      return true;
    }

    // Check for MP3 frame sync in first few bytes
    if (bytes.length >= 2) {
      for (var i = 0; i < bytes.length - 1 && i < 16; i++) {
        if (bytes[i] == 0xFF && (bytes[i + 1] & 0xE0) == 0xE0) {
          final layerBits = (bytes[i + 1] >> 1) & 0x03;
          if (layerBits != 0) return true;
        }
      }
    }

    return false;
  }

  @override
  Uint8List write(Uint8List bytes, AudioMetadata metadata) {
    return ID3v2Writer.write(bytes, metadata);
  }

  @override
  Uint8List strip(Uint8List bytes) {
    return ID3v2Writer.strip(bytes);
  }
}
