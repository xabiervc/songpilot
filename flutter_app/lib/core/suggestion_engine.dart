/// Rule-based chord progression suggestion engine.
///
/// Dart port of songpilot/songpilot_core/suggestion_engine.py. Given a key,
/// style, and mood, suggests continuations with theory explanations.
/// Deterministic and rule-based (no ML) for predictable, testable behavior.
library suggestion_engine;

import 'music_theory.dart';

class ProgressionTemplate {
  final List<String> romans;
  final String mode;
  final String style;
  final String mood;
  final String explanation;

  const ProgressionTemplate({
    required this.romans,
    required this.mode,
    required this.style,
    required this.mood,
    required this.explanation,
  });
}

const List<ProgressionTemplate> progressionTemplates = [
  ProgressionTemplate(
    romans: ['IV', 'V', 'I'],
    mode: 'major',
    style: 'rock',
    mood: 'driving',
    explanation:
        'Classic rock cadence: subdominant to dominant resolves strongly into the tonic.',
  ),
  ProgressionTemplate(
    romans: ['vi', 'IV', 'I', 'V'],
    mode: 'major',
    style: 'pop',
    mood: 'uplifting',
    explanation:
        'Pop staple progression; the vi chord adds a touch of melancholy before resolving.',
  ),
  ProgressionTemplate(
    romans: ['I', 'bVII', 'IV'],
    mode: 'major',
    style: 'blues',
    mood: 'laidback',
    explanation:
        'The flat-VII is borrowed from the mixolydian mode, giving a bluesy, unresolved color.',
  ),
  ProgressionTemplate(
    romans: ['ii', 'V', 'I'],
    mode: 'major',
    style: 'jazz',
    mood: 'smooth',
    explanation:
        'The ii-V-I is the most common jazz cadence, creating strong forward motion to the tonic.',
  ),
  ProgressionTemplate(
    romans: ['i', 'VI', 'III', 'VII'],
    mode: 'minor',
    style: 'indie',
    mood: 'melancholic',
    explanation:
        'A minor-key loop popularized in alt-rock; it never fully resolves, keeping emotional tension.',
  ),
  ProgressionTemplate(
    romans: ['V', 'vi'],
    mode: 'major',
    style: 'pop',
    mood: 'bittersweet',
    explanation:
        'Deceptive cadence: expects resolution to I but lands on vi instead, creating surprise.',
  ),
];

const Map<String, int> romanToMajorDegree = {
  'I': 0, 'ii': 1, 'iii': 2, 'IV': 3, 'V': 4, 'vi': 5, 'vii': 6,
};
const Map<String, int> romanToMinorDegree = {
  'i': 0, 'ii': 1, 'III': 2, 'iv': 3, 'v': 4, 'VI': 5, 'VII': 6,
};

class NoSuggestionsError implements Exception {
  final String message;
  NoSuggestionsError(this.message);
  @override
  String toString() => 'NoSuggestionsError: $message';
}

class Suggestion {
  final List<String> chords;
  final String style;
  final String mood;
  final String explanation;

  Suggestion({
    required this.chords,
    required this.style,
    required this.mood,
    required this.explanation,
  });
}

String _romanToChord(String roman, String key, String templateMode) {
  if (roman == 'bVII') {
    final tonic = getScale(key, mode: templateMode)[0];
    final idx = noteNames.indexOf(tonic);
    return noteNames[(idx + 10) % 12];
  }

  final degreeMap =
      templateMode == 'major' ? romanToMajorDegree : romanToMinorDegree;
  if (!degreeMap.containsKey(roman)) {
    throw NoSuggestionsError(
        "Unsupported roman numeral '$roman' for mode '$templateMode'");
  }
  final degree = degreeMap[roman]!;
  final scale = getScale(key, mode: templateMode);
  return scale[degree];
}

/// Returns suggested continuations matching the requested style/mood.
/// Falls back to same-style, then same-mode, then any template, so the
/// caller always gets a usable result when templates exist.
List<Suggestion> suggestNext({
  required String key,
  required String style,
  required String mood,
  String mode = 'major',
  int limit = 5,
}) {
  if (key.trim().isEmpty) {
    throw ArgumentError('key must not be empty');
  }

  final exact = progressionTemplates
      .where((t) => t.style == style && t.mood == mood)
      .toList();
  final sameStyle =
      progressionTemplates.where((t) => t.style == style).toList();
  final sameMode =
      progressionTemplates.where((t) => t.mode == mode).toList();

  List<ProgressionTemplate> candidates;
  if (exact.isNotEmpty) {
    candidates = exact;
  } else if (sameStyle.isNotEmpty) {
    candidates = sameStyle;
  } else if (sameMode.isNotEmpty) {
    candidates = sameMode;
  } else {
    candidates = progressionTemplates;
  }

  final limited = candidates.take(limit).toList();

  final results = <Suggestion>[];
  for (final template in limited) {
    final chords = template.romans
        .map((r) => _romanToChord(r, key, template.mode))
        .toList();
    results.add(Suggestion(
      chords: chords,
      style: template.style,
      mood: template.mood,
      explanation: template.explanation,
    ));
  }

  if (results.isEmpty) {
    throw NoSuggestionsError('No suggestions available for the given parameters');
  }

  return results;
}

/// Returns a roman-numeral + plain-language explanation for a chord sequence.
List<String> explainProgression(List<String> chords, String key,
    {String mode = 'major'}) {
  if (chords.isEmpty) {
    throw ArgumentError('chords list must not be empty');
  }

  return chords.map((chord) {
    final roman = chordToRoman(chord, key, mode: mode);
    return '$chord -> $roman';
  }).toList();
}
