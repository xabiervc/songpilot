/// Supabase-backed persistence services.
library supabase_service;

import 'dart:convert';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/models.dart';

SupabaseClient get _client => Supabase.instance.client;

String _requireUserId() {
  final id = _client.auth.currentUser?.id;
  if (id == null) throw StateError('You must be logged in to do that.');
  return id;
}

class ProfileService {
  ProfileService([SupabaseClient? client]) : _client = client ?? _client0;
  static final SupabaseClient _client0 = Supabase.instance.client;
  final SupabaseClient _client;

  Future<UserProfile?> getProfile(String userId) async {
    final rows = await _client.from('profiles').select().eq('id', userId).limit(1);
    if (rows.isEmpty) return null;
    return UserProfile.fromJson(rows.first);
  }

  Future<void> upsertProfile(UserProfile profile) async =>
      _client.from('profiles').upsert(profile.toJson());

  Future<void> setOpenToCollab(String userId, bool open) async {
    await _client.from('profiles').upsert({
      'id': userId,
      'open_to_collab': open,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    });
  }

  Future<List<UserProfile>> listOpenProfiles({int limit = 50}) async {
    final rows = await _client.from('profiles').select()
        .eq('open_to_collab', true).order('updated_at', ascending: false).limit(limit);
    return [for (final row in rows) UserProfile.fromJson(row)];
  }
}

class ProjectService {
  ProjectService([SupabaseClient? client]) : _client = client ?? _client0;
  static final SupabaseClient _client0 = Supabase.instance.client;
  final SupabaseClient _client;

  Future<List<SongProject>> listMyProjects() async {
    final userId = _requireUserId();
    final rows = await _client.from('songs').select().eq('owner_id', userId)
        .order('created_at', ascending: false);
    return [for (final row in rows) SongProject.fromJson(row)];
  }

  Future<SongProject?> getProject(String projectId) async {
    final userId = _requireUserId();
    final rows = await _client.from('songs').select().eq('id', projectId)
        .eq('owner_id', userId).limit(1);
    if (rows.isEmpty) return null;
    final sectionRows = await _client.from('song_sections').select()
        .eq('song_id', projectId).order('position', ascending: true);
    final project = SongProject.fromJson(rows.first);
    for (final row in sectionRows) {
      project.addSection(SongSection.fromJson(row));
    }
    return project;
  }

  Future<List<SongProject>> listDiscoverableProjects({int limit = 50}) async {
    final rows = await _client.from('songs').select()
        .inFilter('visibility', ['public', 'collab_open'])
        .order('created_at', ascending: false).limit(limit);
    return [for (final row in rows) SongProject.fromJson(row)];
  }

  Future<SongProject> saveProject(SongProject project) async {
    final userId = _requireUserId();
    final row = project.toJson()..remove('id')..remove('owner_id')..['owner_id'] = userId;
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
      await _client.from('song_sections').insert([
        for (var i = 0; i < project.sections.length; i++)
          project.sections[i].toJson(saved.projectId, i),
      ]);
    }
    return saved;
  }

  Future<void> deleteProject(String projectId) async {
    _requireUserId();
    await _client.from('songs').delete().eq('id', projectId);
  }
}

class CollaborationService {
  CollaborationService([SupabaseClient? client]) : _client = client ?? _client0;
  static final SupabaseClient _client0 = Supabase.instance.client;
  final SupabaseClient _client;

  Future<void> sendRequest({required String toUserId, String? projectId, String message = ''}) async {
    final fromId = _requireUserId();
    await _client.from('collab_requests').insert({
      'from_user': fromId, 'to_user': toUserId,
      'song_id': (projectId == null || projectId == 'new') ? null : projectId,
      'message': message,
    });
  }

  Future<List<CollaborationRequest>> listIncoming() async {
    final uid = _requireUserId();
    final rows = await _client.from('collab_requests').select().eq('to_user', uid)
        .order('created_at', ascending: false);
    return [for (final row in rows) CollaborationRequest.fromJson(row)];
  }

  Future<void> respond(String requestId, {required bool accept}) async {
    _requireUserId();
    await _client.from('collab_requests').update({'status': accept ? 'accepted' : 'declined'}).eq('id', requestId);
  }
}

class AccountService {
  AccountService([SupabaseClient? client]) : _client = client ?? _client0;
  static final SupabaseClient _client0 = Supabase.instance.client;
  final SupabaseClient _client;

  Future<void> requestAccountDeletion({String note = ''}) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) throw StateError('You must be logged in to request account deletion.');
    await _client.from('account_deletion_requests').upsert({
      'user_id': userId, 'requested_at': DateTime.now().toUtc().toIso8601String(),
      'status': 'pending', 'note': note,
    }, onConflict: 'user_id');
  }

  Future<String?> deletionRequestStatus() async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) throw StateError('You must be logged in to view this request.');
    final rows = await _client.from('account_deletion_requests').select('status')
        .eq('user_id', userId).limit(1);
    return rows.isEmpty ? null : rows.first['status'] as String?;
  }

  Future<Map<String, dynamic>> exportMyData() async {
    final userId = _requireUserId();
    final profile = await _client.from('profiles').select().eq('id', userId).limit(1);
    final songs = await _client.from('songs').select().eq('owner_id', userId);
    final songIds = [for (final row in songs) row['id']];
    final sections = songIds.isEmpty
        ? <Map<String, dynamic>>[]
        : await _client.from('song_sections').select().inFilter('song_id', songIds);
    final requests = await _client.from('collab_requests').select()
        .or('from_user.eq.$userId,to_user.eq.$userId');
    final reports = await _client.from('content_reports').select()
        .eq('reporter_id', userId);
    final blocks = await _client.from('user_blocks').select()
        .eq('blocker_id', userId);
    return {
      'exported_at': DateTime.now().toUtc().toIso8601String(),
      'profile': profile,
      'songs': songs,
      'song_sections': sections,
      'collab_requests': requests,
      'content_reports': reports,
      'user_blocks': blocks,
    };
  }

  String encodeExport(Map<String, dynamic> data) =>
      const JsonEncoder.withIndent('  ').convert(data);
}

class CommunitySafetyService {
  CommunitySafetyService([SupabaseClient? client]) : _client = client ?? _client0;
  static final SupabaseClient _client0 = Supabase.instance.client;
  final SupabaseClient _client;

  Future<void> blockUser(String blockedUserId) async {
    final userId = _requireUserId();
    if (blockedUserId == userId) throw ArgumentError('You cannot block your own account.');
    await _client.from('user_blocks').upsert({
      'blocker_id': userId, 'blocked_id': blockedUserId,
    }, onConflict: 'blocker_id,blocked_id');
  }

  Future<void> unblockUser(String blockedUserId) async {
    final userId = _requireUserId();
    await _client.from('user_blocks').delete()
        .eq('blocker_id', userId).eq('blocked_id', blockedUserId);
  }

  Future<void> reportUser({required String reportedUserId, required String reason}) async {
    final userId = _requireUserId();
    await _client.from('content_reports').insert({
      'reporter_id': userId, 'reported_user_id': reportedUserId, 'reason': reason.trim(),
    });
  }

  Future<void> reportSong({required String songId, required String reason}) async {
    final userId = _requireUserId();
    await _client.from('content_reports').insert({
      'reporter_id': userId, 'song_id': songId, 'reason': reason.trim(),
    });
  }

  Future<Set<String>> blockedUserIds() async {
    final userId = _requireUserId();
    final rows = await _client.from('user_blocks').select('blocked_id').eq('blocker_id', userId);
    return {for (final row in rows) row['blocked_id'] as String};
  }
}
