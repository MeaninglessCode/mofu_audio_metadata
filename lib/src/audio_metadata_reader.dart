import 'dart:io';
import 'dart:typed_data';

import 'package:mofu_audio_metadata/src/models/audio_metadata.dart';
import 'package:mofu_audio_metadata/src/models/parse_options.dart';
import 'package:mofu_audio_metadata/src/parsers/parsers.dart';

/// Main class for reading audio metadata
class AudioMetadataReader {
  /// Internal list of supported audio metadata parsers. For AAC, M4A is checked first as it is more
  /// specific. The AAC reader is last as the ADTS format can be more ambiguous.
  final List<MetadataParser> _parsers = [
    M4aParser(),
    Mp3Parser(),
    FlacParser(),
    WavParser(),
    OpusParser(),
    AacParser()
  ];

  /// Parse File object and return AudioMetadata if the format is supported.
  ///
  /// Options are set using the [ParseOptions] parameter, defaulting to [ParseOptions.all].
  AudioMetadata parseFile(File file, [ParseOptions options = ParseOptions.all]) {
    final bytes = file.readAsBytesSync();
    return parseBytes(Uint8List.fromList(bytes), options);
  }

  /// Parse byte array and return AudioMetadata if the format is supported.
  ///
  /// Options are set using the [ParseOptions] parameter, defaulting to [ParseOptions.all].
  AudioMetadata parseBytes(Uint8List bytes, [ParseOptions options = ParseOptions.all]) {
    for (final parser in _parsers) {
      if (parser.canParse(bytes)) {
        return parser.parse(bytes, options);
      }
    }

    throw UnsupportedError('Unsupported audio file format');
  }

  /// Parse file at [path] and return AudioMetadata if the format is supported.
  ///
  /// Options are set using the [ParseOptions] parameter, defaulting to [ParseOptions.all].
  AudioMetadata parsePath(String path, [ParseOptions options = ParseOptions.all]) {
    return parseFile(File(path), options);
  }

  /// Returns true if the given bytes are a supported format, false otherwise.
  bool isSupported(Uint8List bytes) {
    return _parsers.any((parser) => parser.canParse(bytes));
  }

  /// Returns true if the file at the specified path is a supported format, false otherwise.
  bool isSupportedPath(String path) {
    final file = File(path);

    if (!file.existsSync()) {
      return false;
    }

    return isSupported(Uint8List.fromList(file.readAsBytesSync()));
  }
}
