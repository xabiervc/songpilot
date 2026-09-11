/// Helpers for building chord palettes: diatonic triads of a key plus
/// common borrowed-color chords.
library chord_shapes;

import 'music_theory.dart';

/// Qualities (suffixes) for triads built on each degree of the major scale:
/// I, ii, iii, IV, V, vi, vii°.
const List<String> majorScaleTriadQualities = ['', 'm', 'm', '', '', 'm', 'dim'];

/// Diatonic triads of a major key, e.g. C -> [C, Dm, Em, F, G, Am, Bdim].
List<String> diatonicTriads(String key) {
  final scale = getScale(key, mode: 'major');
  return [
    for (var i = 0; i < scale.length; i++)
      '${scale[i]}${majorScaleTriadQualities[i]}',
  ];
}

/// The flat-VII chord root relative to a key (borrowed from mixolydian),
/// a common blues/rock color, e.g. in C the bVII is Bb (returned as A#).
String flatSevenChord(String key) {
  final root = normalizeNote(key);
  final idx = noteNames.indexOf(root);
  return noteNames[(idx + 10) % 12];
}

/// Full default palette for a key: diatonic triads plus borrowed bVII.
List<String> paletteChords(String key) => [
      ...diatonicTriads(key),
      flatSevenChord(key),
    ];
