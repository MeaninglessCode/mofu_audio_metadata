import 'dart:convert';
import 'dart:typed_data';

import 'package:mofu_audio_metadata/src/models/audio_metadata.dart';
import 'package:mofu_audio_metadata/src/utils/binary_utils.dart';

/// Writer for MP4/M4A atoms and iTunes metadata.
///
/// Creates iTunes-style metadata in the ilst atom format.
/// Supports text atoms, numeric atoms, and cover art.
class Mp4AtomWriter {
  /// Build an ILST atom containing the given metadata.
  ///
  /// Returns a Uint8List containing the complete ILST atom.
  static Uint8List buildIlst(AudioMetadata metadata) {
    final atoms = <Uint8List>[];

    // Text atoms (©xxx format)
    _addTextAtom(atoms, '\u00a9nam', metadata.title);
    _addTextAtom(atoms, '\u00a9ART', metadata.artist);
    _addTextAtom(atoms, '\u00a9alb', metadata.album);
    _addTextAtom(atoms, 'aART', metadata.albumArtist);
    _addTextAtom(atoms, '\u00a9day', metadata.date);
    _addTextAtom(atoms, '\u00a9gen', metadata.genre);
    _addTextAtom(atoms, '\u00a9cmt', metadata.comment);
    _addTextAtom(atoms, '\u00a9wrt', metadata.composer);
    _addTextAtom(atoms, '\u00a9pub', metadata.publisher);
    _addTextAtom(atoms, '\u00a9lyr', metadata.lyrics);

    // Track number (TRKN atom - binary format)
    if (metadata.trackNumber != null) {
      atoms.add(_buildTrknAtom(
        metadata.trackNumber!,
        metadata.totalTracks ?? 0
      ));
    }

    // Disc number (DISK atom - binary format)
    if (metadata.discNumber != null) {
      atoms.add(_buildDiskAtom(
        metadata.discNumber!,
        metadata.totalDiscs ?? 0
      ));
    }

    // Cover art (COVR atom)
    if (metadata.albumArt != null) {
      atoms.add(_buildCovrAtom(metadata.albumArt!));
    }

    // Build ilst atom
    return _buildAtom('ilst', _concatenateBytes(atoms));
  }

  /// Write metadata to the given M4A/MP4 file bytes.
  ///
  /// This replaces the existing ILIST atom within the MOOV/UDTA/META hierarchy and returns a new
  /// Uint8List with the updated bytes.
  static Uint8List write(Uint8List bytes, AudioMetadata metadata) {
    final newIlst = buildIlst(metadata);

    // Find MOOV atom
    final moovInfo = _findAtomInfo(bytes, 'moov', 0);
    if (moovInfo == null) {
      throw FormatException('No moov atom found in MP4 file');
    }

    // Find UDTA within MOOV
    final udtaInfo = _findAtomInfo(bytes, 'udta', moovInfo.dataOffset);
    if (udtaInfo == null) {
      // No UTDA atom - need to create one with META and ILST
      return _insertUdtaAtom(bytes, moovInfo, newIlst);
    }

    // Find META within UDTA
    final metaInfo = _findAtomInfo(bytes, 'meta', udtaInfo.dataOffset);
    if (metaInfo == null) {
      // No META atom - need to create one with ilst
      return _insertMetaAtom(bytes, udtaInfo, newIlst);
    }

    // META atom has 4-byte version/flags header
    final metaDataOffset = metaInfo.dataOffset + 4;

    // Find ILIST within META
    final ilstInfo = _findAtomInfo(bytes, 'ilst', metaDataOffset);
    if (ilstInfo == null) {
      // No ILST atom - need to create one
      return _insertIlstAtom(bytes, metaInfo, newIlst);
    }

    // Replace existing ILST
    return _replaceAtom(bytes, ilstInfo, newIlst);
  }

  /// Remove metadata from the given M4A/MP4 file bytes.
  ///
  /// Removes the ILST atom while preserving file structure.
  static Uint8List strip(Uint8List bytes) {
    final moovInfo = _findAtomInfo(bytes, 'moov', 0);
    if (moovInfo == null) return bytes;

    final udtaInfo = _findAtomInfo(bytes, 'udta', moovInfo.dataOffset);
    if (udtaInfo == null) return bytes;

    final metaInfo = _findAtomInfo(bytes, 'meta', udtaInfo.dataOffset);
    if (metaInfo == null) return bytes;

    final metaDataOffset = metaInfo.dataOffset + 4;
    final ilstInfo = _findAtomInfo(bytes, 'ilst', metaDataOffset);
    if (ilstInfo == null) return bytes;

    // Remove ILST atom and update parent sizes
    return _removeAtom(bytes, ilstInfo, [moovInfo, udtaInfo, metaInfo]);
  }

  static void _addTextAtom(List<Uint8List> atoms, String type, String? value) {
    if (value == null || value.isEmpty) return;
    atoms.add(_buildTextAtom(type, value));
  }

  static Uint8List _buildTextAtom(String type, String value) {
    final textBytes = utf8.encode(value);

    // Data atom: 4 bytes size + 'data' + 4 bytes type (1=UTF-8) + 4 bytes locale + text
    final dataContent = BytesBuilder();
    dataContent.add(BinaryUtils.encodeUint32BE(1)); // Type indicator: 1 = UTF-8
    dataContent.add([0x00, 0x00, 0x00, 0x00]); // Locale (unused)
    dataContent.add(textBytes);

    final dataAtom = _buildAtom('data', dataContent.toBytes());

    // Outer atom: type + data atom
    return _buildAtom(type, dataAtom);
  }

  static Uint8List _buildTrknAtom(int track, int total) {
    // TRKN data format: 8 bytes header + 2 reserved + 2 track + 2 total + 2 reserved
    final dataContent = BytesBuilder();

    dataContent.add(BinaryUtils.encodeUint32BE(0)); // Type indicator: 0 = implicit
    dataContent.add([0x00, 0x00, 0x00, 0x00]); // Locale
    dataContent.add([0x00, 0x00]); // Reserved
    dataContent.add(BinaryUtils.encodeUint16BE(track));
    dataContent.add(BinaryUtils.encodeUint16BE(total));
    dataContent.add([0x00, 0x00]); // Reserved

    final dataAtom = _buildAtom('data', dataContent.toBytes());
    return _buildAtom('trkn', dataAtom);
  }

  static Uint8List _buildDiskAtom(int disc, int total) {
    // DISK data format: same as TRKN
    final dataContent = BytesBuilder();

    dataContent.add(BinaryUtils.encodeUint32BE(0)); // Type indicator: 0 = implicit
    dataContent.add([0x00, 0x00, 0x00, 0x00]); // Locale
    dataContent.add([0x00, 0x00]); // Reserved
    dataContent.add(BinaryUtils.encodeUint16BE(disc));
    dataContent.add(BinaryUtils.encodeUint16BE(total));
    dataContent.add([0x00, 0x00]); // Reserved

    final dataAtom = _buildAtom('data', dataContent.toBytes());
    return _buildAtom('disk', dataAtom);
  }

  static Uint8List _buildCovrAtom(AlbumArt albumArt) {
    // Determine type indicator based on MIME type
    int typeIndicator;
    if (albumArt.mimeType == 'image/png') {
      typeIndicator = 14; // PNG
    }
    else {
      typeIndicator = 13; // JPEG (default)
    }

    final dataContent = BytesBuilder();

    dataContent.add(BinaryUtils.encodeUint32BE(typeIndicator));
    dataContent.add([0x00, 0x00, 0x00, 0x00]); // Locale
    dataContent.add(albumArt.data);

    final dataAtom = _buildAtom('data', dataContent.toBytes());
    return _buildAtom('covr', dataAtom);
  }

  static Uint8List _buildAtom(String type, Uint8List content) {
    final builder = BytesBuilder();

    // Size (4 bytes): header (8) + content
    final size = 8 + content.length;
    builder.add(BinaryUtils.encodeUint32BE(size));

    // Type (4 bytes)
    builder.add(type.codeUnits.take(4).toList());

    // Content
    builder.add(content);

    return builder.toBytes();
  }

  static _AtomInfo? _findAtomInfo(Uint8List bytes, String type, int startOffset) {
    var offset = startOffset;

    while (offset + 8 <= bytes.length) {
      final size = _readUint32BE(bytes, offset);
      final atomType = String.fromCharCodes(bytes.sublist(offset + 4, offset + 8));

      if (size == 0) break;

      final actualSize = size == 1
          ? _readUint32BE(bytes, offset + 12) // Extended size (simplified)
          : size;

      if (atomType == type) {
        return _AtomInfo(
          offset: offset,
          size: actualSize,
          dataOffset: offset + 8
        );
      }

      offset += actualSize;
    }

    return null;
  }

  static Uint8List _replaceAtom(Uint8List bytes, _AtomInfo atomInfo, Uint8List newAtom) {
    final sizeDiff = newAtom.length - atomInfo.size;

    final result = BytesBuilder();

    // Copy before atom
    result.add(bytes.sublist(0, atomInfo.offset));

    // Insert new atom
    result.add(newAtom);

    // Copy after atom
    result.add(bytes.sublist(atomInfo.offset + atomInfo.size));

    // Update parent atom sizes
    final resultBytes = result.toBytes();
    _updateParentSizes(resultBytes, atomInfo.offset, sizeDiff);

    return resultBytes;
  }

  static Uint8List _insertUdtaAtom(Uint8List bytes, _AtomInfo moovInfo, Uint8List ilst) {
    // Build: META (with version) -> ILST
    final metaContent = BytesBuilder();
    metaContent.add([0x00, 0x00, 0x00, 0x00]); // Version/flags
    metaContent.add(ilst);
    final metaAtom = _buildAtom('meta', metaContent.toBytes());

    // Build: UDTA -> META
    final udtaAtom = _buildAtom('udta', metaAtom);

    // Insert at end of MOOV
    final insertOffset = moovInfo.offset + moovInfo.size;

    final result = BytesBuilder();
    result.add(bytes.sublist(0, insertOffset));
    result.add(udtaAtom);
    result.add(bytes.sublist(insertOffset));

    final resultBytes = result.toBytes();

    // Update MOOV size
    final newMoovSize = moovInfo.size + udtaAtom.length;
    _writeUint32BE(resultBytes, moovInfo.offset, newMoovSize);

    return resultBytes;
  }

  static Uint8List _insertMetaAtom(Uint8List bytes, _AtomInfo udtaInfo, Uint8List ilst) {
    // Build: META (with version) -> ILST
    final metaContent = BytesBuilder();
    metaContent.add([0x00, 0x00, 0x00, 0x00]); // Version/flags
    metaContent.add(ilst);
    final metaAtom = _buildAtom('meta', metaContent.toBytes());

    // Insert at end of UDTA
    final insertOffset = udtaInfo.offset + udtaInfo.size;

    final result = BytesBuilder();
    result.add(bytes.sublist(0, insertOffset));
    result.add(metaAtom);
    result.add(bytes.sublist(insertOffset));

    final resultBytes = result.toBytes();

    // Update UDTA and MOOV sizes
    _updateParentSizes(resultBytes, insertOffset, metaAtom.length);

    return resultBytes;
  }

  static Uint8List _insertIlstAtom(Uint8List bytes, _AtomInfo metaInfo, Uint8List ilst) {
    // Insert at end of META (after version/flags)
    final insertOffset = metaInfo.offset + metaInfo.size;

    final result = BytesBuilder();
    result.add(bytes.sublist(0, insertOffset));
    result.add(ilst);
    result.add(bytes.sublist(insertOffset));

    final resultBytes = result.toBytes();

    // Update META and parent sizes
    _updateParentSizes(resultBytes, insertOffset, ilst.length);

    return resultBytes;
  }

  static Uint8List _removeAtom(Uint8List bytes, _AtomInfo atomInfo, List<_AtomInfo> parents) {
    final result = BytesBuilder();

    // Copy before atom
    result.add(bytes.sublist(0, atomInfo.offset));

    // Copy after atom (skip the atom)
    result.add(bytes.sublist(atomInfo.offset + atomInfo.size));

    final resultBytes = result.toBytes();

    // Update parent sizes (subtract removed atom size)
    for (final parent in parents) {
      final currentSize = _readUint32BE(resultBytes, parent.offset);
      _writeUint32BE(resultBytes, parent.offset, currentSize - atomInfo.size);
    }

    return resultBytes;
  }

  static void _updateParentSizes(Uint8List bytes, int childOffset, int sizeDiff) {
    // Find and update MOOV atom size
    final moovInfo = _findAtomInfo(bytes, 'moov', 0);
    if (moovInfo != null && childOffset > moovInfo.offset && childOffset < moovInfo.offset + moovInfo.size + sizeDiff) {
      final newSize = _readUint32BE(bytes, moovInfo.offset) + sizeDiff;
      _writeUint32BE(bytes, moovInfo.offset, newSize);

      // Find and update UDTA
      final udtaInfo = _findAtomInfo(bytes, 'udta', moovInfo.dataOffset);
      if (udtaInfo != null && childOffset > udtaInfo.offset) {
        final newUdtaSize = _readUint32BE(bytes, udtaInfo.offset) + sizeDiff;
        _writeUint32BE(bytes, udtaInfo.offset, newUdtaSize);

        // Find and update META
        final metaInfo = _findAtomInfo(bytes, 'meta', udtaInfo.dataOffset);
        if (metaInfo != null && childOffset > metaInfo.offset) {
          final newMetaSize = _readUint32BE(bytes, metaInfo.offset) + sizeDiff;
          _writeUint32BE(bytes, metaInfo.offset, newMetaSize);
        }
      }
    }
  }

  static Uint8List _concatenateBytes(List<Uint8List> bytesList) {
    final builder = BytesBuilder();
    for (final bytes in bytesList) {
      builder.add(bytes);
    }
    return builder.toBytes();
  }

  static int _readUint32BE(Uint8List bytes, int offset) {
    return (bytes[offset] << 24) | (bytes[offset + 1] << 16) | (bytes[offset + 2] << 8) | bytes[offset + 3];
  }

  static void _writeUint32BE(Uint8List bytes, int offset, int value) {
    bytes[offset] = (value >> 24) & 0xFF;
    bytes[offset + 1] = (value >> 16) & 0xFF;
    bytes[offset + 2] = (value >> 8) & 0xFF;
    bytes[offset + 3] = value & 0xFF;
  }
}

class _AtomInfo {
  final int offset;
  final int size;
  final int dataOffset;

  _AtomInfo({
    required this.offset,
    required this.size,
    required this.dataOffset
  });
}
