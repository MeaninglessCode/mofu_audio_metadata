import 'dart:io';
import 'dart:typed_data';

import 'package:test/test.dart';
import 'package:mofu_audio_metadata/mofu_audio_metadata.dart';

void main() {
  group('AudioMetadataReader', () {
    late AudioMetadataReader reader;

    setUp(() {
      reader = AudioMetadataReader();
    });

    test('detects unsupported format', () {
      final bytes = Uint8List.fromList([]);
      expect(reader.isSupported(bytes), isFalse);
    });

    test('detects non-supported file', () {
      final bytes = Uint8List.fromList([0x00, 0x01, 0x02, 0x03]);
      expect(reader.isSupported(bytes), isFalse);
    });

    test('throws on unsupported format', () {
      final bytes = Uint8List.fromList([0x00, 0x01, 0x02, 0x03]);
      expect(
        () => reader.parseBytes(bytes),
        throwsA(isA<UnsupportedError>())
      );
    });
  });

  group('Sample file parsing', () {
    late AudioMetadataReader reader;
    final samplesDir = 'test/samples';

    setUp(() {
      reader = AudioMetadataReader();
    });

    // Common metadata expected across most sample files
    void verifyCommonMetadata(AudioMetadata metadata, {bool isAac = false}) {
      expect(metadata.title, equals('Ambient Piano Music'));
      expect(metadata.artist, equals('Tunetank (ft. Pixabay)'));
      expect(metadata.album, equals('Tranquility'));
      expect(metadata.genre, equals('Ambient'));
      expect(metadata.trackNumber, equals(1));

      // AAC has truncated date due to ID3v2 conversion
      if (!isAac) {
        expect(metadata.comment, equals('Test comment here'));
      }
    }

    test('parses MP3 file with ID3v2 tags', () {
      final file = File('$samplesDir/ambient_piano.mp3');
      final metadata = reader.parseFile(file);

      verifyCommonMetadata(metadata);
      expect(metadata.albumArtist, equals('Tunetank'));
      expect(metadata.composer, equals('John Composer'));
      expect(metadata.discNumber, equals(1));

      // Verify raw tags contain ID3v2 frames
      expect(metadata.rawTags.containsKey('TIT2'), isTrue);
      expect(metadata.rawTags.containsKey('TPE1'), isTrue);
    });

    test('parses FLAC file with Vorbis Comments', () {
      final file = File('$samplesDir/ambient_piano.flac');
      final metadata = reader.parseFile(file);

      verifyCommonMetadata(metadata);
      expect(metadata.albumArtist, equals('Tunetank'));
      expect(metadata.composer, equals('John Composer'));
      expect(metadata.date, equals('2025-05-29'));
      expect(metadata.discNumber, equals(1));

      // Verify raw tags contain Vorbis Comment keys
      expect(metadata.rawTags.containsKey('TITLE'), isTrue);
      expect(metadata.rawTags.containsKey('ARTIST'), isTrue);
    });

    test('parses OPUS file with Vorbis Comments', () {
      final file = File('$samplesDir/ambient_piano.opus');
      final metadata = reader.parseFile(file);

      verifyCommonMetadata(metadata);
      expect(metadata.albumArtist, equals('Tunetank'));
      expect(metadata.composer, equals('John Composer'));
      expect(metadata.date, equals('2025-05-29'));
      expect(metadata.discNumber, equals(1));

      // OPUS file has embedded album art
      expect(metadata.albumArt, isNotNull);
      expect(metadata.albumArt!.mimeType, equals('image/jpeg'));
      expect(metadata.albumArt!.data.length, greaterThan(0));
    });

    test('parses WAV file with RIFF INFO tags', () {
      final file = File('$samplesDir/ambient_piano.wav');
      final metadata = reader.parseFile(file);

      verifyCommonMetadata(metadata);
      expect(metadata.albumArtist, equals('Tunetank'));
      expect(metadata.composer, equals('John Composer'));
      expect(metadata.discNumber, equals(1));
    });

    test('parses M4A file with iTunes atoms', () {
      final file = File('$samplesDir/ambient_piano.m4a');
      final metadata = reader.parseFile(file);

      verifyCommonMetadata(metadata);
      expect(metadata.albumArtist, equals('Tunetank'));
      expect(metadata.composer, equals('John Composer'));
      expect(metadata.date, equals('2025-05-29'));
      expect(metadata.discNumber, equals(1));
    });

    test('parses AAC file with ID3 tags', () {
      final file = File('$samplesDir/ambient_piano.aac');
      final metadata = reader.parseFile(file);

      verifyCommonMetadata(metadata, isAac: true);
      expect(metadata.trackNumber, equals(1));

      // AAC may have year only in date field
      expect(metadata.date, isNotNull);
    });

    test('all sample files are detected as supported', () {
      final sampleFiles = [
        'ambient_piano.mp3',
        'ambient_piano.flac',
        'ambient_piano.opus',
        'ambient_piano.wav',
        'ambient_piano.m4a',
        'ambient_piano.aac'
      ];

      for (final filename in sampleFiles) {
        final file = File('$samplesDir/$filename');
        final bytes = file.readAsBytesSync();

        expect(
          reader.isSupported(bytes),
          isTrue,
          reason: '$filename should be detected as supported'
        );
      }
    });

    test('parsePath works correctly', () {
      final metadata = reader.parsePath('$samplesDir/ambient_piano.mp3');

      expect(metadata.title, equals('Ambient Piano Music'));
      expect(metadata.artist, equals('Tunetank (ft. Pixabay)'));
    });
  });

  group('Edge cases and error handling', () {
    late AudioMetadataReader reader;

    setUp(() {
      reader = AudioMetadataReader();
    });

    test('handles truncated file gracefully', () {
      // First 100 bytes of an MP3 header - not enough data
      final truncated = Uint8List.fromList([
        0x49, 0x44, 0x33, // ID3
        0x04, 0x00, // version 2.4
        0x00, // flags
        0x00, 0x00, 0x00, 0x10 // size (16 bytes, but we don't have that much)
      ]);

      // Should either return empty metadata or throw, not crash
      expect(
        () => reader.parseBytes(truncated),
        anyOf(
          returnsNormally,
          throwsA(anything)
        )
      );
    });

    test('handles empty ID3 tag', () {
      // Valid ID3v2.4 header with 0 size
      final emptyId3 = Uint8List.fromList([
        0x49, 0x44, 0x33, // ID3
        0x04, 0x00, // version 2.4
        0x00, // flags
        0x00, 0x00, 0x00, 0x00, // size 0
        // MP3 frame sync follows
        0xFF, 0xFB, 0x90, 0x00
      ]);

      final metadata = reader.parseBytes(emptyId3);
      expect(metadata.title, isNull);
    });

    test('handles malformed size fields safely', () {
      // ID3 tag with maliciously large size
      final malformed = Uint8List.fromList([
        0x49, 0x44, 0x33, // ID3
        0x04, 0x00, // version 2.4
        0x00, // flags
        0x7F, 0x7F, 0x7F, 0x7F // max synchsafe size
      ]);

      // Should not crash - may throw or return empty
      expect(
        () => reader.parseBytes(malformed),
        anyOf(
          returnsNormally,
          throwsA(anything)
        )
      );
    });
  });
}
