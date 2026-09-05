import 'package:test/test.dart';
import 'package:songpilot/core/suggestion_engine.dart';

void main() {
  group('suggestNext', () {
    test('exact style+mood match: rock driving', () {
      final results = suggestNext(key: 'C', style: 'rock', mood: 'driving');
      expect(results.length, greaterThanOrEqualTo(1));
      expect(results.first.style, 'rock');
      expect(results.first.mood, 'driving');
      expect(results.first.explanation.toLowerCase(), contains('cadence'));
    });

    test('blues laidback progression', () {
      final results = suggestNext(key: 'A', style: 'blues', mood: 'laidback');
      expect(results.any((r) => r.style == 'blues'), isTrue);
    });

    test('falls back to same style, different mood', () {
      final results = suggestNext(key: 'C', style: 'pop', mood: 'aggressive');
      expect(results.every((r) => r.style == 'pop'), isTrue);
    });

    test('falls back to any template for unknown style', () {
      final results =
          suggestNext(key: 'C', style: 'unknown-style', mood: 'unknown-mood');
      expect(results.length, greaterThanOrEqualTo(1));
    });

    test('empty key throws', () {
      expect(() => suggestNext(key: '', style: 'rock', mood: 'driving'),
          throwsArgumentError);
    });

    test('limit is respected', () {
      final results =
          suggestNext(key: 'C', style: 'unknown', mood: 'unknown', limit: 2);
      expect(results.length, lessThanOrEqualTo(2));
    });

    test('chords generated for each suggestion', () {
      final results = suggestNext(key: 'G', style: 'jazz', mood: 'smooth');
      for (final r in results) {
        expect(r.chords, isNotEmpty);
      }
    });

    test('minor mode suggestion', () {
      final results = suggestNext(
          key: 'A', style: 'indie', mood: 'melancholic', mode: 'minor');
      expect(results.any((r) => r.style == 'indie'), isTrue);
      for (final r in results) {
        expect(r.chords, isNotEmpty);
      }
    });
  });

  group('explainProgression', () {
    test('explains a simple progression', () {
      final explanations = explainProgression(['C', 'F', 'G'], 'C');
      expect(explanations.length, 3);
      expect(explanations[0], contains('I'));
      expect(explanations[1], contains('IV'));
      expect(explanations[2], contains('V'));
    });

    test('empty chords throws', () {
      expect(() => explainProgression([], 'C'), throwsArgumentError);
    });

    test('borrowed chord labelled', () {
      final explanations = explainProgression(['Db'], 'C');
      expect(explanations[0], contains('borrowed'));
    });
  });
}
