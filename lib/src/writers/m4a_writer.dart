import 'dart:typed_data';

import 'package:mofu_audio_metadata/src/models/audio_metadata.dart';
import 'package:mofu_audio_metadata/src/writers/metadata_writer.dart';
import 'package:mofu_audio_metadata/src/formats/mp4/mp4_atom_writer.dart';

/// Writer for M4A/MP4 audio files.
///
/// Writes iTunes-style metadata atoms to M4A files.
class M4aWriter implements MetadataWriter {
  static const _ftypSignature = [0x66, 0x74, 0x79, 0x70]; // "ftyp"

  @override
  bool canWrite(Uint8List bytes) {
    if (bytes.length < 12) return false;

    // Check for ftyp atom at offset 4
    if (bytes[4] != _ftypSignature[0] || bytes[5] != _ftypSignature[1] || bytes[6] != _ftypSignature[2] || bytes[7] != _ftypSignature[3]) {
      return false;
    }

    // Check for M4A/MP4 compatible brands
    final brand = String.fromCharCodes(bytes.sublist(8, 12));
    return brand == 'M4A ' || brand == 'M4B ' || brand == 'mp42' || brand == 'isom' || brand == 'iso2';
  }

  @override
  Uint8List write(Uint8List bytes, AudioMetadata metadata) {
    return Mp4AtomWriter.write(bytes, metadata);
  }

  @override
  Uint8List strip(Uint8List bytes) {
    return Mp4AtomWriter.strip(bytes);
  }
}
