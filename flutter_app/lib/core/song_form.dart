/// Song-form helpers used by the editor UI.
library song_form;

import '../models/models.dart';

/// Conventional popular-song section ordering heuristic.
/// Returns the section type that typically follows `after`.
SectionType nextSectionAfter(SectionType after) => switch (after) {
      SectionType.intro => SectionType.verse,
      SectionType.verse => SectionType.preChorus,
      SectionType.preChorus => SectionType.chorus,
      SectionType.chorus => SectionType.bridge,
      SectionType.bridge => SectionType.chorus,
      SectionType.outro => SectionType.outro,
      SectionType.custom => SectionType.verse,
    };

/// Human-readable labels for section types.
const Map<SectionType, String> sectionTypeLabels = {
  SectionType.intro: 'Intro',
  SectionType.verse: 'Verse',
  SectionType.preChorus: 'Pre-chorus',
  SectionType.chorus: 'Chorus',
  SectionType.bridge: 'Bridge',
  SectionType.outro: 'Outro',
  SectionType.custom: 'Custom',
};
