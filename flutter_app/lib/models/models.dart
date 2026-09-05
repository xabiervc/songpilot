/// Core data models for SongPilot.
/// Dart port of songpilot/songpilot_core/models.py.
library models;

enum SkillLevel { beginner, intermediate, advanced }

enum Visibility { private_, public_, collabOpen }

enum SectionType { intro, verse, preChorus, chorus, bridge, outro, custom }

class UserProfile {
  final String userId;
  final String username;
  final String email;
  final SkillLevel skillLevel;
  final List<String> instruments;
  final List<String> genres;
  final List<String> favouriteArtists;
  final bool openToCollab;
  final List<String> lookingFor;
  final bool isPro;

  UserProfile({
    required this.userId,
    required this.username,
    required this.email,
    this.skillLevel = SkillLevel.intermediate,
    List<String>? instruments,
    List<String>? genres,
    List<String>? favouriteArtists,
    this.openToCollab = false,
    List<String>? lookingFor,
    this.isPro = false,
  })  : instruments = instruments ?? [],
        genres = genres ?? [],
        favouriteArtists = favouriteArtists ?? [],
        lookingFor = lookingFor ?? [] {
    if (username.trim().isEmpty) {
      throw ArgumentError('username cannot be empty');
    }
    if (!email.contains('@')) {
      throw ArgumentError('email must be valid');
    }
  }
}

class SongSection {
  final SectionType sectionType;
  final String key;
  final List<String> chords;
  final int barCount;

  SongSection({
    required this.sectionType,
    required this.key,
    List<String>? chords,
    this.barCount = 4,
  }) : chords = chords ?? [] {
    if (barCount <= 0) {
      throw ArgumentError('barCount must be positive');
    }
  }
}

class SongProject {
  final String projectId;
  final String ownerId;
  final String title;
  final String key;
  final int tempo;
  final String style;
  final String mood;
  final String instrument;
  final Visibility visibility;
  final List<SongSection> sections;
  final DateTime createdAt;

  SongProject({
    required this.projectId,
    required this.ownerId,
    required this.title,
    this.key = 'C',
    this.tempo = 120,
    this.style = 'rock',
    this.mood = 'driving',
    this.instrument = 'guitar',
    this.visibility = Visibility.private_,
    List<SongSection>? sections,
    DateTime? createdAt,
  })  : sections = sections ?? [],
        createdAt = createdAt ?? DateTime.now().toUtc() {
    if (title.trim().isEmpty) {
      throw ArgumentError('title cannot be empty');
    }
    if (tempo <= 0 || tempo > 400) {
      throw ArgumentError('tempo must be between 1 and 400 bpm');
    }
  }

  void addSection(SongSection section) {
    sections.add(section);
  }

  int totalBars() {
    return sections.fold(0, (sum, s) => sum + s.barCount);
  }
}

class CollaborationRequest {
  final String requestId;
  final String fromUserId;
  final String toUserId;
  final String projectId;
  final String message;
  String status; // pending, accepted, declined

  CollaborationRequest({
    required this.requestId,
    required this.fromUserId,
    required this.toUserId,
    required this.projectId,
    this.message = '',
    this.status = 'pending',
  });

  void accept() {
    status = 'accepted';
  }

  void decline() {
    status = 'declined';
  }
}
