import 'dart:convert';
import 'dart:typed_data';

import 'package:mofu_audio_metadata/src/models/audio_metadata.dart';
import 'package:mofu_audio_metadata/src/formats/id3/id3v2_parser.dart';
import 'package:mofu_audio_metadata/src/utils/binary_utils.dart';

/// Writer for ID3v2.4 tags.
///
/// Creates ID3v2.4 tags using UTF-8 encoding for text frames. Supports standard text frames,
/// comments (COMM), lyrics (USLT), and album art (APIC).
class ID3v2Writer {
  /// Builds an ID3v2.4 tag from the given metadata and returns the completed tag as a Uint8List
  /// byte array.
  static Uint8List build(AudioMetadata metadata) {
    final frames = <Uint8List>[];

    // Text frames
    _addTextFrame(frames, 'TIT2', metadata.title);
    _addTextFrame(frames, 'TPE1', metadata.artist);
    _addTextFrame(frames, 'TALB', metadata.album);
    _addTextFrame(frames, 'TPE2', metadata.albumArtist);
    _addTextFrame(frames, 'TDRC', metadata.date);
    _addTextFrame(frames, 'TCON', metadata.genre);
    _addTextFrame(frames, 'TCOM', metadata.composer);
    _addTextFrame(frames, 'TPUB', metadata.publisher);

    // Track number (format: "track/total" or just "track")
    if (metadata.trackNumber != null) {
      final trackStr = metadata.totalTracks != null
          ? '${metadata.trackNumber}/${metadata.totalTracks}'
          : '${metadata.trackNumber}';

      _addTextFrame(frames, 'TRCK', trackStr);
    }

    // Disc number
    if (metadata.discNumber != null) {
      final discStr = metadata.totalDiscs != null
          ? '${metadata.discNumber}/${metadata.totalDiscs}'
          : '${metadata.discNumber}';

      _addTextFrame(frames, 'TPOS', discStr);
    }

    // Comment (COMM frame)
    if (metadata.comment != null && metadata.comment!.isNotEmpty) {
      frames.add(_buildCommFrame(metadata.comment!));
    }

    // Lyrics (USLT frame)
    if (metadata.lyrics != null && metadata.lyrics!.isNotEmpty) {
      frames.add(_buildUsltFrame(metadata.lyrics!));
    }

    // Album art (APIC frame)
    if (metadata.albumArt != null) {
      frames.add(_buildApicFrame(metadata.albumArt!));
    }

    // Calculate total frames size
    final framesSize = frames.fold<int>(0, (sum, frame) => sum + frame.length);

    // Build tag header
    final tag = BytesBuilder();

    // ID3 signature
    tag.add([0x49, 0x44, 0x33]); // "ID3"

    // Version 2.4.0
    tag.add([0x04, 0x00]);

    // Flags (none)
    tag.addByte(0x00);

    // Tag size (synchsafe integer, excludes header)
    tag.add(BinaryUtils.encodeSynchsafeInt32(framesSize));

    // Add all frames
    for (final frame in frames) {
      tag.add(frame);
    }

    return tag.toBytes();
  }

  /// Writes metadata to the given MP3 file bytes.
  /// 
  /// Any existing ID3v2 tag information will be replaced with the new metadata. The updated file
  /// is returned as a new Uint8List of bytes.
  static Uint8List write(Uint8List bytes, AudioMetadata metadata) {
    final newTag = build(metadata);

    // Find where the audio data starts
    int audioStart = 0;

    if (ID3v2Parser.hasID3v2Tag(bytes)) {
      // Skip existing ID3v2 tag
      final tagSize = ID3v2Parser.getTagSize(bytes);
      audioStart = 10 + tagSize;

      // Check for footer (rare)
      if (bytes.length >= 10 && (bytes[5] & 0x10) != 0) {
        audioStart += 10;
      }
    }

    // Build new file
    final result = BytesBuilder();
    result.add(newTag);
    result.add(bytes.sublist(audioStart));

    return result.toBytes();
  }

  /// Removes ID3v2 tag information from the given MP3 file bytes.
  /// 
  /// Returns a new Uint8List of bytes with the metadata removed. Any ID3v1 tags at the end of the
  /// file are preserved.
  static Uint8List strip(Uint8List bytes) {
    if (!ID3v2Parser.hasID3v2Tag(bytes)) {
      return bytes;
    }

    final tagSize = ID3v2Parser.getTagSize(bytes);
    var audioStart = 10 + tagSize;

    // Check for footer
    if (bytes.length >= 10 && (bytes[5] & 0x10) != 0) {
      audioStart += 10;
    }

    return Uint8List.fromList(bytes.sublist(audioStart));
  }

  static void _addTextFrame(List<Uint8List> frames, String id, String? value) {
    if (value == null || value.isEmpty) return;

    frames.add(_buildTextFrame(id, value));
  }

  static Uint8List _buildTextFrame(String id, String value) {
    final frameBuilder = BytesBuilder();

    // Frame ID (4 bytes)
    frameBuilder.add(id.codeUnits);

    // Encode text as UTF-8
    final textBytes = utf8.encode(value);

    // Frame size (synchsafe integer): 1 byte encoding + text
    final frameSize = 1 + textBytes.length;
    frameBuilder.add(BinaryUtils.encodeSynchsafeInt32(frameSize));

    // Frame flags (none)
    frameBuilder.add([0x00, 0x00]);

    // Text encoding: 3 = UTF-8
    frameBuilder.addByte(0x03);

    // Text content
    frameBuilder.add(textBytes);

    return frameBuilder.toBytes();
  }

  static Uint8List _buildCommFrame(String comment) {
    final frameBuilder = BytesBuilder();

    // Frame ID
    frameBuilder.add('COMM'.codeUnits);

    // Encode comment as UTF-8
    final commentBytes = utf8.encode(comment);

    // Frame size: 1 byte encoding + 3 bytes language + 1 byte null (empty description) + comment
    final frameSize = 1 + 3 + 1 + commentBytes.length;
    frameBuilder.add(BinaryUtils.encodeSynchsafeInt32(frameSize));

    // Frame flags
    frameBuilder.add([0x00, 0x00]);

    // Text encoding: 3 = UTF-8
    frameBuilder.addByte(0x03);

    // Language: "eng"
    frameBuilder.add([0x65, 0x6E, 0x67]);

    // Short description (empty, null-terminated)
    frameBuilder.addByte(0x00);

    // Comment text
    frameBuilder.add(commentBytes);

    return frameBuilder.toBytes();
  }

  static Uint8List _buildUsltFrame(String lyrics) {
    final frameBuilder = BytesBuilder();

    // Frame ID
    frameBuilder.add('USLT'.codeUnits);

    // Encode lyrics as UTF-8
    final lyricsBytes = utf8.encode(lyrics);

    // Frame size: 1 byte encoding + 3 bytes language + 1 byte null (empty description) + lyrics
    final frameSize = 1 + 3 + 1 + lyricsBytes.length;
    frameBuilder.add(BinaryUtils.encodeSynchsafeInt32(frameSize));

    // Frame flags
    frameBuilder.add([0x00, 0x00]);

    // Text encoding: 3 = UTF-8
    frameBuilder.addByte(0x03);

    // Language: "eng"
    frameBuilder.add([0x65, 0x6E, 0x67]);

    // Content descriptor (empty, null-terminated)
    frameBuilder.addByte(0x00);

    // Lyrics text
    frameBuilder.add(lyricsBytes);

    return frameBuilder.toBytes();
  }

  static Uint8List _buildApicFrame(AlbumArt albumArt) {
    final frameBuilder = BytesBuilder();

    // Frame ID
    frameBuilder.add('APIC'.codeUnits);

    // MIME type (null-terminated)
    final mimeBytes = utf8.encode(albumArt.mimeType);

    // Description (null-terminated, can be empty)
    final descBytes = albumArt.description != null
        ? utf8.encode(albumArt.description!)
        : <int>[];

    // Frame size: 1 byte encoding + mime + null + 1 byte picture type + desc + null + data
    final frameSize = 1 + mimeBytes.length + 1 + 1 + descBytes.length + 1 + albumArt.data.length;
    frameBuilder.add(BinaryUtils.encodeSynchsafeInt32(frameSize));

    // Frame flags
    frameBuilder.add([0x00, 0x00]);

    // Text encoding: 0 = ISO-8859-1 (for MIME type compatibility)
    frameBuilder.addByte(0x00);

    // MIME type
    frameBuilder.add(mimeBytes);
    frameBuilder.addByte(0x00); // Null terminator

    // Picture type: 3 = Cover (front)
    frameBuilder.addByte(0x03);

    // Description
    frameBuilder.add(descBytes);
    frameBuilder.addByte(0x00); // Null terminator

    // Picture data
    frameBuilder.add(albumArt.data);

    return frameBuilder.toBytes();
  }
}
