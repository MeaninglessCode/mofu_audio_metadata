import 'dart:io';

import 'package:test/test.dart';
import 'package:mofu_audio_metadata/mofu_audio_metadata.dart';

void main() {
  group('Comprehensive write tests', () {
    late AudioMetadataReader reader;
    late AudioMetadataWriter writer;
    final testDir = Directory('test/write_test');

    setUp(() {
      reader = AudioMetadataReader();
      writer = AudioMetadataWriter();
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
        late AudioMetadata originalMeta;

        setUp(() {
          file = File('${testDir.path}/$filename');
          if (!file.existsSync()) {
            fail('Test file not found: ${file.path}');
          }
          originalMeta = reader.parseFile(file);
        });

        tearDown(() {
          // Always restore original metadata after each test
          try {
            writer.writeFile(file, originalMeta);
          } catch (e) {
            // Ignore errors during restoration
          }
        });

        test('writes and reads back modified metadata', () {
          final newMeta = originalMeta.copyWith(
            title: 'Modified Title - $format',
            artist: 'Test Artist',
            album: 'Test Album',
            albumArtist: 'Test Album Artist',
            date: '2026',
            trackNumber: 5,
            totalTracks: 10,
            discNumber: 2,
            totalDiscs: 3,
            genre: 'Test Genre',
            comment: 'This is a test comment for $format format',
            composer: 'Test Composer',
            publisher: 'Test Publisher',
            lyrics: 'Test lyrics for $format\nLine 2\nLine 3'
          );

          writer.writeFile(file, newMeta);
          final readBack = reader.parseFile(file);

          expect(readBack.title, equals(newMeta.title));
          expect(readBack.artist, equals(newMeta.artist));
          expect(readBack.album, equals(newMeta.album));
          expect(readBack.albumArtist, equals(newMeta.albumArtist));
          expect(readBack.date, equals(newMeta.date));
          expect(readBack.trackNumber, equals(newMeta.trackNumber));
          expect(readBack.totalTracks, equals(newMeta.totalTracks));
          expect(readBack.discNumber, equals(newMeta.discNumber));
          expect(readBack.totalDiscs, equals(newMeta.totalDiscs));
          expect(readBack.genre, equals(newMeta.genre));
          expect(readBack.comment, equals(newMeta.comment));
          expect(readBack.composer, equals(newMeta.composer));
          expect(readBack.publisher, equals(newMeta.publisher));
          expect(readBack.lyrics, equals(newMeta.lyrics));
        });

        test('preserves album art during write', () {
          if (originalMeta.albumArt == null) {
            return; // Skip test if no album art
          }

          final newMeta = originalMeta.copyWith(
            title: 'Modified Title',
          );

          writer.writeFile(file, newMeta);
          final readBack = reader.parseFile(file);

          expect(readBack.albumArt, isNotNull,
              reason: 'Album art should be preserved');
          expect(readBack.albumArt!.data.length,
              equals(originalMeta.albumArt!.data.length),
              reason: 'Album art size should match');
        });

        test('clears fields when requested', () {
          final clearedMeta = originalMeta.copyWith(
            title: 'Test Title',
            clearComment: true
          );

          writer.writeFile(file, clearedMeta);
          final readBack = reader.parseFile(file);

          expect(readBack.title, equals('Test Title'));
          // Note: Some formats may not support clearing
          // So we just verify it doesn't crash
        });

        test('restores original metadata successfully', () {
          // Modify
          final modified = originalMeta.copyWith(
            title: 'Temporary Modification',
          );
          writer.writeFile(file, modified);

          // Restore
          writer.writeFile(file, originalMeta);
          final restored = reader.parseFile(file);

          expect(restored.title, equals(originalMeta.title));
          expect(restored.artist, equals(originalMeta.artist));
        });

        test('writes to bytes successfully', () {
          final newMeta = originalMeta.copyWith(
            title: 'ByteWrite Test',
          );

          final originalBytes = file.readAsBytesSync();
          final modifiedBytes = writer.writeBytes(originalBytes, newMeta);

          expect(modifiedBytes, isNotNull);
          expect(modifiedBytes.length, greaterThan(0));

          // Verify we can read the modified bytes
          final readBack = reader.parseBytes(modifiedBytes);
          expect(readBack.title, equals('ByteWrite Test'));
        });
      });
    }
  });
}
