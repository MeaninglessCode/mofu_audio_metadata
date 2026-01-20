import 'dart:typed_data';

/// Utility functions for parsing and extracting tag values
class TagUtils {
  /// Get the first matching value from a map of tag frames
  ///
  /// Searches through the list of frame IDs and returns the first non-empty value found.
  /// Used for ID3v2 tags where multiple frame IDs can represent the same field.
  static String? getFirstMatchingValue(
    Map<String, List<String>> frames,
    List<String> frameIds
  ) {
    for (final id in frameIds) {
      final values = frames[id];

      if (values != null && values.isNotEmpty) {
        return values.first;
      }
    }

    return null;
  }

  /// Get the first value for a key, case-insensitive
  ///
  /// Used for Vorbis Comments where keys are case-insensitive.
  static String? getFirstValue(Map<String, List<String>> tags, String key) {
    final values = tags[key.toUpperCase()];
    return (values != null && values.isNotEmpty) ? values.first : null;
  }

  /// Parse track or disc number in "N" or "N/Total" format
  ///
  /// Returns a tuple of (number, total) where either can be null.
  /// Example: "3/12" returns (3, 12), "5" returns (5, null)
  static (int?, int?) parseNumberSlashTotal(String? value) {
    if (value == null) return (null, null);

    final parts = value.split('/');
    final number = int.tryParse(parts[0]);
    final total = parts.length > 1 ? int.tryParse(parts[1]) : null;

    return (number, total);
  }

  /// Check if bytes match a signature at a specific offset
  static bool matchesSignature(
    Uint8List bytes,
    int offset,
    List<int> signature
  ) {
    if (offset + signature.length > bytes.length) return false;

    for (var i = 0; i < signature.length; i++) {
      if (bytes[offset + i] != signature[i]) return false;
    }

    return true;
  }
}

/// Registry of ID3v1 genre names
class GenreRegistry {
  static const _genres = [
    'Blues',
    'Classic Rock',
    'Country',
    'Dance',
    'Disco',
    'Funk',
    'Grunge',
    'Hip-Hop',
    'Jazz',
    'Metal',
    'New Age',
    'Oldies',
    'Other',
    'Pop',
    'R&B',
    'Rap',
    'Reggae',
    'Rock',
    'Techno',
    'Industrial',
    'Alternative',
    'Ska',
    'Death Metal',
    'Pranks',
    'Soundtrack',
    'Euro-Techno',
    'Ambient',
    'Trip-Hop',
    'Vocal',
    'Jazz+Funk',
    'Fusion',
    'Trance',
    'Classical',
    'Instrumental',
    'Acid',
    'House',
    'Game',
    'Sound Clip',
    'Gospel',
    'Noise',
    'AlternRock',
    'Bass',
    'Soul',
    'Punk',
    'Space',
    'Meditative',
    'Instrumental Pop',
    'Instrumental Rock',
    'Ethnic',
    'Gothic',
    'Darkwave',
    'Techno-Industrial',
    'Electronic',
    'Pop-Folk',
    'Eurodance',
    'Dream',
    'Southern Rock',
    'Comedy',
    'Cult',
    'Gangsta',
    'Top 40',
    'Christian Rap',
    'Pop/Funk',
    'Jungle',
    'Native American',
    'Cabaret',
    'New Wave',
    'Psychadelic',
    'Rave',
    'Showtunes',
    'Trailer',
    'Lo-Fi',
    'Tribal',
    'Acid Punk',
    'Acid Jazz',
    'Polka',
    'Retro',
    'Musical',
    'Rock & Roll',
    'Hard Rock'
  ];

  /// Get genre name from ID3v1 genre ID
  static String? getGenreName(int genreId) {
    if (genreId >= 0 && genreId < _genres.length) {
      return _genres[genreId];
    }

    return null;
  }
}
