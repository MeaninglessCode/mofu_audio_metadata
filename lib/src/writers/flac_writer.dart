import 'dart:typed_data';

import 'package:mofu_audio_metadata/src/models/audio_metadata.dart';
import 'package:mofu_audio_metadata/src/writers/metadata_writer.dart';
import 'package:mofu_audio_metadata/src/formats/vorbis/vorbis_comment_writer.dart';
import 'package:mofu_audio_metadata/src/utils/binary_utils.dart';

/// Writer for native FLAC audio files.
///
/// Writes Vorbis Comments to FLAC files. Replaces existing VORBIS_COMMENT
/// and PICTURE metadata blocks.
class FlacWriter implements MetadataWriter {
  static const _flacSignature = [0x66, 0x4C, 0x61, 0x43]; // "fLaC"

  @override
  bool canWrite(Uint8List bytes) {
    if (bytes.length < 4) return false;

    return bytes[0] == _flacSignature[0] && bytes[1] == _flacSignature[1] && bytes[2] == _flacSignature[2] && bytes[3] == _flacSignature[3];
  }

  @override
  Uint8List write(Uint8List bytes, AudioMetadata metadata) {
    if (!canWrite(bytes)) {
      throw FormatException('Invalid FLAC file');
    }

    // Build new Vorbis Comment block
    final commentData = VorbisCommentWriter.build(metadata);

    // Parse existing metadata blocks
    final blocks = _parseMetadataBlocks(bytes);

    // Find STREAMINFO block (required, must be first)
    final streamInfoBlock = blocks.firstWhere(
      (b) => b.type == 0,
      orElse: () => throw FormatException('Missing STREAMINFO block')
    );

    // Build new file
    final result = BytesBuilder();

    // FLAC signature
    result.add(_flacSignature);

    // STREAMINFO block (always first, not last)
    result.add(_buildMetadataBlockHeader(0, streamInfoBlock.data.length, false));
    result.add(streamInfoBlock.data);

    // Vorbis Comment block
    result.add(_buildMetadataBlockHeader(4, commentData.length, metadata.albumArt == null));
    result.add(commentData);

    // Picture block (if album art present)
    if (metadata.albumArt != null) {
      final pictureData = _buildPictureBlock(metadata.albumArt!);
      result.add(_buildMetadataBlockHeader(6, pictureData.length, true));
      result.add(pictureData);
    }

    // Audio data (everything after metadata blocks)
    final audioStart = _findAudioStart(bytes);
    result.add(bytes.sublist(audioStart));

    return result.toBytes();
  }

  @override
  Uint8List strip(Uint8List bytes) {
    if (!canWrite(bytes)) {
      throw FormatException('Invalid FLAC file');
    }

    // Parse existing metadata blocks
    final blocks = _parseMetadataBlocks(bytes);

    // Keep only STREAMINFO
    final streamInfoBlock = blocks.firstWhere(
      (b) => b.type == 0,
      orElse: () => throw FormatException('Missing STREAMINFO block')
    );

    // Build new file
    final result = BytesBuilder();

    // FLAC signature
    result.add(_flacSignature);

    // STREAMINFO block (marked as last)
    result.add(_buildMetadataBlockHeader(0, streamInfoBlock.data.length, true));
    result.add(streamInfoBlock.data);

    // Audio data
    final audioStart = _findAudioStart(bytes);
    result.add(bytes.sublist(audioStart));

    return result.toBytes();
  }

  List<_MetadataBlock> _parseMetadataBlocks(Uint8List bytes) {
    final blocks = <_MetadataBlock>[];
    var offset = 4; // Skip "fLaC"

    while (offset < bytes.length) {
      if (offset + 4 > bytes.length) break;

      final header = bytes[offset];
      final isLast = (header & 0x80) != 0;
      final blockType = header & 0x7F;
      final blockSize = BinaryUtils.readUint24BE(bytes, offset + 1);

      offset += 4;

      if (offset + blockSize > bytes.length) break;

      final blockData = bytes.sublist(offset, offset + blockSize);
      blocks.add(_MetadataBlock(type: blockType, data: blockData));

      offset += blockSize;

      if (isLast) break;
    }

    return blocks;
  }

  int _findAudioStart(Uint8List bytes) {
    var offset = 4; // Skip "fLaC"

    while (offset < bytes.length) {
      if (offset + 4 > bytes.length) break;

      final header = bytes[offset];
      final isLast = (header & 0x80) != 0;
      final blockSize = BinaryUtils.readUint24BE(bytes, offset + 1);

      offset += 4 + blockSize;

      if (isLast) break;
    }

    return offset;
  }

  Uint8List _buildMetadataBlockHeader(int type, int size, bool isLast) {
    final header = isLast ? (type | 0x80) : type;
    return Uint8List.fromList([
      header,
      (size >> 16) & 0xFF,
      (size >> 8) & 0xFF,
      size & 0xFF
    ]);
  }

  Uint8List _buildPictureBlock(AlbumArt albumArt) {
    final builder = BytesBuilder();

    // Picture type: 3 = Cover (front)
    builder.add(BinaryUtils.encodeUint32BE(3));

    // MIME type
    final mimeBytes = albumArt.mimeType.codeUnits;
    builder.add(BinaryUtils.encodeUint32BE(mimeBytes.length));
    builder.add(mimeBytes);

    // Description
    final descBytes = albumArt.description?.codeUnits ?? <int>[];
    builder.add(BinaryUtils.encodeUint32BE(descBytes.length));
    builder.add(descBytes);

    // Dimensions (0 = unknown)
    builder.add(BinaryUtils.encodeUint32BE(0)); // width
    builder.add(BinaryUtils.encodeUint32BE(0)); // height
    builder.add(BinaryUtils.encodeUint32BE(0)); // color depth
    builder.add(BinaryUtils.encodeUint32BE(0)); // colors used

    // Picture data
    builder.add(BinaryUtils.encodeUint32BE(albumArt.data.length));
    builder.add(albumArt.data);

    return builder.toBytes();
  }
}

class _MetadataBlock {
  final int type;
  final Uint8List data;

  _MetadataBlock({required this.type, required this.data});
}
