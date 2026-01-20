/// A lightweight, pure Dart library for reading and writing metadata to audio files.
///
/// Supports various audio formats and requires zero dependencies.
///
/// ### Supported Formats
/// - MP3 (.mp3) - ID3v1, ID3v2.2, ID3v2.3, ID3v2.4
/// - M4A/AAC (.m4a, .aac) - MP4 metadata atoms and ID3 tags
/// - FLAC (.flac) - Native FLAC and Ogg FLAC with Vorbis Comments
/// - WAV (.wav) - ID3v2 and RIFF INFO tags
/// - OPUS (.opus) - Vorbis Comments
library;

export 'package:mofu_audio_metadata/src/audio_metadata_reader.dart';

export 'package:mofu_audio_metadata/src/audio_metadata_writer.dart';

export 'package:mofu_audio_metadata/src/models/audio_metadata.dart';
export 'package:mofu_audio_metadata/src/models/parse_options.dart';

export 'package:mofu_audio_metadata/src/parsers/metadata_parser.dart';
export 'package:mofu_audio_metadata/src/writers/metadata_writer.dart';
