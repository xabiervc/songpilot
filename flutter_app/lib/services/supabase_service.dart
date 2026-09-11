/// Supabase-backed persistence services.
///
/// Tables are created by supabase/migrations/20260911210000_init.sql.
/// Methods raise a StateError with a user-readable message when the caller is
/// not authenticated, so screens can display the error text directly.
library supabase_service;

import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/models.dart';

SupabaseClient get _client => Supabase.instance.client;

String _requireUserId() {
  final id = _client.auth.currentUser?.id;
  if (id == null) {
    throw StateError('You must be logged in to do that.');
  }
  return id;
}

/// CRUD for the `profiles` table.
class ProfileService {
  ProfileService([SupabaseClient? client]) : _client = client ?? _client0;

  static final SupabaseClient _client0 = Supabase.instance.client;

  final SupabaseClient _client;

  Future<UserProfile?> getProfile(String userId) async {
    final rows =
        await _client.from('profiles').select().eq('id', userId).limit(1);
    if (rows.isEmpty) return null;
    return UserProfile.fromJson(rows.first);
  }

  Future<void> upsertProfile(UserProfile profile) async {
    await _client.from('profiles').upsert(profile.toJson());
  }

  Future<void> setOpenToCollab(String userId, bool open) async {
    await _client.from('profiles').upsert({
      'id': userId,
      'open_to_collab': open,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    });
  }
}

/// CRUD for `songs` and their `song_sections`.
class ProjectService {
  ProjectService([SupabaseClient? client]) : _client = client ?? _client0;

  static final SupabaseClient _client0 = Supabase.instance.client;

  final SupabaseClient _client;

  Future<List<SongProject>> listMyProjects() async {
    final userId = _requireUserId();
    final rows = await _client
        .from('songs')
        .select()
        .eq('owner_id', userId)
        .order('created_at', ascending: false);
    return [for (final row in rows) SongProject.fromJson(row)];
  }

  /// Loads a single song with its sections, ordered by section position.
  /// Returns null if the song doesn't exist or isn't visible to the user.
  Future<SongProject?> getProject(String projectId) async {
    final userId = _requireUserId();
    final songRows = await _client
        .from('songs')
        .select()
        .eq('id', projectId)
        .eq('owner_id', userId)
        .limit(1);
    if (songRows.isEmpty) return null;

    final sectionRows = await _client
        .from('song_sections')
        .select()
        .eq('song_id', projectId)
        .order('position', ascending: true);

    final project = SongProject.fromJson(songRows.first);
    for (final row in sectionRows) {
      project.addSection(SongSection.fromJson(row));
    }
    return project;
  }

  /// Inserts the song when projectId is empty/'new', otherwise upserts it.
  /// Sections are fully replaced for simplicity while the editor works on the
  /// whole arrangement at once (cheap at small scale, consistent restore).
  Future<SongProject> saveProject(SongProject project) async {
    final userId = _requireUserId();
    final row = project.toJson()
      ..remove('id')
      ..remove('owner_id')
      ..['owner_id'] = userId;

    Map<String, dynamic> savedRow;
    if (project.projectId.isEmpty || project.projectId == 'new') {
      savedRow = await _client.from('songs').insert(row).select().single();
    } else {
      row['id'] = project.projectId;
      savedRow = await _client.from('songs').upsert(row).select().single();
    }

    final saved = SongProject.fromJson(savedRow);

    await _client.from('song_sections').delete().eq('song_id', saved.projectId);
    if (project.sections.isNotEmpty) {
      final sectionRows = [
        for (var i = 0; i < project.sections.length; i++)
          project.sections[i].toJson(saved.projectId, i),
      ];
      await _client.from('song_sections').insert(sectionRows);
    }
    return saved;
  }

  Future<void> deleteProject(String projectId) async {
    _requireUserId();
    await _client.from('songs').delete().eq('id', projectId);
  }
}

/// CRUD for `collab_requests`.
class CollaborationService {
  CollaborationService([SupabaseClient? client])
      : _client = client ?? _client0;

  static final SupabaseClient _client0 = Supabase.instance.client;

  final SupabaseClient _client;

  Future<void> sendRequest({
    required String toUserId,
    String? projectId,
    String message = '',
  }) async {
    final fromId = _requireUserId();
    await _client.from('collab_requests').insert({
      'from_user': fromId,
      'to_user': toUserId,
      'song_id': (projectId == null || projectId == 'new') ? null : projectId,
      'message': message,
    });
  }

  Future<List<CollaborationRequest>> listIncoming() async {
    final uid = _requireUserId();
    final rows = await _client
        .from('collab_requests')
        .select()
        .eq('to_user', uid)
        .order('created_at', ascending: false);
    return [for (final r in rows) CollaborationRequest.fromJson(r)];
  }

  Future<void> respond(String requestId, {required bool accept}) async {
    _requireUserId();
    await _client
        .from('collab_requests')
        .update({'status': accept ? 'accepted' : 'declined'})
        .eq('id', requestId);
  }
}
