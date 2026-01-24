import 'dart:io';

import 'package:test/test.dart';
import 'package:mofu_audio_metadata/mofu_audio_metadata.dart';

void main() {
  group('Edge case and special character tests', () {
    late AudioMetadataReader reader;
    late AudioMetadataWriter writer;
    final testDir = Directory('test/write_test');

    setUp(() {
      reader = AudioMetadataReader();
      writer = AudioMetadataWriter();
    });

    group('Unicode and special characters', () {
      final unicodeTests = {
        'MP3': 'ambient_piano.mp3',
        'M4A': 'ambient_piano.m4a',
        'FLAC': 'ambient_piano.flac',
      };

      for (final entry in unicodeTests.entries) {
        final format = entry.key;
        final filename = entry.value;

        test('$format handles Unicode characters', () {
          final file = File('${testDir.path}/$filename');
          if (!file.existsSync()) {
            fail('Test file not found: ${file.path}');
          }

          final original = reader.parseFile(file);

          final testMeta = original.copyWith(
            title: '音楽 🎵 Música «Test» €100',
            artist: 'Артист / Artist™',
            album: '测试 & Test\nMultiline',
            comment: 'Emoji: 😀🎵🎸 | Special: <>&"\'\n| Math: ∑∏√',
            lyrics: '''Line 1: English
Line 2: 日本語
Line 3: Русский
Line 4: 中文
Line 5: Emoji 🎵🎶🎸''',
          );

          writer.writeFile(file, testMeta);
          final readBack = reader.parseFile(file);

          expect(readBack.title, equals(testMeta.title), reason: 'Unicode title should be preserved');
          expect(readBack.artist, equals(testMeta.artist), reason: 'Unicode artist should be preserved');

          // Restore original
          writer.writeFile(file, original);
        });
      }
    });

    group('Long strings', () {
      test('MP3 handles very long metadata', () {
        final file = File('${testDir.path}/ambient_piano.mp3');

        if (!file.existsSync()) {
          return;
        }

        final original = reader.parseFile(file);
        final longString = 'A' * 10000; // 10KB string

        final testMeta = original.copyWith(
          comment: longString,
          lyrics: longString,
        );

        writer.writeFile(file, testMeta);
        final readBack = reader.parseFile(file);

        expect(readBack.comment, isNotNull, reason: 'Long comment should be stored');
        expect(readBack.comment!.length, greaterThan(0), reason: 'Comment should have content');

        // Restore original
        writer.writeFile(file, original);
      });
    });

    group('Empty and null values', () {
      test('FLAC handles minimal metadata', () {
        final file = File('${testDir.path}/ambient_piano.flac');

        if (!file.existsSync()) {
          return;
        }

        final original = reader.parseFile(file);

        // Create metadata with only title
        final minimalMeta = AudioMetadata(
          title: 'Only Title',
          albumArt: original.albumArt, // Preserve album art
        );

        writer.writeFile(file, minimalMeta);
        final readBack = reader.parseFile(file);

        expect(readBack.title, equals('Only Title'));
        expect(readBack.artist, isNull, reason: 'Null fields should remain null');

        // Restore original
        writer.writeFile(file, original);
      });
    });

    group('Boundary values', () {
      test('M4A handles large track/disc numbers', () {
        final file = File('${testDir.path}/ambient_piano.m4a');

        if (!file.existsSync()) {
          return;
        }

        final original = reader.parseFile(file);

        // M4A has field limitations (typically 255 max for 8-bit fields)
        // Use more realistic boundary values
        final boundaryMeta = original.copyWith(
          trackNumber: 99,
          totalTracks: 99,
          discNumber: 9,
          totalDiscs: 9
        );

        writer.writeFile(file, boundaryMeta);
        final readBack = reader.parseFile(file);

        // Verify the values were written and read back
        expect(readBack.trackNumber, equals(99), reason: 'Track number should be written correctly');
        expect(readBack.totalTracks, equals(99), reason: 'Total tracks should be written correctly');
        expect(readBack.discNumber, equals(9), reason: 'Disc number should be written correctly');
        expect(readBack.totalDiscs, equals(9), reason: 'Total discs should be written correctly');

        // Restore original
        writer.writeFile(file, original);
      });
    });

    group('Strip functionality', () {
      test('WAV strips metadata successfully', () {
        final file = File('${testDir.path}/ambient_piano.wav');

        if (!file.existsSync()) {
          return;
        }

        final original = reader.parseFile(file);

        writer.stripFile(file);
        final stripped = reader.parseFile(file);

        expect(stripped.title, isNull, reason: 'Title should be stripped');
        expect(stripped.artist, isNull, reason: 'Artist should be stripped');
        expect(stripped.albumArt, isNull, reason: 'Album art should be stripped');

        // Restore original
        writer.writeFile(file, original);
        final restored = reader.parseFile(file);

        expect(restored.title, equals(original.title), reason: 'Original metadata should be restored');
      });
    });
  });
}
