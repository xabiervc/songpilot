import 'package:flutter/material.dart';

import '../main.dart';
import '../models/models.dart';
import '../services/supabase_service.dart';

class CollabScreen extends StatefulWidget {
  const CollabScreen({super.key});
  @override
  State<CollabScreen> createState() => _CollabScreenState();
}
enum _CollabView { projects, musicians, requests }
class _CollabScreenState extends State<CollabScreen> {
  _CollabView _view = _CollabView.projects;
  List<SongProject> _projects = const [];
  List<UserProfile> _profiles = const [];
  List<CollaborationRequest> _requests = const [];
  Set<String> _blockedIds = {};
  bool _loading = true;
  String? _error;
  String? get _myId => supabase.auth.currentUser?.id;
  @override
  void initState() { super.initState(); _load(); }
  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final blocked = await CommunitySafetyService().blockedUserIds();
      final allProjects = await ProjectService().listDiscoverableProjects();
      final allProfiles = await ProfileService().listOpenProfiles();
      final requests = await CollaborationService().listIncoming();
      if (!mounted) return;
      setState(() { _blockedIds = blocked; _projects = allProjects.where((p) => !blocked.contains(p.ownerId)).toList(); _profiles = allProfiles.where((p) => !blocked.contains(p.userId)).toList(); _requests = requests.where((r) => !blocked.contains(r.fromUserId)).toList(); });
    } catch (e) { if (mounted) setState(() => _error = e.toString()); }
    finally { if (mounted) setState(() => _loading = false); }
  }
  void _message(String text) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  Future<void> _sendRequest({required String toUserId, String? projectId}) async {
    final message = await showDialog<String>(context: context, builder: (_) => const _CollabRequestDialog());
    if (message == null || !mounted) return;
    try { await CollaborationService().sendRequest(toUserId: toUserId, projectId: projectId, message: message); if (mounted) _message('Collaboration request sent.'); }
    catch (e) { if (mounted) _message('Could not send request: $e'); }
  }
  Future<void> _respondTo(CollaborationRequest r, {required bool accept}) async {
    try { await CollaborationService().respond(r.requestId, accept: accept); await _load(); }
    catch (e) { if (mounted) _message('Could not update request: $e'); }
  }
  Future<String?> _askReason() async {
    final c = TextEditingController();
    final value = await showDialog<String>(context: context, builder: (ctx) => AlertDialog(title: const Text('Report content'), content: TextField(controller: c, maxLength: 500, maxLines: 3, decoration: const InputDecoration(hintText: 'Describe the issue (at least 3 characters)')), actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')), FilledButton(onPressed: () { if (c.text.trim().length >= 3) Navigator.pop(ctx, c.text.trim()); }, child: const Text('Submit'))]));
    c.dispose();
    return value;
  }
  Future<void> _safetyMenu({required String userId, String? songId}) async {
    final action = await showModalBottomSheet<String>(context: context, builder: (ctx) => SafeArea(child: Wrap(children: [ListTile(leading: const Icon(Icons.block), title: const Text('Block user'), onTap: () => Navigator.pop(ctx, 'block')), ListTile(leading: const Icon(Icons.flag_outlined), title: const Text('Report'), onTap: () => Navigator.pop(ctx, 'report'))])));
    if (action == null || !mounted) return;
    try {
      if (action == 'block') {
        final ok = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(title: const Text('Block this user?'), content: const Text('Their profiles and projects will be hidden from your collaboration lists.'), actions: [TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')), FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Block'))]));
        if (ok != true || !mounted) return;
        await CommunitySafetyService().blockUser(userId);
        await _load();
        if (mounted) _message('User blocked and hidden from your lists.');
      } else {
        final reason = await _askReason();
        if (reason == null || !mounted) return;
        if (songId == null) { await CommunitySafetyService().reportUser(reportedUserId: userId, reason: reason); }
        else { await CommunitySafetyService().reportSong(songId: songId, reason: reason); }
        if (mounted) _message('Report submitted.');
      }
    } catch (e) { if (mounted) _message('Action failed: $e'); }
  }
  String _shortId(String id) => id.length <= 8 ? id : '${id.substring(0, 8)}…';
  @override
  Widget build(BuildContext context) => Scaffold(appBar: AppBar(title: const Text('Collaborate')), body: Column(children: [
    Padding(padding: const EdgeInsets.fromLTRB(16, 12, 16, 4), child: SegmentedButton<_CollabView>(showSelectedIcon: false, segments: const [ButtonSegment(value: _CollabView.projects, icon: Icon(Icons.music_note_outlined), label: Text('Projects')), ButtonSegment(value: _CollabView.musicians, icon: Icon(Icons.person_outline), label: Text('Musicians')), ButtonSegment(value: _CollabView.requests, icon: Icon(Icons.inbox_outlined), label: Text('Requests'))], selected: {_view}, onSelectionChanged: (s) => setState(() => _view = s.first))),
    Expanded(child: _buildContent()),
  ]));
  Widget _buildContent() {
    if (_loading && _projects.isEmpty && _profiles.isEmpty) return const Center(child: CircularProgressIndicator());
    if (_error != null) return Center(child: Column(mainAxisSize: MainAxisSize.min, children: [Text(_error!), FilledButton(onPressed: _load, child: const Text('Retry'))]));
    return RefreshIndicator(onRefresh: _load, child: switch (_view) { _CollabView.projects => _buildProjects(), _CollabView.musicians => _buildMusicians(), _CollabView.requests => _buildRequests() });
  }
  Widget _buildProjects() => ListView(padding: const EdgeInsets.all(16), children: [if (_projects.isEmpty) const ListTile(title: Text('No open projects yet')), for (final p in _projects) Card(child: ListTile(title: Text(p.title), subtitle: Text('${p.key} · ${p.tempo} bpm · ${p.style} · ${p.mood}'), trailing: p.ownerId == _myId ? const Chip(label: Text('Yours')) : Wrap(children: [IconButton(tooltip: 'Report or block owner', icon: const Icon(Icons.more_vert), onPressed: () => _safetyMenu(userId: p.ownerId, songId: p.projectId)), FilledButton.tonal(onPressed: () => _sendRequest(toUserId: p.ownerId, projectId: p.projectId), child: const Text('Collab'))])))]);
  Widget _buildMusicians() {
    final profiles = _profiles.where((p) => p.userId != _myId).toList();
    return ListView(padding: const EdgeInsets.all(16), children: [if (profiles.isEmpty) const ListTile(title: Text('No collaborators found yet')), for (final p in profiles) Card(child: ListTile(title: Text(p.username), subtitle: Text([if (p.instruments.isNotEmpty) p.instruments.join(', '), if (p.genres.isNotEmpty) p.genres.join(', '), if (p.lookingFor.isNotEmpty) 'Looking for: ${p.lookingFor.join(', ')}'].join('\n')), trailing: Wrap(children: [IconButton(tooltip: 'Report or block', icon: const Icon(Icons.more_vert), onPressed: () => _safetyMenu(userId: p.userId)), FilledButton.tonal(onPressed: () => _sendRequest(toUserId: p.userId), child: const Text('Collab'))]))]);
  }
  Widget _buildRequests() => ListView(padding: const EdgeInsets.all(16), children: [if (_requests.isEmpty) const ListTile(title: Text('No requests yet')), for (final r in _requests) Card(child: ListTile(title: Text('From ${_shortId(r.fromUserId)}'), subtitle: Text(r.message), trailing: r.status == 'pending' ? Wrap(children: [IconButton(tooltip: 'Report or block', icon: const Icon(Icons.more_vert), onPressed: () => _safetyMenu(userId: r.fromUserId)), IconButton(icon: const Icon(Icons.check), onPressed: () => _respondTo(r, accept: true)), IconButton(icon: const Icon(Icons.close), onPressed: () => _respondTo(r, accept: false))]) : Text(r.status)))]);
}
