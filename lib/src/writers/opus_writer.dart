import 'dart:typed_data';

import 'package:mofu_audio_metadata/src/models/audio_metadata.dart';
import 'package:mofu_audio_metadata/src/writers/metadata_writer.dart';
import 'package:mofu_audio_metadata/src/containers/ogg_container.dart';
import 'package:mofu_audio_metadata/src/formats/vorbis/vorbis_comment_writer.dart';
import 'package:mofu_audio_metadata/src/utils/binary_utils.dart';

/// Writer for OPUS audio files (Ogg container).
///
/// Writes Vorbis Comments to OPUS files. Replaces the OpusTags page.
class OpusWriter implements MetadataWriter {
  static const _opusHeadSignature = 'OpusHead';
  static const _opusTagsSignature = 'OpusTags';

  @override
  bool canWrite(Uint8List bytes) {
    if (!OggContainer.isOggFile(bytes)) return false;

    final pages = OggContainer.parsePages(bytes);
    if (pages.isEmpty) return false;

    final firstPage = pages.first;
    if (firstPage.data.length < 8) return false;

    final signature = String.fromCharCodes(firstPage.data.sublist(0, 8));
    return signature == _opusHeadSignature;
  }

  @override
  Uint8List write(Uint8List bytes, AudioMetadata metadata) {
    if (!canWrite(bytes)) {
      throw FormatException('Invalid OPUS file');
    }

    final pages = OggContainer.parsePages(bytes);

    // Build new OpusTags page data
    final commentData = VorbisCommentWriter.build(metadata);
    final opusTagsData = BytesBuilder();
    opusTagsData.add(_opusTagsSignature.codeUnits);
    opusTagsData.add(commentData);

    // Find the OpusTags page (usually second page)
    int tagsPageIndex = -1;
    for (var i = 0; i < pages.length; i++) {
      if (pages[i].data.length >= 8) {
        final sig = String.fromCharCodes(pages[i].data.sublist(0, 8));
        if (sig == _opusTagsSignature) {
          tagsPageIndex = i;
          break;
        }
      }
    }

    if (tagsPageIndex == -1) {
      throw FormatException('OpusTags page not found');
    }

    // Rebuild the file with new OpusTags
    return _rebuildOggFile(bytes, pages, tagsPageIndex, opusTagsData.toBytes());
  }

  @override
  Uint8List strip(Uint8List bytes) {
    // For OPUS, we can't completely remove tags - create minimal tags
    final minimalMetadata = const AudioMetadata();
    return write(bytes, minimalMetadata);
  }

  Uint8List _rebuildOggFile(
    Uint8List originalBytes,
    List<OggPage> pages,
    int tagsPageIndex,
    Uint8List newTagsData
  ) {
    final result = BytesBuilder();
    var currentOffset = 0;

    for (var i = 0; i < pages.length; i++) {
      final page = pages[i];

      // Find original page in bytes
      final pageStart = _findPageStart(originalBytes, currentOffset, page);

      if (i == tagsPageIndex) {
        // Replace this page with new OpusTags
        final newPage = _buildOggPage(
          newTagsData,
          page.serialNumber,
          page.sequenceNumber,
          page.headerType,
          page.granulePosition
        );
        result.add(newPage);
      }
      else {
        // Copy original page
        final pageSize = _calculatePageSize(page);
        result.add(originalBytes.sublist(pageStart, pageStart + pageSize));
      }

      currentOffset = pageStart + _calculatePageSize(page);
    }

    return result.toBytes();
  }

  int _findPageStart(Uint8List bytes, int startOffset, OggPage targetPage) {
    var offset = startOffset;

    while (offset < bytes.length - 27) {
      if (bytes[offset] == 0x4F &&
          bytes[offset + 1] == 0x67 &&
          bytes[offset + 2] == 0x67 &&
          bytes[offset + 3] == 0x53) {
        // Check if this matches our target page by sequence number
        final seqNum = bytes[offset + 18] |
                       (bytes[offset + 19] << 8) |
                       (bytes[offset + 20] << 16) |
                       (bytes[offset + 21] << 24);

        if (seqNum == targetPage.sequenceNumber) {
          return offset;
        }
      }
      offset++;
    }

    return startOffset;
  }

  int _calculatePageSize(OggPage page) {
    final dataSize = page.segments.fold<int>(0, (sum, len) => sum + len);
    return 27 + page.segments.length + dataSize;
  }

  Uint8List _buildOggPage(
    Uint8List data,
    int serialNumber,
    int sequenceNumber,
    int headerType,
    int granulePosition
  ) {
    final builder = BytesBuilder();

    // Capture pattern "OggS"
    builder.add([0x4F, 0x67, 0x67, 0x53]);

    // Stream structure version
    builder.addByte(0);

    // Header type
    builder.addByte(headerType);

    // Granule position (8 bytes, little-endian)
    for (var i = 0; i < 8; i++) {
      builder.addByte((granulePosition >> (i * 8)) & 0xFF);
    }

    // Serial number (4 bytes, little-endian)
    builder.add(BinaryUtils.encodeUint32LE(serialNumber));

    // Sequence number (4 bytes, little-endian)
    builder.add(BinaryUtils.encodeUint32LE(sequenceNumber));

    // CRC (4 bytes) - will be calculated after
    final crcOffset = builder.length;
    builder.add([0, 0, 0, 0]);

    // Build segment table
    final segments = <int>[];
    var remaining = data.length;

    while (remaining > 0) {
      if (remaining >= 255) {
        segments.add(255);
        remaining -= 255;
      }
      else {
        segments.add(remaining);
        remaining = 0;
      }
    }

    // If data length is multiple of 255, add terminating 0
    if (data.isNotEmpty && data.length % 255 == 0) {
      segments.add(0);
    }

    // Number of segments
    builder.addByte(segments.length);

    // Segment table
    builder.add(segments);

    // Page data
    builder.add(data);

    // Calculate and insert CRC
    final pageBytes = builder.toBytes();
    final crc = _calculateCrc32(pageBytes);
    pageBytes[crcOffset] = crc & 0xFF;
    pageBytes[crcOffset + 1] = (crc >> 8) & 0xFF;
    pageBytes[crcOffset + 2] = (crc >> 16) & 0xFF;
    pageBytes[crcOffset + 3] = (crc >> 24) & 0xFF;

    return pageBytes;
  }

  /// Calculate Ogg CRC-32.
  int _calculateCrc32(Uint8List data) {
    const table = [
      0x00000000, 0x04c11db7, 0x09823b6e, 0x0d4326d9,
      0x130476dc, 0x17c56b6b, 0x1a864db2, 0x1e475005,
      0x2608edb8, 0x22c9f00f, 0x2f8ad6d6, 0x2b4bcb61,
      0x350c9b64, 0x31cd86d3, 0x3c8ea00a, 0x384fbdbd,
      0x4c11db70, 0x48d0c6c7, 0x4593e01e, 0x4152fda9,
      0x5f15adac, 0x5bd4b01b, 0x569796c2, 0x52568b75,
      0x6a1936c8, 0x6ed82b7f, 0x639b0da6, 0x675a1011,
      0x791d4014, 0x7ddc5da3, 0x709f7b7a, 0x745e66cd,
      0x9823b6e0, 0x9ce2ab57, 0x91a18d8e, 0x95609039,
      0x8b27c03c, 0x8fe6dd8b, 0x82a5fb52, 0x8664e6e5,
      0xbe2b5b58, 0xbaea46ef, 0xb7a96036, 0xb3687d81,
      0xad2f2d84, 0xa9ee3033, 0xa4ad16ea, 0xa06c0b5d,
      0xd4326d90, 0xd0f37027, 0xddb056fe, 0xd9714b49,
      0xc7361b4c, 0xc3f706fb, 0xceb42022, 0xca753d95,
      0xf23a8028, 0xf6fb9d9f, 0xfbb8bb46, 0xff79a6f1,
      0xe13ef6f4, 0xe5ffeb43, 0xe8bccd9a, 0xec7dd02d,
      0x34867077, 0x30476dc0, 0x3d044b19, 0x39c556ae,
      0x278206ab, 0x23431b1c, 0x2e003dc5, 0x2ac12072,
      0x128e9dcf, 0x164f8078, 0x1b0ca6a1, 0x1fcdbb16,
      0x018aeb13, 0x054bf6a4, 0x0808d07d, 0x0cc9cdca,
      0x7897ab07, 0x7c56b6b0, 0x71159069, 0x75d48dde,
      0x6b93dddb, 0x6f52c06c, 0x6211e6b5, 0x66d0fb02,
      0x5e9f46bf, 0x5a5e5b08, 0x571d7dd1, 0x53dc6066,
      0x4d9b3063, 0x495a2dd4, 0x44190b0d, 0x40d816ba,
      0xaca5c697, 0xa864db20, 0xa527fdf9, 0xa1e6e04e,
      0xbfa1b04b, 0xbb60adfc, 0xb6238b25, 0xb2e29692,
      0x8aad2b2f, 0x8e6c3698, 0x832f1041, 0x87ee0df6,
      0x99a95df3, 0x9d684044, 0x902b669d, 0x94ea7b2a,
      0xe0b41de7, 0xe4750050, 0xe9362689, 0xedf73b3e,
      0xf3b06b3b, 0xf771768c, 0xfa325055, 0xfef34de2,
      0xc6bcf05f, 0xc27dede8, 0xcf3ecb31, 0xcbffd686,
      0xd5b88683, 0xd1799b34, 0xdc3abded, 0xd8fba05a,
      0x690ce0ee, 0x6dcdfd59, 0x608edb80, 0x644fc637,
      0x7a089632, 0x7ec98b85, 0x738aad5c, 0x774bb0eb,
      0x4f040d56, 0x4bc510e1, 0x46863638, 0x42472b8f,
      0x5c007b8a, 0x58c1663d, 0x558240e4, 0x51435d53,
      0x251d3b9e, 0x21dc2629, 0x2c9f00f0, 0x285e1d47,
      0x36194d42, 0x32d850f5, 0x3f9b762c, 0x3b5a6b9b,
      0x0315d626, 0x07d4cb91, 0x0a97ed48, 0x0e56f0ff,
      0x1011a0fa, 0x14d0bd4d, 0x19939b94, 0x1d528623,
      0xf12f560e, 0xf5ee4bb9, 0xf8ad6d60, 0xfc6c70d7,
      0xe22b20d2, 0xe6ea3d65, 0xeba91bbc, 0xef68060b,
      0xd727bbb6, 0xd3e6a601, 0xdea580d8, 0xda649d6f,
      0xc423cd6a, 0xc0e2d0dd, 0xcda1f604, 0xc960ebb3,
      0xbd3e8d7e, 0xb9ff90c9, 0xb4bcb610, 0xb07daba7,
      0xae3afba2, 0xaafbe615, 0xa7b8c0cc, 0xa379dd7b,
      0x9b3660c6, 0x9ff77d71, 0x92b45ba8, 0x9675461f,
      0x8832161a, 0x8cf30bad, 0x81b02d74, 0x857130c3,
      0x5d8a9099, 0x594b8d2e, 0x5408abf7, 0x50c9b640,
      0x4e8ee645, 0x4a4ffbf2, 0x470cdd2b, 0x43cdc09c,
      0x7b827d21, 0x7f436096, 0x7200464f, 0x76c15bf8,
      0x68860bfd, 0x6c47164a, 0x61043093, 0x65c52d24,
      0x119b4be9, 0x155a565e, 0x18197087, 0x1cd86d30,
      0x029f3d35, 0x065e2082, 0x0b1d065b, 0x0fdc1bec,
      0x3793a651, 0x3352bbe6, 0x3e119d3f, 0x3ad08088,
      0x2497d08d, 0x2056cd3a, 0x2d15ebe3, 0x29d4f654,
      0xc5a92679, 0xc1683bce, 0xcc2b1d17, 0xc8ea00a0,
      0xd6ad50a5, 0xd26c4d12, 0xdf2f6bcb, 0xdbee767c,
      0xe3a1cbc1, 0xe760d676, 0xea23f0af, 0xeee2ed18,
      0xf0a5bd1d, 0xf464a0aa, 0xf9278673, 0xfde69bc4,
      0x89b8fd09, 0x8d79e0be, 0x803ac667, 0x84fbdbd0,
      0x9abc8bd5, 0x9e7d9662, 0x933eb0bb, 0x97ffad0c,
      0xafb010b1, 0xab710d06, 0xa6322bdf, 0xa2f33668,
      0xbcb4666d, 0xb8757bda, 0xb5365d03, 0xb1f740b4
    ];

    var crc = 0;

    for (var i = 0; i < data.length; i++) {
      crc = ((crc << 8) ^ table[((crc >> 24) & 0xFF) ^ data[i]]) & 0xFFFFFFFF;
    }

    return crc;
  }
}
