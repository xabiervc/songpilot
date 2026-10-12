import 'package:flutter_test/flutter_test.dart';

import '../lib/models/models.dart';

void main() {
  group('release data export model basics', () {
    test('profile JSON round-trips core fields', () {
      final profile = UserProfile(
        userId: 'user-1', username: 'writer', email: 'writer@example.test',
        instruments: ['guitar'], genres: ['indie'], openToCollab: true,
      );
      final restored = UserProfile.fromJson(profile.toJson());
      expect(restored.userId, 'user-1');
      expect(restored.instruments, ['guitar']);
      expect(restored.openToCollab, isTrue);
    });

    test('song project retains section data for JSON export', () {
      final project = SongProject(
        projectId: 'song-1', ownerId: 'user-1', title: 'Demo',
        sections: [SongSection(sectionType: SectionType.verse, key: 'C', chords: ['C', 'G'], tabs: 'e|--0--|')],
      );
      expect(project.sections.single.tabs, 'e|--0--|');
      expect(project.sections.single.chords, ['C', 'G']);
    });
  });
}
