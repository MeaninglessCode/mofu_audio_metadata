import 'dart:io';
import 'dart:typed_data';

import 'package:mofu_audio_metadata/src/models/audio_metadata.dart';
import 'package:mofu_audio_metadata/src/writers/writers.dart';

/// Main class for writing audio metadata.
///
/// Provides a unified interface for writing metadata to various audio formats.
/// Each format has its own writer that handles the specific encoding.
class AudioMetadataWriter {
  /// Internal list of supported audio metadata writers.
  /// Order matters - more specific formats should come first.
  final List<MetadataWriter> _writers = [
    M4aWriter(),
    Mp3Writer(),
    FlacWriter(),
    WavWriter(),
    OpusWriter(),
    AacWriter()
  ];

  /// Write metadata to a file and save it.
  ///
  /// Reads the file, writes the metadata, and saves the result back.
  /// Returns the updated AudioMetadata.
  void writeFile(File file, AudioMetadata metadata) {
    final bytes = file.readAsBytesSync();
    final updatedBytes = writeBytes(Uint8List.fromList(bytes), metadata);
    file.writeAsBytesSync(updatedBytes);
  }

  /// Write metadata to a byte array.
  ///
  /// Returns a new Uint8List with the updated metadata.
  /// The original audio data is preserved.
  Uint8List writeBytes(Uint8List bytes, AudioMetadata metadata) {
    for (final writer in _writers) {
      if (writer.canWrite(bytes)) {
        return writer.write(bytes, metadata);
      }
    }

    throw UnsupportedError('Unsupported audio file format for writing');
  }

  /// Write metadata to a file at the specified path.
  void writePath(String path, AudioMetadata metadata) {
    writeFile(File(path), metadata);
  }

  /// Strip all metadata from a file and save it.
  void stripFile(File file) {
    final bytes = file.readAsBytesSync();
    final strippedBytes = stripBytes(Uint8List.fromList(bytes));
    file.writeAsBytesSync(strippedBytes);
  }

  /// Strip all metadata from a byte array.
  ///
  /// Returns a new Uint8List with metadata removed.
  Uint8List stripBytes(Uint8List bytes) {
    for (final writer in _writers) {
      if (writer.canWrite(bytes)) {
        return writer.strip(bytes);
      }
    }

    throw UnsupportedError('Unsupported audio file format for stripping');
  }

  /// Strip all metadata from a file at the specified path.
  void stripPath(String path) {
    stripFile(File(path));
  }

  /// Returns true if the given bytes can be written to, false otherwise.
  bool canWrite(Uint8List bytes) {
    return _writers.any((writer) => writer.canWrite(bytes));
  }

  /// Returns true if the file at the specified path can be written to.
  bool canWritePath(String path) {
    final file = File(path);

    if (!file.existsSync()) {
      return false;
    }

    return canWrite(Uint8List.fromList(file.readAsBytesSync()));
  }
}
