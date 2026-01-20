import 'dart:io';

import 'package:mofu_audio_metadata/mofu_audio_metadata.dart';

void main() {
  final reader = AudioMetadataReader();
  final file = File('test/samples/ambient_piano.mp3');

  // Example 1: Fast scan - skip album art
  print('=== Fast Scan (No Album Art) ===');
  final start1 = DateTime.now();
  final metadataNoArt = reader.parseFile(file, ParseOptions.noAlbumArt);
  final elapsed1 = DateTime.now().difference(start1);

  print('Title: ${metadataNoArt.title}');
  print('Artist: ${metadataNoArt.artist}');
  print('Album Art: ${metadataNoArt.albumArt}'); // Will be null
  print('Time: ${elapsed1.inMicroseconds}µs\n');

  // Example 2: Only get album art
  print('=== Album Art Only ===');
  final start2 = DateTime.now();
  final artOnly = reader.parseFile(file, ParseOptions.albumArtOnly);
  final elapsed2 = DateTime.now().difference(start2);

  print('Title: ${artOnly.title}'); // Will be null
  print('Artist: ${artOnly.artist}'); // Will be null
  print('Album Art: ${artOnly.albumArt != null ? '${artOnly.albumArt!.data.length} bytes' : 'null'}');
  print('Time: ${elapsed2.inMicroseconds}µs\n');

  // Example 3: Load everything (default)
  print('=== Full Parse (All Data) ===');
  final start3 = DateTime.now();
  final fullMetadata = reader.parseFile(file); // or ParseOptions.all
  final elapsed3 = DateTime.now().difference(start3);

  print('Title: ${fullMetadata.title}');
  print('Artist: ${fullMetadata.artist}');
  print('Album Art: ${fullMetadata.albumArt != null ? '${fullMetadata.albumArt!.data.length} bytes' : 'null'}');
  print('Time: ${elapsed3.inMicroseconds}µs\n');

  // Use case: Quick directory scan
  print('=== Use Case: Scanning Music Directory ===');
  final musicDir = Directory('test/samples');
  final files = musicDir
      .listSync()
      .whereType<File>()
      .where((f) => f.path.endsWith('.mp3') || f.path.endsWith('.m4a') || f.path.endsWith('.flac'))
      .toList();

  print('Scanning ${files.length} files without album art...');
  final scanStart = DateTime.now();

  for (final audioFile in files) {
    try {
      // Fast scan - no album art for initial listing
      final meta = reader.parseFile(audioFile, ParseOptions.noAlbumArt);
      print('  ${audioFile.path.split(Platform.pathSeparator).last}: ${meta.artist} - ${meta.title}');
    }
    catch (e) {
      continue;
    }
  }

  final scanElapsed = DateTime.now().difference(scanStart);
  print('Scanned in ${scanElapsed.inMilliseconds}ms');
}
