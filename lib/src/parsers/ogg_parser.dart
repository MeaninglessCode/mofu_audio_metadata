// This file is deprecated and maintained for backward compatibility.
// Use the following imports instead:
// - package:mofu_audio_metadata/src/containers/ogg_container.dart
// - package:mofu_audio_metadata/src/formats/vorbis/vorbis_comment_parser.dart

export 'package:mofu_audio_metadata/src/containers/ogg_container.dart'
    show OggPage, OggContainer;
export 'package:mofu_audio_metadata/src/formats/vorbis/vorbis_comment_parser.dart'
    show VorbisCommentParser;

// Re-export OggContainer as OggParser for backward compatibility
import 'package:mofu_audio_metadata/src/containers/ogg_container.dart';

/// @Deprecated('Use OggContainer instead')
typedef OggParser = OggContainer;
