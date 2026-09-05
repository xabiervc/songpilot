import 'package:test/test.dart';
import 'package:songpilot/models/models.dart';

void main() {
  group('UserProfile', () {
    test('valid profile has correct defaults', () {
      final p = UserProfile(userId: 'u1', username: 'xabi', email: 'x@example.com');
      expect(p.skillLevel, SkillLevel.intermediate);
      expect(p.openToCollab, isFalse);
      expect(p.isPro, isFalse);
    });

    test('empty username throws', () {
      expect(
          () => UserProfile(userId: 'u1', username: '   ', email: 'x@example.com'),
          throwsArgumentError);
    });

    test('invalid email throws', () {
      expect(
          () => UserProfile(userId: 'u1', username: 'xabi', email: 'not-an-email'),
          throwsArgumentError);
    });
  });

  group('SongSection', () {
    test('valid section', () {
      final s = SongSection(
          sectionType: SectionType.verse, key: 'E', chords: ['E', 'A'], barCount: 4);
      expect(s.barCount, 4);
    });

    test('zero bar count throws', () {
      expect(
          () => SongSection(sectionType: SectionType.verse, key: 'E', barCount: 0),
          throwsArgumentError);
    });

    test('negative bar count throws', () {
      expect(
          () => SongSection(sectionType: SectionType.chorus, key: 'E', barCount: -2),
          throwsArgumentError);
    });
  });

  group('SongProject', () {
    test('valid project defaults', () {
      final proj = SongProject(projectId: 'p1', ownerId: 'u1', title: 'My Song');
      expect(proj.key, 'C');
      expect(proj.tempo, 120);
      expect(proj.visibility, Visibility.private_);
    });

    test('empty title throws', () {
      expect(() => SongProject(projectId: 'p1', ownerId: 'u1', title: ''),
          throwsArgumentError);
    });

    test('tempo zero throws', () {
      expect(
          () => SongProject(projectId: 'p1', ownerId: 'u1', title: 'Song', tempo: 0),
          throwsArgumentError);
    });

    test('tempo too high throws', () {
      expect(
          () =>
              SongProject(projectId: 'p1', ownerId: 'u1', title: 'Song', tempo: 500),
          throwsArgumentError);
    });

    test('add section and total bars', () {
      final proj = SongProject(projectId: 'p1', ownerId: 'u1', title: 'Song');
      proj.addSection(SongSection(sectionType: SectionType.verse, key: 'C', barCount: 8));
      proj.addSection(SongSection(sectionType: SectionType.chorus, key: 'C', barCount: 4));
      expect(proj.totalBars(), 12);
      expect(proj.sections.length, 2);
    });

    test('total bars of empty project is zero', () {
      final proj = SongProject(projectId: 'p1', ownerId: 'u1', title: 'Song');
      expect(proj.totalBars(), 0);
    });
  });

  group('CollaborationRequest', () {
    test('default status is pending', () {
      final req = CollaborationRequest(
          requestId: 'r1', fromUserId: 'u1', toUserId: 'u2', projectId: 'p1');
      expect(req.status, 'pending');
    });

    test('accept changes status', () {
      final req = CollaborationRequest(
          requestId: 'r1', fromUserId: 'u1', toUserId: 'u2', projectId: 'p1');
      req.accept();
      expect(req.status, 'accepted');
    });

    test('decline changes status', () {
      final req = CollaborationRequest(
          requestId: 'r1', fromUserId: 'u1', toUserId: 'u2', projectId: 'p1');
      req.decline();
      expect(req.status, 'declined');
    });
  });
}
