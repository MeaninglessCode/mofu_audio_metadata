import 'dart:typed_data';

import 'package:mofu_audio_metadata/src/models/audio_metadata.dart';
import 'package:mofu_audio_metadata/src/models/parse_options.dart';
import 'package:mofu_audio_metadata/src/parsers/metadata_parser.dart';
import 'package:mofu_audio_metadata/src/formats/mp4/mp4_atom_parser.dart';

/// Parser for M4A/MP4 audio files (AAC in MP4 container)
class M4aParser implements MetadataParser {
  static const _ftypSignature = [0x66, 0x74, 0x79, 0x70]; // "ftyp"

  /// Returns true if the given bytes are a valid M4A AAC format, false otherwise.
  @override
  bool canParse(Uint8List bytes) {
    if (bytes.length < 12) return false;

    // Check for ftyp atom at offset 4
    if (!_hasSignature(bytes, 4, _ftypSignature)) return false;

    // Check for M4A/MP4 compatible brands
    final brand = String.fromCharCodes(bytes.sublist(8, 12));
    return brand == 'M4A ' || brand == 'M4B ' || brand == 'mp42' || brand == 'isom' || brand == 'iso2';
  }

  /// Parse byte array and return AudioMetadata if the format is supported.
  /// 
  /// Options are set using the [ParseOptions] parameter, defaulting to [ParseOptions.all].
  @override
  AudioMetadata parse(Uint8List bytes, [ParseOptions options = ParseOptions.all]) {
    if (!canParse(bytes)) {
      throw FormatException('Invalid M4A/MP4 file');
    }

    // Extract metadata using Mp4AtomParser
    final atoms = Mp4AtomParser.extractMetadata(bytes, options);

    // Extract album art
    final albumArt = options.includeAlbumArt ? Mp4AtomParser.extractAlbumArt(atoms) : null;

    return _buildMetadata(atoms, albumArt);
  }

  AudioMetadata _buildMetadata(Map<String, dynamic> atoms, AlbumArt? albumArt) {
    String? getString(String key) {
      final value = atoms[key];
      return value is String ? value : null;
    }

    // Parse track number and disc number using Mp4AtomParser
    final trackInfo = Mp4AtomParser.parseTrackNumber(atoms);
    final discInfo = Mp4AtomParser.parseDiscNumber(atoms);

    // Parse genre
    final genre = Mp4AtomParser.parseGenre(atoms);

    // Convert atom names to raw tags
    final rawTags = <String, List<String>>{};

    atoms.forEach((key, value) {
      if (value != null && value is! Map) {
        rawTags[key] = [value.toString()];
      }
    });

    return AudioMetadata(
      title: getString('\u00a9nam'),
      artist: getString('\u00a9ART'),
      album: getString('\u00a9alb'),
      albumArtist: getString('aART'),
      date: getString('\u00a9day'),
      trackNumber: trackInfo.trackNumber,
      totalTracks: trackInfo.totalTracks,
      discNumber: discInfo.discNumber,
      totalDiscs: discInfo.totalDiscs,
      genre: genre,
      comment: getString('\u00a9cmt'),
      composer: getString('\u00a9wrt'),
      publisher: getString('\u00a9pub'),
      lyrics: getString('\u00a9lyr'),
      albumArt: albumArt,
      rawTags: rawTags
    );
  }

  bool _hasSignature(Uint8List bytes, int offset, List<int> signature) {
    if (offset + signature.length > bytes.length) return false;

    for (var i = 0; i < signature.length; i++) {
      if (bytes[offset + i] != signature[i]) return false;
    }

    return true;
  }
}
