/// Music theory utilities: chord parsing, key/scale handling, roman numerals.
///
/// This is a Dart port of the verified Python reference implementation in
/// songpilot/songpilot_core/music_theory.py. Logic mirrors that module
/// exactly so behavior stays consistent between the two.
library music_theory;

const List<String> noteNames = [
  'C', 'C#', 'D', 'D#', 'E', 'F', 'F#', 'G', 'G#', 'A', 'A#', 'B'
];

const Map<String, String> enharmonic = {
  'Db': 'C#', 'Eb': 'D#', 'Gb': 'F#', 'Ab': 'G#', 'Bb': 'A#',
};

const List<int> majorScaleSteps = [0, 2, 4, 5, 7, 9, 11];
const List<int> minorScaleSteps = [0, 2, 3, 5, 7, 8, 10];

const List<String> romanMajor = ['I', 'ii', 'iii', 'IV', 'V', 'vi', 'vii'];
const List<String> romanMinor = ['i', 'ii', 'III', 'iv', 'v', 'VI', 'VII'];

class InvalidChordError implements Exception {
  final String message;
  InvalidChordError(this.message);
  @override
  String toString() => 'InvalidChordError: $message';
}

class ChordParts {
  final String root;
  final String quality;
  ChordParts(this.root, this.quality);
}

String normalizeNote(String note) {
  final trimmed = note.trim();
  if (enharmonic.containsKey(trimmed)) {
    return enharmonic[trimmed]!;
  }
  if (!noteNames.contains(trimmed)) {
    throw InvalidChordError('Unknown note: $trimmed');
  }
  return trimmed;
}

final RegExp _chordPattern = RegExp(r'^([A-Ga-g])(#|b)?(.*)$');

ChordParts parseChord(String chord) {
  if (chord.trim().isEmpty) {
    throw InvalidChordError('Empty chord string');
  }

  final trimmed = chord.trim();
  final match = _chordPattern.firstMatch(trimmed);
  if (match == null) {
    throw InvalidChordError('Cannot parse chord: $trimmed');
  }

  final letter = match.group(1)!;
  final accidental = match.group(2) ?? '';
  String quality = match.group(3) ?? '';

  final root = normalizeNote(letter.toUpperCase() + accidental);
  if (quality.isEmpty) {
    quality = 'maj';
  }
  return ChordParts(root, quality);
}

List<String> getScale(String key, {String mode = 'major'}) {
  final root = normalizeNote(key);
  final rootIndex = noteNames.indexOf(root);
  final steps = mode == 'major' ? majorScaleSteps : minorScaleSteps;
  return steps.map((step) => noteNames[(rootIndex + step) % 12]).toList();
}

String chordToRoman(String chord, String key, {String mode = 'major'}) {
  final parts = parseChord(chord);
  final scale = getScale(key, mode: mode);
  if (!scale.contains(parts.root)) {
    return 'borrowed';
  }
  final degree = scale.indexOf(parts.root);
  final romanSet = mode == 'major' ? romanMajor : romanMinor;
  return romanSet[degree];
}

/// Heuristic key detection: score each candidate major key by how many
/// chord roots fit its scale, with extra weight for tonic matches.
/// Returns null for empty input. Throws InvalidChordError for malformed chords.
String? detectKeyFromChords(List<String> chords) {
  if (chords.isEmpty) return null;

  final roots = chords.map((c) => parseChord(c).root).toList();

  String? bestKey;
  int bestScore = -1;
  for (final candidate in noteNames) {
    final scale = getScale(candidate, mode: 'major');
    int score = 0;
    for (final r in roots) {
      if (r == candidate) {
        score += 2;
      } else if (scale.contains(r)) {
        score += 1;
      }
    }
    if (score > bestScore) {
      bestScore = score;
      bestKey = candidate;
    }
  }
  return bestKey;
}
