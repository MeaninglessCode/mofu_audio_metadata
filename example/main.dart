import 'dart:io';

import 'package:mofu_audio_metadata/mofu_audio_metadata.dart';

void main() {
  final reader = AudioMetadataReader();

  // Example 1: Parse different audio formats
  final examples = [
    'path/to/song.mp3',
    'path/to/song.m4a',
    'path/to/song.aac',
    'path/to/song.flac',
    'path/to/song.wav',
    'path/to/song.opus',
  ];

  for (final path in examples) {
    try {
      final metadata = reader.parsePath(path);
      print('\n=== $path ===');
      print('Title: ${metadata.title}');
      print('Artist: ${metadata.artist}');
      print('Album: ${metadata.album}');
      print('Track: ${metadata.trackNumber}/${metadata.totalTracks}');
      print('Genre: ${metadata.genre}');
      print('Date: ${metadata.date}');

      if (metadata.albumArt != null) {
        print('Album art: ${metadata.albumArt!.mimeType}, ${metadata.albumArt!.data.length} bytes');
      }

      print('\nRaw tags:');
      metadata.rawTags.forEach((key, values) {
        print('  $key: ${values.join(', ')}');
      });
    }
    catch (e) {
      print('Error parsing $path: $e');
    }
  }

  // Example 2: Check if file is supported before parsing
  final file = File('path/to/audio.opus');
  if (file.existsSync()) {
    final bytes = file.readAsBytesSync();

    if (reader.isSupported(bytes)) {
      final metadata = reader.parseBytes(bytes);

      print('\n$metadata');
    }
    else {
      print('File format not supported');
    }
  }

  // Example 3: Parse using File object
  try {
    final audioFile = File('path/to/another.opus');
    final metadata = reader.parseFile(audioFile);

    print('\nMetadata: $metadata');
  }
  catch (e) {
    print('Error: $e');
  }
}
