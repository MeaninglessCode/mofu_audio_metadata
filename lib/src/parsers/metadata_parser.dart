import 'dart:typed_data';

import 'package:mofu_audio_metadata/src/models/audio_metadata.dart';
import 'package:mofu_audio_metadata/src/models/parse_options.dart';

/// Base interface for metadata parsers
abstract class MetadataParser {
  /// Parse metadata from the given file bytes.
  ///
  /// Options are set using the [ParseOptions] parameter, defaulting to [ParseOptions.all].
  AudioMetadata parse(Uint8List bytes, [ParseOptions options = ParseOptions.all]);

  /// Check if this parser can extract metadata from the given bytes
  bool canParse(Uint8List bytes);
}
