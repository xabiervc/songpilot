import 'package:test/test.dart';
import 'package:songpilot/core/chord_shapes.dart';

void main() {
  group('diatonicTriads', () {
    test('C major', () {
      expect(diatonicTriads('C'), ['C', 'Dm', 'Em', 'F', 'G', 'Am', 'Bdim']);
    });

    test('E major', () {
      expect(diatonicTriads('E'),
          ['E', 'F#m', 'G#m', 'A', 'B', 'C#m', 'D#dim']);
    });

    test('flat key input is normalized to sharps', () {
      expect(diatonicTriads('Bb'), diatonicTriads('A#'));
    });
  });

  group('flatSevenChord', () {
    test('in C, bVII is Bb (rendered A#)', () {
      expect(flatSevenChord('C'), 'A#');
    });

    test('in E, bVII is D', () {
      expect(flatSevenChord('E'), 'D');
    });

    test('in A, bVII is G', () {
      expect(flatSevenChord('A'), 'G');
    });
  });

  group('paletteChords', () {
    test('returns 7 diatonic triads plus the borrowed bVII', () {
      final palette = paletteChords('C');
      expect(palette.length, 8);
      expect(palette.last, 'A#');
      expect(palette.first, 'C');
    });
  });
}
