import 'dart:io';

import 'package:test/test.dart';
import 'package:mofu_audio_metadata/mofu_audio_metadata.dart';

void main() {
  group('Comprehensive parsing tests', () {
    late AudioMetadataReader reader;
    final testDir = Directory('test/samples');

    setUp(() {
      reader = AudioMetadataReader();
    });

    final files = {
      'MP3': 'ambient_piano.mp3',
      'FLAC': 'ambient_piano.flac',
      'OPUS': 'ambient_piano.opus',
      'M4A': 'ambient_piano.m4a',
      'AAC': 'ambient_piano.aac',
      'WAV': 'ambient_piano.wav',
    };

    for (final entry in files.entries) {
      final format = entry.key;
      final filename = entry.value;

      group('$format ($filename)', () {
        late File file;

        setUp(() {
          file = File('${testDir.path}/$filename');
          if (!file.existsSync()) {
            fail('Test file not found: ${file.path}');
          }
        });

        test('parses full metadata with album art', () {
          final fullMeta = reader.parseFile(file, ParseOptions.all);

          expect(fullMeta.title, isNotNull);
          expect(fullMeta.artist, isNotNull);
          expect(fullMeta.album, isNotNull);
          expect(fullMeta.rawTags, isNotEmpty);

          // Most test files should have album art
          if (format != 'WAV') {
            expect(fullMeta.albumArt, isNotNull,
                reason: 'Expected album art for $format');
            expect(fullMeta.albumArt!.data.length, greaterThan(0));
          }
        });

        test('parses without album art', () {
          final noArtMeta = reader.parseFile(file, ParseOptions.noAlbumArt);

          expect(noArtMeta.albumArt, isNull,
              reason: 'Album art should be skipped');
          expect(noArtMeta.title, isNotNull,
              reason: 'Text metadata should be preserved');
        });

        test('parses album art only', () {
          final artOnlyMeta = reader.parseFile(file, ParseOptions.albumArtOnly);

          expect(artOnlyMeta.title, isNull,
              reason: 'Text metadata should be skipped');
          expect(artOnlyMeta.artist, isNull,
              reason: 'Text metadata should be skipped');

          // Album art availability depends on format
          if (format != 'WAV') {
            expect(artOnlyMeta.albumArt, isNotNull,
                reason: 'Album art should be extracted for $format');
          }
        });

        test('detects format correctly', () {
          final bytes = file.readAsBytesSync();
          expect(reader.isSupported(bytes), isTrue,
              reason: '$format should be detected as supported');
        });

        test('supports path-based parsing', () {
          final fullMeta = reader.parseFile(file);
          final pathMeta = reader.parsePath(file.path);

          expect(pathMeta.title, equals(fullMeta.title),
              reason: 'Path parsing should produce same result');
          expect(pathMeta.artist, equals(fullMeta.artist),
              reason: 'Path parsing should produce same result');
        });

        test('supports isSupportedPath', () {
          expect(reader.isSupportedPath(file.path), isTrue,
              reason: 'isSupportedPath should return true for $format');
        });
      });
    }
  });
}
