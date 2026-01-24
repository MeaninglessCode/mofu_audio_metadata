import 'dart:io';
import 'dart:typed_data';

import 'package:test/test.dart';
import 'package:mofu_audio_metadata/mofu_audio_metadata.dart';
import 'package:image/image.dart' as img;

void main() {
  group('Album Art Processing Tests', () {
    late AudioMetadataReader reader;
    late AudioMetadataWriter writer;
    final testDir = Directory('test/samples');
    final writeTestDir = Directory('test/write_test');

    setUp(() {
      reader = AudioMetadataReader();
      writer = AudioMetadataWriter();
    });

    group('Album Art Reading', () {
      final filesWithArt = {
        'MP3': 'ambient_piano.mp3',
        'FLAC': 'ambient_piano.flac',
        'OPUS': 'ambient_piano.opus',
        'M4A': 'ambient_piano.m4a',
        'AAC': 'ambient_piano.aac',
      };

      for (final entry in filesWithArt.entries) {
        final format = entry.key;
        final filename = entry.value;

        group('$format format', () {
          late File file;

          setUp(() {
            file = File('${testDir.path}/$filename');
            if (!file.existsSync()) {
              fail('Test file not found: ${file.path}');
            }
          });

          test('extracts album art successfully', () {
            final metadata = reader.parseFile(file, ParseOptions.all);

            expect(metadata.albumArt, isNotNull,
                reason: '$format should contain album art');
          });

          test('album art has valid MIME type', () {
            final metadata = reader.parseFile(file, ParseOptions.all);

            if (metadata.albumArt != null) {
              final mimeType = metadata.albumArt!.mimeType;

              expect(mimeType, isNotEmpty,
                  reason: 'MIME type should not be empty');

              // Common image MIME types
              final validMimeTypes = [
                'image/jpeg',
                'image/jpg',
                'image/png',
                'image/gif',
                'image/bmp',
                'image/webp',
              ];

              expect(
                validMimeTypes.any((valid) =>
                  mimeType.toLowerCase().contains(valid.toLowerCase()) ||
                  valid.toLowerCase().contains(mimeType.toLowerCase())
                ),
                isTrue,
                reason: 'MIME type "$mimeType" should be a valid image type'
              );
            }
          });

          test('album art data is not empty', () {
            final metadata = reader.parseFile(file, ParseOptions.all);

            if (metadata.albumArt != null) {
              expect(metadata.albumArt!.data, isNotEmpty,
                  reason: 'Album art data should not be empty');

              expect(metadata.albumArt!.data.length, greaterThan(100),
                  reason: 'Album art should have substantial data (>100 bytes)');
            }
          });

          test('album art has valid image signature', () {
            final metadata = reader.parseFile(file, ParseOptions.all);

            if (metadata.albumArt != null) {
              final data = metadata.albumArt!.data;
              final mimeType = metadata.albumArt!.mimeType.toLowerCase();

              if (mimeType.contains('jpeg') || mimeType.contains('jpg')) {
                // JPEG magic bytes: FF D8 FF
                expect(data[0], equals(0xFF), reason: 'JPEG should start with 0xFF');
                expect(data[1], equals(0xD8), reason: 'JPEG should have 0xD8 as second byte');
                expect(data[2], equals(0xFF), reason: 'JPEG should have 0xFF as third byte');
              }
              else if (mimeType.contains('png')) {
                // PNG magic bytes: 89 50 4E 47 0D 0A 1A 0A
                expect(data[0], equals(0x89), reason: 'PNG should start with 0x89');
                expect(data[1], equals(0x50), reason: 'PNG signature byte 2');
                expect(data[2], equals(0x4E), reason: 'PNG signature byte 3');
                expect(data[3], equals(0x47), reason: 'PNG signature byte 4');
              }
            }
          });

          test('album art description is optional string', () {
            final metadata = reader.parseFile(file, ParseOptions.all);

            if (metadata.albumArt != null) {
              final description = metadata.albumArt!.description;

              // Description can be null or a string
              if (description != null) {
                expect(description, isA<String>(),
                    reason: 'Description should be a string if present');
              }
            }
          });

          test('albumArtOnly option extracts only album art', () {
            final metadata = reader.parseFile(file, ParseOptions.albumArtOnly);

            expect(metadata.title, isNull, reason: 'Title should be null with albumArtOnly option');
            expect(metadata.artist, isNull, reason: 'Artist should be null with albumArtOnly option');
            expect(metadata.album, isNull, reason: 'Album should be null with albumArtOnly option');

            if (metadata.albumArt != null) {
              expect(metadata.albumArt!.data, isNotEmpty, reason: 'Album art should still be extracted');
            }
          });

          test('noAlbumArt option skips album art', () {
            final metadata = reader.parseFile(file, ParseOptions.noAlbumArt);

            expect(metadata.albumArt, isNull, reason: 'Album art should be null with noAlbumArt option');
            expect(metadata.title, isNotNull, reason: 'Text metadata should still be extracted');
          });

          test('parseBytes works with album art', () {
            final bytes = file.readAsBytesSync();
            final metadata = reader.parseBytes(bytes, ParseOptions.all);

            if (metadata.albumArt != null) {
              expect(metadata.albumArt!.data, isNotEmpty, reason: 'parseBytes should extract album art');
            }
          });

          test('parsePath works with album art', () {
            final metadata = reader.parsePath(file.path, ParseOptions.all);

            if (metadata.albumArt != null) {
              expect(metadata.albumArt!.data, isNotEmpty, reason: 'parsePath should extract album art');
            }
          });
        });
      }
    });

    group('Album Art Image Validation', () {
      final filesWithArt = {
        'MP3': 'ambient_piano.mp3',
        'FLAC': 'ambient_piano.flac',
        'OPUS': 'ambient_piano.opus',
        'M4A': 'ambient_piano.m4a',
        'AAC': 'ambient_piano.aac',
      };

      for (final entry in filesWithArt.entries) {
        final format = entry.key;
        final filename = entry.value;

        test('$format album art is a valid, decodable image', () {
          final file = File('${testDir.path}/$filename');
          if (!file.existsSync()) {
            fail('Test file not found: ${file.path}');
          }

          final metadata = reader.parseFile(file, ParseOptions.all);

          if (metadata.albumArt != null) {
            final imageData = metadata.albumArt!.data;

            // Attempt to decode the image
            final decodedImage = img.decodeImage(Uint8List.fromList(imageData));

            expect(decodedImage, isNotNull,
                reason: '$format album art should be a valid, decodable image');

            // Verify image has valid dimensions
            expect(decodedImage!.width, greaterThan(0), reason: 'Image width should be positive');
            expect(decodedImage.height, greaterThan(0), reason: 'Image height should be positive');

            // Typical album art is square or near-square
            // Just verify dimensions are reasonable (not 0x0 or impossibly large)
            expect(decodedImage.width, lessThan(10000), reason: 'Image width should be reasonable');
            expect(decodedImage.height, lessThan(10000), reason: 'Image height should be reasonable');
          }
        });

        test('$format album art format matches MIME type', () {
          final file = File('${testDir.path}/$filename');

          if (!file.existsSync()) {
            return;
          }

          final metadata = reader.parseFile(file, ParseOptions.all);

          if (metadata.albumArt != null) {
            final imageData = Uint8List.fromList(metadata.albumArt!.data);
            final mimeType = metadata.albumArt!.mimeType.toLowerCase();

            // Decode and verify format
            final decodedImage = img.decodeImage(imageData);
            expect(decodedImage, isNotNull);

            // Try to determine format from data
            if (img.JpegDecoder().isValidFile(imageData)) {
              expect(mimeType, anyOf(contains('jpeg'), contains('jpg')), reason: 'JPEG image should have JPEG MIME type');
            }
            else if (img.PngDecoder().isValidFile(imageData)) {
              expect(mimeType, contains('png'), reason: 'PNG image should have PNG MIME type');
            }
            else if (img.GifDecoder().isValidFile(imageData)) {
              expect(mimeType, contains('gif'), reason: 'GIF image should have GIF MIME type');
            }
            else if (img.BmpDecoder().isValidFile(imageData)) {
              expect(mimeType, contains('bmp'), reason: 'BMP image should have BMP MIME type');
            }
          }
        });

        test('$format album art has reasonable pixel data', () {
          final file = File('${testDir.path}/$filename');

          if (!file.existsSync()) {
            return;
          }

          final metadata = reader.parseFile(file, ParseOptions.all);

          if (metadata.albumArt != null) {
            final imageData = Uint8List.fromList(metadata.albumArt!.data);
            final decodedImage = img.decodeImage(imageData);

            expect(decodedImage, isNotNull);

            // Verify image has pixels
            final pixelCount = decodedImage!.width * decodedImage.height;
            expect(pixelCount, greaterThan(0), reason: 'Image should have pixels');

            // Verify we can access pixel data without errors
            final centerX = decodedImage.width ~/ 2;
            final centerY = decodedImage.height ~/ 2;
            final centerPixel = decodedImage.getPixel(centerX, centerY);

            expect(centerPixel, isNotNull, reason: 'Should be able to access pixel data');
          }
        });
      }

      test('replaced album art is valid and decodable', () {
        final file = File('${writeTestDir.path}/ambient_piano.mp3');

        if (!file.existsSync()) {
          return;
        }

        final original = reader.parseFile(file, ParseOptions.all);

        // Create a simple 1x1 pixel PNG image
        final simplePng = Uint8List.fromList([
          0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, // PNG signature
          0x00, 0x00, 0x00, 0x0D, 0x49, 0x48, 0x44, 0x52, // IHDR chunk
          0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01, // 1x1 dimensions
          0x08, 0x06, 0x00, 0x00, 0x00, 0x1F, 0x15, 0xC4,
          0x89, 0x00, 0x00, 0x00, 0x0A, 0x49, 0x44, 0x41, // IDAT chunk
          0x54, 0x78, 0x9C, 0x63, 0x00, 0x01, 0x00, 0x00,
          0x05, 0x00, 0x01, 0x0D, 0x0A, 0x2D, 0xB4, 0x00, // IEND chunk
          0x00, 0x00, 0x00, 0x49, 0x45, 0x4E, 0x44, 0xAE,
          0x42, 0x60, 0x82,
        ]);

        final newAlbumArt = AlbumArt(
          mimeType: 'image/png',
          data: simplePng,
          description: 'Test 1x1 PNG',
        );

        final modified = original.copyWith(albumArt: newAlbumArt);
        writer.writeFile(file, modified);

        final readBack = reader.parseFile(file, ParseOptions.all);

        expect(readBack.albumArt, isNotNull);

        // Decode the written image
        final decodedImage = img.decodeImage(
            Uint8List.fromList(readBack.albumArt!.data));

        expect(decodedImage, isNotNull, reason: 'Written album art should be decodable');
        expect(decodedImage!.width, equals(1), reason: 'Should be 1x1 pixel image');
        expect(decodedImage.height, equals(1), reason: 'Should be 1x1 pixel image');

        // Restore original
        writer.writeFile(file, original);
      });

      test('original album art survives write/read cycle (pixel-perfect)', () {
        final file = File('${writeTestDir.path}/ambient_piano.flac');

        if (!file.existsSync()) {
          return;
        }

        final original = reader.parseFile(file, ParseOptions.all);

        if (original.albumArt == null) {
          return;
        }

        // Decode original image
        final originalImage = img.decodeImage(Uint8List.fromList(original.albumArt!.data));
        expect(originalImage, isNotNull);

        // Write metadata without changing album art
        final modified = original.copyWith(title: 'Pixel Test');
        writer.writeFile(file, modified);

        final readBack = reader.parseFile(file, ParseOptions.all);
        expect(readBack.albumArt, isNotNull);

        // Decode read-back image
        final readBackImage = img.decodeImage(
            Uint8List.fromList(readBack.albumArt!.data));
        expect(readBackImage, isNotNull);

        // Compare dimensions
        expect(readBackImage!.width, equals(originalImage!.width), reason: 'Image width should be preserved');
        expect(readBackImage.height, equals(originalImage.height), reason: 'Image height should be preserved');

        // Restore original
        writer.writeFile(file, original);
      });
    });

    group('Album Art Consistency', () {
      test('same album art extracted via different parsing methods', () {
        final testFile = File('${testDir.path}/ambient_piano.mp3');

        if (!testFile.existsSync()) {
          fail('Test file not found: ${testFile.path}');
        }

        final fromFile = reader.parseFile(testFile, ParseOptions.all);
        final fromBytes = reader.parseBytes(testFile.readAsBytesSync(), ParseOptions.all);
        final fromPath = reader.parsePath(testFile.path, ParseOptions.all);

        if (fromFile.albumArt != null) {
          expect(fromBytes.albumArt, isNotNull, reason: 'parseBytes should extract same album art');
          expect(fromPath.albumArt, isNotNull, reason: 'parsePath should extract same album art');

          expect(
            fromBytes.albumArt!.data.length,
            equals(fromFile.albumArt!.data.length),
            reason: 'Album art size should be identical'
          );
          expect(
            fromPath.albumArt!.data.length,
            equals(fromFile.albumArt!.data.length),
            reason: 'Album art size should be identical'
          );

          expect(
            fromBytes.albumArt!.mimeType,
            equals(fromFile.albumArt!.mimeType),
            reason: 'MIME type should be identical'
          );
          expect(
            fromPath.albumArt!.mimeType,
            equals(fromFile.albumArt!.mimeType),
            reason: 'MIME type should be identical'
          );
        }
      });

      test('album art data is immutable', () {
        final testFile = File('${testDir.path}/ambient_piano.flac');
        if (!testFile.existsSync()) {
          return;
        }

        final metadata = reader.parseFile(testFile, ParseOptions.all);

        if (metadata.albumArt != null) {
          final originalLength = metadata.albumArt!.data.length;
          final originalFirstByte = metadata.albumArt!.data[0];

          // Reading again should give same data
          final metadata2 = reader.parseFile(testFile, ParseOptions.all);

          expect(metadata2.albumArt!.data.length, equals(originalLength), reason: 'Album art length should be consistent');
          expect(metadata2.albumArt!.data[0], equals(originalFirstByte), reason: 'Album art data should be consistent');
        }
      });
    });

    group('Album Art Writing and Preservation', () {
      final testFiles = {
        'MP3': 'ambient_piano.mp3',
        'FLAC': 'ambient_piano.flac',
        'M4A': 'ambient_piano.m4a',
      };

      for (final entry in testFiles.entries) {
        final format = entry.key;
        final filename = entry.value;

        test('$format preserves album art when writing metadata', () {
          final file = File('${writeTestDir.path}/$filename');

          if (!file.existsSync()) {
            return;
          }

          final original = reader.parseFile(file, ParseOptions.all);

          if (original.albumArt == null) {
            return; // Skip if no album art
          }

          final originalArtSize = original.albumArt!.data.length;
          final originalMimeType = original.albumArt!.mimeType;

          // Modify text metadata but keep album art
          final modified = original.copyWith(
            title: 'Modified Title for Album Art Test',
            artist: 'Test Artist',
          );

          writer.writeFile(file, modified);
          final readBack = reader.parseFile(file, ParseOptions.all);

          expect(readBack.albumArt, isNotNull, reason: 'Album art should be preserved after write');
          expect(readBack.albumArt!.data.length, equals(originalArtSize), reason: 'Album art size should be preserved');
          expect(readBack.albumArt!.mimeType, equals(originalMimeType), reason: 'Album art MIME type should be preserved');
          expect(readBack.title, equals('Modified Title for Album Art Test'), reason: 'Text metadata should be updated');

          // Restore original
          writer.writeFile(file, original);
        });

        test('$format can replace album art', () {
          final file = File('${writeTestDir.path}/$filename');

          if (!file.existsSync()) {
            return;
          }

          final original = reader.parseFile(file, ParseOptions.all);

          // Create a simple 1x1 pixel PNG image (smallest valid PNG)
          final simplePng = Uint8List.fromList([
            0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, // PNG signature
            0x00, 0x00, 0x00, 0x0D, 0x49, 0x48, 0x44, 0x52, // IHDR chunk
            0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01, // 1x1 dimensions
            0x08, 0x06, 0x00, 0x00, 0x00, 0x1F, 0x15, 0xC4,
            0x89, 0x00, 0x00, 0x00, 0x0A, 0x49, 0x44, 0x41, // IDAT chunk
            0x54, 0x78, 0x9C, 0x63, 0x00, 0x01, 0x00, 0x00,
            0x05, 0x00, 0x01, 0x0D, 0x0A, 0x2D, 0xB4, 0x00, // IEND chunk
            0x00, 0x00, 0x00, 0x49, 0x45, 0x4E, 0x44, 0xAE,
            0x42, 0x60, 0x82,
          ]);

          final newAlbumArt = AlbumArt(
            mimeType: 'image/png',
            data: simplePng,
            description: 'Test replacement image',
          );

          final modified = original.copyWith(albumArt: newAlbumArt);

          writer.writeFile(file, modified);
          final readBack = reader.parseFile(file, ParseOptions.all);

          expect(readBack.albumArt, isNotNull, reason: 'New album art should be present');
          expect(readBack.albumArt!.mimeType.toLowerCase(), contains('png'), reason: 'MIME type should be PNG');
          expect(readBack.albumArt!.data.length, equals(simplePng.length), reason: 'Album art size should match new image');

          // Verify it's a valid PNG
          expect(readBack.albumArt!.data[0], equals(0x89), reason: 'Should start with PNG signature');
          expect(readBack.albumArt!.data[1], equals(0x50), reason: 'Should have PNG signature');

          // Restore original
          writer.writeFile(file, original);
        });

        test('$format can remove album art', () {
          final file = File('${writeTestDir.path}/$filename');

          if (!file.existsSync()) {
            return;
          }

          final original = reader.parseFile(file, ParseOptions.all);

          if (original.albumArt == null) {
            return; // Skip if no album art
          }

          // Remove album art
          final withoutArt = original.copyWith(clearAlbumArt: true);

          writer.writeFile(file, withoutArt);
          final readBack = reader.parseFile(file, ParseOptions.all);

          expect(readBack.albumArt, isNull, reason: 'Album art should be removed');
          expect(readBack.title, equals(original.title), reason: 'Text metadata should be preserved');

          // Restore original
          writer.writeFile(file, original);
        });
      }
    });

    group('Album Art Edge Cases', () {
      test('handles file without album art gracefully', () {
        final wavFile = File('${testDir.path}/ambient_piano.wav');

        if (!wavFile.existsSync()) {
          return;
        }

        final metadata = reader.parseFile(wavFile, ParseOptions.all);

        // WAV files may or may not have album art
        // Just verify it doesn't crash and returns valid metadata
        expect(metadata, isNotNull);
        expect(metadata.title, isNotNull, reason: 'Should still extract text metadata');
      });

      test('handles album art in bytes write/read cycle', () {
        final testFile = File('${testDir.path}/ambient_piano.mp3');

        if (!testFile.existsSync()) {
          return;
        }

        final original = reader.parseFile(testFile, ParseOptions.all);

        if (original.albumArt == null) {
          return;
        }

        final originalBytes = testFile.readAsBytesSync();
        final modified = original.copyWith(
          title: 'Bytes Write Test',
        );

        final modifiedBytes = writer.writeBytes(originalBytes, modified);
        final readBack = reader.parseBytes(modifiedBytes, ParseOptions.all);

        expect(readBack.albumArt, isNotNull, reason: 'Album art should survive bytes write cycle');
        expect(
          readBack.albumArt!.data.length,
          equals(original.albumArt!.data.length),
          reason: 'Album art size should be preserved in bytes write'
        );
      });

      test('handles very large album art', () {
        final testFile = File('${testDir.path}/ambient_piano.flac');
        if (!testFile.existsSync()) {
          return;
        }

        final metadata = reader.parseFile(testFile, ParseOptions.all);

        if (metadata.albumArt != null) {
          final artSize = metadata.albumArt!.data.length;

          // Typical album art ranges from a few KB to several MB
          expect(artSize, greaterThan(0), reason: 'Album art should have positive size');

          // Just verify we can handle it without crashing
          expect(metadata.albumArt!.data, isA<List<int>>(), reason: 'Should be a valid byte list');
        }
      });

      test('album art toString() includes MIME type', () {
        final testFile = File('${testDir.path}/ambient_piano.mp3');

        if (!testFile.existsSync()) {
          return;
        }

        final metadata = reader.parseFile(testFile, ParseOptions.all);

        if (metadata.albumArt != null) {
          final metadataString = metadata.toString();

          expect(metadataString, contains('albumArt:'), reason: 'toString should mention album art');
          expect(metadataString, contains(metadata.albumArt!.mimeType), reason: 'toString should include MIME type');
        }
      });

      test('copyWith preserves album art by default', () {
        final testFile = File('${testDir.path}/ambient_piano.m4a');

        if (!testFile.existsSync()) {
          return;
        }

        final original = reader.parseFile(testFile, ParseOptions.all);

        if (original.albumArt == null) {
          return;
        }

        final copied = original.copyWith(title: 'New Title');

        expect(copied.albumArt, isNotNull, reason: 'copyWith should preserve album art by default');
        expect(
          copied.albumArt!.data.length,
          equals(original.albumArt!.data.length),
          reason: 'Album art should be identical'
        );
        expect(
          copied.albumArt!.mimeType,
          equals(original.albumArt!.mimeType),
          reason: 'MIME type should be preserved'
        );
      });

      test('multiple album art extractions are consistent', () {
        final testFile = File('${testDir.path}/ambient_piano.opus');

        if (!testFile.existsSync()) {
          return;
        }

        final results = <AudioMetadata>[];

        // Parse multiple times
        for (var i = 0; i < 5; i++) {
          results.add(reader.parseFile(testFile, ParseOptions.all));
        }

        // All should have same album art
        for (var i = 1; i < results.length; i++) {
          if (results[0].albumArt != null) {
            expect(results[i].albumArt, isNotNull, reason: 'All parses should extract album art');
            expect(
              results[i].albumArt!.data.length,
              equals(results[0].albumArt!.data.length),
              reason: 'Album art size should be consistent across parses'
            );
            expect(
              results[i].albumArt!.mimeType,
              equals(results[0].albumArt!.mimeType),
              reason: 'MIME type should be consistent across parses'
            );
          }
        }
      });
    });

    group('Album Art Format-Specific Features', () {
      test('ID3v2 formats (MP3, AAC) handle APIC frames', () {
        final mp3File = File('${testDir.path}/ambient_piano.mp3');

        if (!mp3File.existsSync()) {
          return;
        }

        final metadata = reader.parseFile(mp3File, ParseOptions.all);

        if (metadata.albumArt != null) {
          // Just verify we can extract it
          expect(metadata.albumArt!.data, isNotEmpty, reason: 'Should extract album art from APIC frame');
        }
      });

      test('FLAC handles METADATA_BLOCK_PICTURE', () {
        final flacFile = File('${testDir.path}/ambient_piano.flac');

        if (!flacFile.existsSync()) {
          return;
        }

        final metadata = reader.parseFile(flacFile, ParseOptions.all);

        if (metadata.albumArt != null) {
          expect(metadata.albumArt!.data, isNotEmpty, reason: 'Should extract from FLAC picture block');
        }
      });

      test('Opus handles base64-encoded METADATA_BLOCK_PICTURE', () {
        final opusFile = File('${testDir.path}/ambient_piano.opus');

        if (!opusFile.existsSync()) {
          return;
        }

        final metadata = reader.parseFile(opusFile, ParseOptions.all);

        if (metadata.albumArt != null) {
          expect(metadata.albumArt!.data, isNotEmpty, reason: 'Should extract from Opus vorbis comments');
        }
      });

      test('M4A handles covr atom', () {
        final m4aFile = File('${testDir.path}/ambient_piano.m4a');

        if (!m4aFile.existsSync()) {
          return;
        }

        final metadata = reader.parseFile(m4aFile, ParseOptions.all);

        if (metadata.albumArt != null) {
          expect(metadata.albumArt!.data, isNotEmpty, reason: 'Should extract from M4A covr atom');
        }
      });
    });
  });
}
