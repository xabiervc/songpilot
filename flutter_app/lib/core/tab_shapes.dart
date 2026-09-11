/// Guitar chord voicings and text-diagram rendering for the tabs editor.
///
/// Fret lists are indexed low-E string first (E A D G B e); -1 means muted.
library tab_shapes;

import 'music_theory.dart';

/// Standard open-position / common barre voicings, low-E string first.
const Map<String, List<int>> openChordVoicings = {
  'C': [-1, 3, 2, 0, 1, 0],
  'Cmaj7': [-1, 3, 2, 0, 0, 0],
  'Cm': [-1, 3, 5, 5, 4, 3],
  'D': [-1, -1, 0, 2, 3, 2],
  'Dm': [-1, -1, 0, 2, 3, 1],
  'Dm7': [-1, -1, 0, 2, 1, 1],
  'D7': [-1, -1, 0, 2, 1, 2],
  'E': [0, 2, 2, 1, 0, 0],
  'Em': [0, 2, 2, 0, 0, 0],
  'Em7': [0, 2, 0, 0, 0, 0],
  'E7': [0, 2, 0, 1, 0, 0],
  'F': [1, 3, 3, 2, 1, 1],
  'Fm': [1, 3, 3, 1, 1, 1],
  'Fmaj7': [-1, -1, 3, 2, 1, 0],
  'F#': [2, 4, 4, 3, 2, 2],
  'F#m': [2, 4, 4, 2, 2, 2],
  'G': [3, 2, 0, 0, 0, 3],
  'Gm': [3, 5, 5, 3, 3, 3],
  'G7': [3, 2, 0, 0, 0, 1],
  'A': [-1, 0, 2, 2, 2, 0],
  'Am': [-1, 0, 2, 2, 1, 0],
  'Am7': [-1, 0, 2, 0, 1, 0],
  'A7': [-1, 0, 2, 0, 2, 0],
  'A#': [-1, 1, 3, 3, 3, 1],
  'B': [-1, 2, 4, 4, 4, 2],
  'Bm': [-1, 2, 4, 4, 3, 2],
  'B7': [-1, 2, 1, 2, 0, 2],
  'Bdim': [-1, 2, 3, 4, 3, -1],
  'C#m': [-1, 4, 6, 6, 5, 4],
  'G#m': [4, 6, 6, 4, 4, 4],
  'D#dim': [-1, 6, 7, 8, 7, -1],
};

/// Looks up a voicing by chord name, normalizing flats and the implicit
/// 'maj' quality. Returns null when no standard voicing is known.
List<int>? voicingFor(String chord) {
  final parts = parseChord(chord);
  final quality = parts.quality;
  final key = (quality.isEmpty || quality == 'maj')
      ? parts.root
      : '${parts.root}$quality';
  return openChordVoicings[key];
}

String _fretLabel(int fret) => fret < 0 ? 'x' : '$fret';

/// Renders a classic 6-line chord diagram, high-e string on top.
String renderChordDiagram(String chordName, List<int> frets) {
  const stringNames = ['e', 'B', 'G', 'D', 'A', 'E'];
  final lines = <String>[
    for (var s = 0; s < 6; s++)
      '${stringNames[s]}|--${_fretLabel(frets[5 - s])}--|',
  ];
  return '$chordName\n${lines.join('\n')}';
}

/// Builds stacked diagrams for a chord sequence; chords without a known
/// voicing get an explicit placeholder block instead of failing silently.
String tabsForProgression(List<String> chords) {
  final buffer = StringBuffer();
  for (final chord in chords) {
    final voicing = voicingFor(chord);
    if (voicing == null) {
      buffer.writeln('$chord\n(no standard voicing in table)\n');
    } else {
      buffer.writeln('${renderChordDiagram(chord, voicing)}\n');
    }
  }
  return buffer.toString().trimRight();
}
