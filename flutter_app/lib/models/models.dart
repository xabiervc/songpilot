/// Core data models for SongPilot.
/// Dart port of songpilot/songpilot_core/models.py, extended with JSON
/// (de)serialization used by the Supabase persistence layer.
library models;

enum SkillLevel { beginner, intermediate, advanced }

enum Visibility { private_, public_, collabOpen }

enum SectionType { intro, verse, preChorus, chorus, bridge, outro, custom }

String _skillLevelToString(SkillLevel level) => level.name;

SkillLevel _skillLevelFromString(String? value) => SkillLevel.values.firstWhere(
      (e) => e.name == value,
      orElse: () => SkillLevel.intermediate,
    );

String _visibilityToString(Visibility visibility) => switch (visibility) {
      Visibility.private_ => 'private',
      Visibility.public_ => 'public',
      Visibility.collabOpen => 'collab_open',
    };

Visibility _visibilityFromString(String? value) => switch (value) {
      'public' => Visibility.public_,
      'collab_open' => Visibility.collabOpen,
      _ => Visibility.private_,
    };

const Map<SectionType, String> _sectionTypeNames = {
  SectionType.intro: 'intro',
  SectionType.verse: 'verse',
  SectionType.preChorus: 'pre_chorus',
  SectionType.chorus: 'chorus',
  SectionType.bridge: 'bridge',
  SectionType.outro: 'outro',
  SectionType.custom: 'custom',
};

String _sectionTypeToString(SectionType type) =>
    _sectionTypeNames[type] ?? 'custom';

SectionType _sectionTypeFromString(String? value) =>
    SectionType.values.firstWhere(
      (e) => _sectionTypeNames[e] == value,
      orElse: () => SectionType.custom,
    );

List<String> _stringListFromJson(Object? value) =>
    (value as List<dynamic>? ?? const <dynamic>[])
        .map((e) => e.toString())
        .toList();

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

  Map<String, dynamic> toJson() => {
        'id': userId,
        'username': username,
        'email': email,
        'skill_level': _skillLevelToString(skillLevel),
        'instruments': instruments,
        'genres': genres,
        'favourite_artists': favouriteArtists,
        'open_to_collab': openToCollab,
        'looking_for': lookingFor,
        'is_pro': isPro,
      };

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    final rawUsername = (json['username'] as String?)?.trim();
    return UserProfile(
      userId: json['id'] as String,
      username: (rawUsername == null || rawUsername.isEmpty)
          ? 'musician'
          : rawUsername,
      email: json['email'] as String? ?? 'unknown@unknown',
      skillLevel: _skillLevelFromString(json['skill_level'] as String?),
      instruments: _stringListFromJson(json['instruments']),
      genres: _stringListFromJson(json['genres']),
      favouriteArtists: _stringListFromJson(json['favourite_artists']),
      openToCollab: json['open_to_collab'] as bool? ?? false,
      lookingFor: _stringListFromJson(json['looking_for']),
      isPro: json['is_pro'] as bool? ?? false,
    );
  }
}

class SongSection {
  final SectionType sectionType;
  final String key;
  final List<String> chords;
  final int barCount;
  final String tabs;

  SongSection({
    required this.sectionType,
    required this.key,
    List<String>? chords,
    this.barCount = 4,
    this.tabs = '',
  }) : chords = chords ?? [] {
    if (barCount <= 0) {
      throw ArgumentError('barCount must be positive');
    }
  }

  Map<String, dynamic> toJson(String songId, int position) => {
        'song_id': songId,
        'position': position,
        'section_type': _sectionTypeToString(sectionType),
        'key': key,
        'chords': chords,
        'bar_count': barCount,
        'tabs': tabs,
      };

  factory SongSection.fromJson(Map<String, dynamic> json) => SongSection(
        sectionType: _sectionTypeFromString(json['section_type'] as String?),
        key: json['key'] as String? ?? 'C',
        chords: _stringListFromJson(json['chords']),
        barCount: (json['bar_count'] as num?)?.toInt() ?? 4,
        tabs: json['tabs'] as String? ?? '',
      );
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

  Map<String, dynamic> toJson() => {
        'id': projectId,
        'owner_id': ownerId,
        'title': title,
        'key': key,
        'tempo': tempo,
        'style': style,
        'mood': mood,
        'instrument': instrument,
        'visibility': _visibilityToString(visibility),
        'created_at': createdAt.toIso8601String(),
      };

  factory SongProject.fromJson(Map<String, dynamic> json) => SongProject(
        projectId: json['id'] as String,
        ownerId: json['owner_id'] as String,
        title: json['title'] as String? ?? 'Untitled song',
        key: json['key'] as String? ?? 'C',
        tempo: (json['tempo'] as num?)?.toInt() ?? 120,
        style: json['style'] as String? ?? 'rock',
        mood: json['mood'] as String? ?? 'driving',
        instrument: json['instrument'] as String? ?? 'guitar',
        visibility: _visibilityFromString(json['visibility'] as String?),
        createdAt: json['created_at'] != null
            ? DateTime.tryParse(json['created_at'].toString())
            : null,
      );
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

  Map<String, dynamic> toJson() => {
        'id': requestId,
        'from_user': fromUserId,
        'to_user': toUserId,
        'song_id': projectId.isEmpty ? null : projectId,
        'message': message,
        'status': status,
      };

  factory CollaborationRequest.fromJson(Map<String, dynamic> json) =>
      CollaborationRequest(
        requestId: json['id'] as String,
        fromUserId: json['from_user'] as String,
        toUserId: json['to_user'] as String,
        projectId: json['song_id'] as String? ?? '',
        message: json['message'] as String? ?? '',
        status: json['status'] as String? ?? 'pending',
      );
}
