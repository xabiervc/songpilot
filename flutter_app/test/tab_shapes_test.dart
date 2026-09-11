import 'package:test/test.dart';
import 'package:songpilot/core/tab_shapes.dart';

void main() {
  group('voicingFor', () {
    test('plain major and minor chords resolve', () {
      expect(voicingFor('C'), isNotNull);
      expect(voicingFor('Am'), isNotNull);
      expect(voicingFor('G7'), isNotNull);
    });

    test('implicit maj quality normalizes', () {
      expect(voicingFor('C')?.length, 6);
    });

    test('flat roots are normalized to sharps', () {
      // Bb == A# in our table
      expect(voicingFor('Bb'), isNotNull);
      expect(voicingFor('A#'), equals(voicingFor('Bb')));
    });

    test('palette chords for C and E keys are covered', () {
      for (final c in const [
        'C', 'Dm', 'Em', 'F', 'G', 'Am', 'Bdim',
        'E', 'F#m', 'G#m', 'A', 'B', 'C#m', 'D#dim',
      ]) {
        expect(voicingFor(c), isNotNull, reason: 'missing voicing for $c');
      }
    });

    test('unknown chord returns null', () {
      expect(voicingFor('Cmaj13#11'), isNull);
    });
  });

  group('renderChordDiagram', () {
    test('C major diagram is the standard open voicing', () {
      final diagram = renderChordDiagram('C', const [-1, 3, 2, 0, 1, 0]);
      final lines = diagram.split('\n');
      expect(lines.length, 7); // name + 6 strings
      expect(lines[0], 'C');
      expect(lines[1], 'e|--0--|');
      expect(lines[2], 'B|--1--|');
      expect(lines[6], 'E|--x--|');
    });
  });

  group('tabsForProgression', () {
    test('generates blocks per chord', () {
      final tabs = tabsForProgression(const ['C', 'Am']);
      expect(tabs, contains('C\ne|--0--|'));
      expect(tabs, contains('Am\ne|--0--|'));
    });

    test('unknown chords get an explicit placeholder line', () {
      final tabs = tabsForProgression(const ['Cqnoexist']);
      expect(tabs, contains('no standard voicing'));
    });

    test('empty input produces empty output', () {
      expect(tabsForProgression(const []), '');
    });
  });
}
