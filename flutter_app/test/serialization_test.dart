import 'package:test/test.dart';
import 'package:songpilot/models/models.dart';

void main() {
  group('UserProfile JSON', () {
    test('round trip preserves fields', () {
      final profile = UserProfile(
        userId: 'u1',
        username: 'xabi',
        email: 'x@example.com',
        skillLevel: SkillLevel.advanced,
        instruments: ['guitar', 'bass'],
        genres: ['rock'],
        favouriteArtists: ['RHCP'],
        openToCollab: true,
        lookingFor: ['vocalist'],
        isPro: true,
      );
      final restored = UserProfile.fromJson(profile.toJson());
      expect(restored.userId, 'u1');
      expect(restored.username, 'xabi');
      expect(restored.skillLevel, SkillLevel.advanced);
      expect(restored.instruments, ['guitar', 'bass']);
      expect(restored.genres, ['rock']);
      expect(restored.openToCollab, isTrue);
      expect(restored.lookingFor, ['vocalist']);
      expect(restored.isPro, isTrue);
    });

    test('defaults applied when fields are missing', () {
      final restored = UserProfile.fromJson(const {
        'id': 'u9',
        'username': 'jo',
        'email': 'j@e.com',
      });
      expect(restored.skillLevel, SkillLevel.intermediate);
      expect(restored.openToCollab, isFalse);
      expect(restored.genres, isEmpty);
      expect(restored.isPro, isFalse);
    });

    test('skill_level string maps back to enum', () {
      final restored = UserProfile.fromJson(const {
        'id': 'u1',
        'username': 'a',
        'email': 'a@b.co',
        'skill_level': 'beginner',
      });
      expect(restored.skillLevel, SkillLevel.beginner);
    });
  });

  group('SongProject JSON', () {
    test('round trip with collab_open visibility', () {
      final project = SongProject(
        projectId: 'p1',
        ownerId: 'u1',
        title: 'Song',
        visibility: Visibility.collabOpen,
      );
      final json = project.toJson();
      expect(json['visibility'], 'collab_open');
      final restored = SongProject.fromJson(json);
      expect(restored.visibility, Visibility.collabOpen);
      expect(restored.title, 'Song');
      expect(restored.projectId, 'p1');
      expect(restored.tempo, 120);
    });

    test('private visibility maps to snake-case string', () {
      final json = SongProject(projectId: 'p', ownerId: 'u', title: 'T')
          .toJson();
      expect(json['visibility'], 'private');
      expect(SongProject.fromJson(json).visibility, Visibility.private_);
      expect(SongProject.fromJson(json).style, 'rock');
      expect(SongProject.fromJson(json).mood, 'driving');
    });

    test('numeric tempo from DB num type parses', () {
      final restored = SongProject.fromJson(const {
        'id': 'p1',
        'owner_id': 'u1',
        'title': 'T',
        'tempo': 98.0,
      });
      expect(restored.tempo, 98);
    });
  });

  group('SongSection JSON', () {
    test('toJson carries song id and position; fromJson restores content', () {
      final section = SongSection(
        sectionType: SectionType.preChorus,
        key: 'E',
        chords: ['E', 'A'],
        barCount: 8,
      );
      final json = section.toJson('song-1', 3);
      expect(json['song_id'], 'song-1');
      expect(json['position'], 3);
      expect(json['section_type'], 'pre_chorus');

      final restored = SongSection.fromJson(json);
      expect(restored.sectionType, SectionType.preChorus);
      expect(restored.chords, ['E', 'A']);
      expect(restored.barCount, 8);
      expect(restored.key, 'E');
    });

    test('unknown section type falls back to custom', () {
      final restored = SongSection.fromJson(const {
        'section_type': 'something_new',
        'key': 'C',
        'chords': ['C'],
        'bar_count': 4,
      });
      expect(restored.sectionType, SectionType.custom);
    });
  });

  group('CollaborationRequest JSON', () {
    test('round trip', () {
      final req = CollaborationRequest(
        requestId: 'r1',
        fromUserId: 'u1',
        toUserId: 'u2',
        projectId: 'p1',
        message: 'hi',
      );
      final restored = CollaborationRequest.fromJson(req.toJson());
      expect(restored.status, 'pending');
      expect(restored.projectId, 'p1');
      expect(restored.message, 'hi');
      expect(restored.fromUserId, 'u1');
    });

    test('status survives acceptance round trip', () {
      final req = CollaborationRequest(
        requestId: 'r1',
        fromUserId: 'u1',
        toUserId: 'u2',
        projectId: 'p1',
      )..accept();
      final restored = CollaborationRequest.fromJson(req.toJson());
      expect(restored.status, 'accepted');
    });
  });
}
