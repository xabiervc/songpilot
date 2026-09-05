import 'package:test/test.dart';
import 'package:songpilot/core/music_theory.dart';

void main() {
  group('normalizeNote', () {
    test('sharp note unchanged', () {
      expect(normalizeNote('C#'), 'C#');
    });
    test('flat note converted to sharp equivalent', () {
      expect(normalizeNote('Db'), 'C#');
    });
    test('invalid note throws', () {
      expect(() => normalizeNote('H'), throwsA(isA<InvalidChordError>()));
    });
  });

  group('parseChord', () {
    test('simple major chord', () {
      final p = parseChord('C');
      expect(p.root, 'C');
      expect(p.quality, 'maj');
    });
    test('minor seventh chord', () {
      final p = parseChord('Am7');
      expect(p.root, 'A');
      expect(p.quality, 'm7');
    });
    test('maj7 with sharp root', () {
      final p = parseChord('A#maj7');
      expect(p.root, 'A#');
      expect(p.quality, 'maj7');
    });
    test('flat root normalized', () {
      final p = parseChord('Dbm');
      expect(p.root, 'C#');
      expect(p.quality, 'm');
    });
    test('lowercase letter accepted', () {
      final p = parseChord('c');
      expect(p.root, 'C');
    });
    test('empty string throws', () {
      expect(() => parseChord(''), throwsA(isA<InvalidChordError>()));
    });
    test('whitespace only throws', () {
      expect(() => parseChord('   '), throwsA(isA<InvalidChordError>()));
    });
    test('invalid letter throws', () {
      expect(() => parseChord('H7'), throwsA(isA<InvalidChordError>()));
    });
  });

  group('getScale', () {
    test('C major scale', () {
      expect(getScale('C', mode: 'major'), ['C', 'D', 'E', 'F', 'G', 'A', 'B']);
    });
    test('A minor scale', () {
      expect(getScale('A', mode: 'minor'), ['A', 'B', 'C', 'D', 'E', 'F', 'G']);
    });
    test('E major scale', () {
      expect(getScale('E', mode: 'major'),
          ['E', 'F#', 'G#', 'A', 'B', 'C#', 'D#']);
    });
    test('flat key normalized matches sharp equivalent', () {
      expect(getScale('Db', mode: 'major'), getScale('C#', mode: 'major'));
    });
  });

  group('chordToRoman', () {
    test('tonic chord', () {
      expect(chordToRoman('C', 'C', mode: 'major'), 'I');
    });
    test('dominant chord', () {
      expect(chordToRoman('G', 'C', mode: 'major'), 'V');
    });
    test('subdominant chord', () {
      expect(chordToRoman('F', 'C', mode: 'major'), 'IV');
    });
    test('relative minor chord', () {
      expect(chordToRoman('Am', 'C', mode: 'major'), 'vi');
    });
    test('borrowed chord outside key', () {
      expect(chordToRoman('Db', 'C', mode: 'major'), 'borrowed');
    });
    test('minor key tonic', () {
      expect(chordToRoman('Am', 'A', mode: 'minor'), 'i');
    });
  });

  group('detectKeyFromChords', () {
    test('simple C major progression', () {
      expect(detectKeyFromChords(['C', 'F', 'G', 'C']), 'C');
    });
    test('E major progression', () {
      expect(detectKeyFromChords(['E', 'A', 'B', 'E']), 'E');
    });
    test('empty list returns null', () {
      expect(detectKeyFromChords([]), isNull);
    });
    test('single chord returns a key', () {
      expect(detectKeyFromChords(['G']), isNotNull);
    });
    test('invalid chord in list throws', () {
      expect(() => detectKeyFromChords(['C', 'H7']),
          throwsA(isA<InvalidChordError>()));
    });
  });
}
