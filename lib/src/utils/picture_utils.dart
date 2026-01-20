import 'dart:typed_data';
import 'dart:convert';

import 'package:mofu_audio_metadata/src/models/audio_metadata.dart';
import 'package:mofu_audio_metadata/src/utils/binary_utils.dart';

/// Utility functions for parsing embedded album artwork
class PictureUtils {
  /// Parse FLAC METADATA_BLOCK_PICTURE format
  ///
  /// This format is used by FLAC and OPUS (as base64-encoded in Vorbis Comments).
  /// Format specification:
  /// - Picture type (4 bytes, big-endian)
  /// - MIME type length (4 bytes, big-endian)
  /// - MIME type (variable length UTF-8 string)
  /// - Description length (4 bytes, big-endian)
  /// - Description (variable length UTF-8 string)
  /// - Width, height, color depth, indexed colors (16 bytes total)
  /// - Picture data length (4 bytes, big-endian)
  /// - Picture data (variable length)
  static AlbumArt? parseFLACMetadataBlockPicture(Uint8List data) {
    try {
      var offset = 0;

      // Picture type (4 bytes, big-endian)
      if (offset + 4 > data.length) return null;
      offset += 4;

      // MIME type length (4 bytes, big-endian)
      if (offset + 4 > data.length) return null;
      final mimeLength = BinaryUtils.readUint32BE(data, offset);
      offset += 4;

      if (offset + mimeLength > data.length) return null;

      // MIME type
      final mimeType = utf8.decode(data.sublist(offset, offset + mimeLength));
      offset += mimeLength;

      // Description length (4 bytes, big-endian)
      if (offset + 4 > data.length) return null;
      final descLength = BinaryUtils.readUint32BE(data, offset);
      offset += 4;

      // Description
      String? description;
      if (descLength > 0 && offset + descLength <= data.length) {
        description = utf8.decode(data.sublist(offset, offset + descLength));
        offset += descLength;
      }

      // Skip width, height, color depth, indexed colors (16 bytes total)
      if (offset + 16 > data.length) return null;
      offset += 16;

      // Picture data length (4 bytes, big-endian)
      if (offset + 4 > data.length) return null;
      final pictureLength = BinaryUtils.readUint32BE(data, offset);
      offset += 4;

      if (offset + pictureLength > data.length) return null;

      // Picture data
      final pictureData = data.sublist(offset, offset + pictureLength);

      return AlbumArt(
        mimeType: mimeType,
        data: pictureData,
        description: description?.isNotEmpty == true ? description : null
      );
    }
    catch (e) {
      return null;
    }
  }

  /// Parse FLAC METADATA_BLOCK_PICTURE from base64-encoded string
  ///
  /// Used by OPUS in Vorbis Comments (METADATA_BLOCK_PICTURE tag).
  static AlbumArt? parseFLACMetadataBlockPictureBase64(String base64Data) {
    try {
      final decoded = base64.decode(base64Data);
      final data = Uint8List.fromList(decoded);

      return parseFLACMetadataBlockPicture(data);
    }
    catch (e) {
      return null;
    }
  }
}
