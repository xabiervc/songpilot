import 'package:test/test.dart';
import 'package:songpilot/core/song_form.dart';
import 'package:songpilot/models/models.dart';

void main() {
  group('nextSectionAfter', () {
    test('conventional pop-song ordering', () {
      expect(nextSectionAfter(SectionType.intro), SectionType.verse);
      expect(nextSectionAfter(SectionType.verse), SectionType.preChorus);
      expect(nextSectionAfter(SectionType.preChorus), SectionType.chorus);
      expect(nextSectionAfter(SectionType.chorus), SectionType.bridge);
      expect(nextSectionAfter(SectionType.bridge), SectionType.chorus);
    });

    test('stable outro and fallback for custom', () {
      expect(nextSectionAfter(SectionType.outro), SectionType.outro);
      expect(nextSectionAfter(SectionType.custom), SectionType.verse);
    });
  });

  group('sectionTypeLabels', () {
    test('covers every enum value', () {
      for (final type in SectionType.values) {
        expect(sectionTypeLabels, contains(type));
      }
    });

    test('labels are non-empty', () {
      for (final label in sectionTypeLabels.values) {
        expect(label, isNotEmpty);
      }
    });
  });
}
