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
  Future<void> upsertProfile(UserProfile profile) async => _client.from('profiles').upsert(profile.toJson());
  Future<void> setOpenToCollab(String userId, bool open) async {
    await _client.from('profiles').upsert({'id': userId, 'open_to_collab': open, 'updated_at': DateTime.now().toUtc().toIso8601String()});
  }
  Future<List<UserProfile>> listOpenProfiles({int limit = 50}) async {
    final rows = await _client.from('profiles').select().eq('open_to_collab', true).order('updated_at', ascending: false).limit(limit);
    return [for (final row in rows) UserProfile.fromJson(row)];
  }
}

class ProjectService {
  ProjectService([SupabaseClient? client]) : _client = client ?? _client0;
  static final SupabaseClient _client0 = Supabase.instance.client;
  final SupabaseClient _client;
  Future<List<SongProject>> listMyProjects() async {
    final id = _requireUserId();
    final rows = await _client.from('songs').select().eq('owner_id', id).order('created_at', ascending: false);
    return [for (final row in rows) SongProject.fromJson(row)];
  }
  Future<SongProject?> getProject(String projectId) async {
    final id = _requireUserId();
    final rows = await _client.from('songs').select().eq('id', projectId).eq('owner_id', id).limit(1);
    if (rows.isEmpty) return null;
    final sections = await _client.from('song_sections').select().eq('song_id', projectId).order('position', ascending: true);
    final project = SongProject.fromJson(rows.first);
    for (final row in sections) { project.addSection(SongSection.fromJson(row)); }
    return project;
  }
  Future<List<SongProject>> listDiscoverableProjects({int limit = 50}) async {
    final rows = await _client.from('songs').select().inFilter('visibility', ['public', 'collab_open']).order('created_at', ascending: false).limit(limit);
    return [for (final row in rows) SongProject.fromJson(row)];
  }
  Future<SongProject> saveProject(SongProject project) async {
    final id = _requireUserId();
    final row = project.toJson()..remove('id')..remove('owner_id')..['owner_id'] = id;
    Map<String, dynamic> savedRow;
    if (project.projectId.isEmpty || project.projectId == 'new') { savedRow = await _client.from('songs').insert(row).select().single(); }
    else { row['id'] = project.projectId; savedRow = await _client.from('songs').upsert(row).select().single(); }
    final saved = SongProject.fromJson(savedRow);
    await _client.from('song_sections').delete().eq('song_id', saved.projectId);
    if (project.sections.isNotEmpty) { await _client.from('song_sections').insert([for (var i = 0; i < project.sections.length; i++) project.sections[i].toJson(saved.projectId, i)]); }
    return saved;
  }
  Future<void> deleteProject(String projectId) async { _requireUserId(); await _client.from('songs').delete().eq('id', projectId); }
}

class CollaborationService {
  CollaborationService([SupabaseClient? client]) : _client = client ?? _client0;
  static final SupabaseClient _client0 = Supabase.instance.client;
  final SupabaseClient _client;
  Future<void> sendRequest({required String toUserId, String? projectId, String message = ''}) async {
    final fromId = _requireUserId();
    await _client.from('collab_requests').insert({'from_user': fromId, 'to_user': toUserId, 'song_id': (projectId == null || projectId == 'new') ? null : projectId, 'message': message});
  }
  Future<List<CollaborationRequest>> listIncoming() async {
    final id = _requireUserId();
    final rows = await _client.from('collab_requests').select().eq('to_user', id).order('created_at', ascending: false);
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
    final id = _client.auth.currentUser?.id;
    if (id == null) throw StateError('You must be logged in to request account deletion.');
    await _client.from('account_deletion_requests').upsert({'user_id': id, 'requested_at': DateTime.now().toUtc().toIso8601String(), 'status': 'pending', 'note': note}, onConflict: 'user_id');
  }
  Future<String?> deletionRequestStatus() async {
    final id = _requireUserId();
    final rows = await _client.from('account_deletion_requests').select('status').eq('user_id', id).limit(1);
    return rows.isEmpty ? null : rows.first['status'] as String?;
  }
  Future<Map<String, dynamic>> exportMyData() async {
    final id = _requireUserId();
    final profile = await _client.from('profiles').select().eq('id', id).limit(1);
    final songs = await _client.from('songs').select().eq('owner_id', id);
    final ids = [for (final row in songs) row['id']];
    final sections = ids.isEmpty ? <Map<String, dynamic>>[] : await _client.from('song_sections').select().inFilter('song_id', ids);
    final requests = await _client.from('collab_requests').select().or('from_user.eq.$id,to_user.eq.$id');
    final reports = await _client.from('content_reports').select().eq('reporter_id', id);
    final blocks = await _client.from('user_blocks').select().eq('blocker_id', id);
    return {'exported_at': DateTime.now().toUtc().toIso8601String(), 'profile': profile, 'songs': songs, 'song_sections': sections, 'collab_requests': requests, 'content_reports': reports, 'user_blocks': blocks};
  }
  String encodeExport(Map<String, dynamic> data) => const JsonEncoder.withIndent('  ').convert(data);
  Future<Map<String, dynamic>> processOwnAccountDeletion() async {
    _requireUserId();
    final response = await _client.functions.invoke('process-account-deletion', body: <String, dynamic>{});
    if (response.status < 200 || response.status >= 300) throw StateError('Account deletion could not be completed. Please retry or contact support.');
    return Map<String, dynamic>.from(response.data as Map);
  }
}

class CommunitySafetyService {
  CommunitySafetyService([SupabaseClient? client]) : _client = client ?? _client0;
  static final SupabaseClient _client0 = Supabase.instance.client;
  final SupabaseClient _client;
  Future<void> blockUser(String targetId) async {
    final id = _requireUserId();
    if (targetId == id) throw ArgumentError('You cannot block your own account.');
    await _client.from('user_blocks').upsert({'blocker_id': id, 'blocked_id': targetId}, onConflict: 'blocker_id,blocked_id');
  }
  Future<void> unblockUser(String targetId) async {
    final id = _requireUserId();
    await _client.from('user_blocks').delete().eq('blocker_id', id).eq('blocked_id', targetId);
  }
  Future<void> reportUser({required String reportedUserId, required String reason}) async {
    final id = _requireUserId();
    await _client.from('content_reports').insert({'reporter_id': id, 'reported_user_id': reportedUserId, 'reason': reason.trim()});
  }
  Future<void> reportSong({required String songId, required String reason}) async {
    final id = _requireUserId();
    await _client.from('content_reports').insert({'reporter_id': id, 'song_id': songId, 'reason': reason.trim()});
  }
  Future<Set<String>> blockedUserIds() async {
    final id = _requireUserId();
    final rows = await _client.from('user_blocks').select('blocked_id').eq('blocker_id', id);
    return {for (final row in rows) row['blocked_id'] as String};
  }
  Future<List<Map<String, dynamic>>> listReports({String? status}) async {
    var query = _client.from('content_reports').select('id, reporter_id, reported_user_id, song_id, reason, status, created_at');
    if (status != null) query = query.eq('status', status);
    final rows = await query.order('created_at', ascending: true).limit(200);
    return [for (final row in rows) Map<String, dynamic>.from(row)];
  }
  Future<void> updateReportStatus(String reportId, String status) async {
    if (!{'reviewing', 'resolved', 'dismissed'}.contains(status)) throw ArgumentError.value(status, 'status');
    await _client.from('content_reports').update({'status': status}).eq('id', reportId);
  }
}
