import 'dart:typed_data';

import 'package:mofu_audio_metadata/src/models/audio_metadata.dart';

/// Base interface for metadata writers.
///
/// Writers modify the metadata portion of audio files while preserving
/// the audio data unchanged.
abstract class MetadataWriter {
  /// Write metadata to the given file bytes.
  ///
  /// Returns a new Uint8List with the updated metadata.
  /// The original audio data is preserved.
  Uint8List write(Uint8List bytes, AudioMetadata metadata);

  /// Check if this writer can handle the given file format.
  bool canWrite(Uint8List bytes);

  /// Remove all metadata from the given file bytes.
  ///
  /// Returns a new Uint8List with metadata stripped.
  Uint8List strip(Uint8List bytes);
}
