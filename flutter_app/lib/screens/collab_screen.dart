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
      setState(() {
        _blockedIds = blocked;
        _projects = allProjects.where((p) => !_blockedIds.contains(p.ownerId)).toList();
        _profiles = allProfiles.where((p) => !_blockedIds.contains(p.userId)).toList();
        _requests = requests.where((r) => !_blockedIds.contains(r.fromUserId)).toList();
      });
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _sendRequest({required String toUserId, String? projectId}) async {
    final message = await showDialog<String>(context: context, builder: (_) => const _CollabRequestDialog());
    if (message == null) return;
    try {
      await CollaborationService().sendRequest(toUserId: toUserId, projectId: projectId, message: message);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Collaboration request sent')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not send request: $e')));
    }
  }

  Future<void> _respondTo(CollaborationRequest request, {required bool accept}) async {
    try { await CollaborationService().respond(request.requestId, accept: accept); await _load(); }
    catch (e) { if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not update request: $e'))); }
  }

  Future<void> _safetyAction({required String userId, String? songId}) async {
    final action = await showModalBottomSheet<String>(
      context: context,
      builder: (ctx) => SafeArea(child: Wrap(children: [
        ListTile(leading: const Icon(Icons.block), title: const Text('Block user'), onTap: () => Navigator.pop(ctx, 'block')),
        ListTile(leading: const Icon(Icons.flag_outlined), title: const Text('Report'), onTap: () => Navigator.pop(ctx, 'report')),
      ])),
    );
    if (action == null) return;
    try {
      if (action == 'block') {
        await CommunitySafetyService().blockUser(userId);
        await _load();
      } else {
        final reason = await _askReason();
        if (reason == null) return;
        if (songId == null) {
          await CommunitySafetyService().reportUser(reportedUserId: userId, reason: reason);
        } else {
          await CommunitySafetyService().reportSong(songId: songId, reason: reason);
        }
      }
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(action == 'block' ? 'User blocked and hidden from your lists.' : 'Report submitted.')));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Action failed: $e')));
    }
  }

  Future<String?> _askReason() async {
    final controller = TextEditingController();
    final value = await showDialog<String>(context: context, builder: (ctx) => AlertDialog(
      title: const Text('Report content'),
      content: TextField(controller: controller, maxLength: 500, maxLines: 3, decoration: const InputDecoration(hintText: 'Describe the issue (at least 3 characters)')),
      actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')), FilledButton(onPressed: () { final reason = controller.text.trim(); if (reason.length >= 3) Navigator.pop(ctx, reason); }, child: const Text('Submit'))],
    ));
    controller.dispose();
    return value;
  }

  String _shortId(String id) => id.length <= 8 ? id : '${id.substring(0, 8)}…';

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Collaborate')),
    body: Column(children: [
      Padding(padding: const EdgeInsets.fromLTRB(16, 12, 16, 4), child: SegmentedButton<_CollabView>(showSelectedIcon: false, segments: const [
        ButtonSegment(value: _CollabView.projects, icon: Icon(Icons.music_note_outlined), label: Text('Projects')),
        ButtonSegment(value: _CollabView.musicians, icon: Icon(Icons.person_outline), label: Text('Musicians')),
        ButtonSegment(value: _CollabView.requests, icon: Icon(Icons.inbox_outlined), label: Text('Requests')),
      ], selected: {_view}, onSelectionChanged: (s) => setState(() => _view = s.first))),
      Expanded(child: _buildContent()),
    ]),
  );

  Widget _buildContent() {
    if (_loading && _projects.isEmpty && _profiles.isEmpty) return const Center(child: CircularProgressIndicator());
    if (_error != null) return Center(child: Column(mainAxisSize: MainAxisSize.min, children: [Text(_error!), FilledButton(onPressed: _load, child: const Text('Retry'))]));
    return RefreshIndicator(onRefresh: _load, child: switch (_view) {
      _CollabView.projects => _buildProjects(),
      _CollabView.musicians => _buildMusicians(),
      _CollabView.requests => _buildRequests(),
    });
  }

  Widget _buildProjects() => ListView(padding: const EdgeInsets.all(16), children: [
    if (_projects.isEmpty) const ListTile(title: Text('No open projects yet')),
    for (final p in _projects) Card(child: ListTile(
      title: Text(p.title), subtitle: Text('${p.key} · ${p.tempo} bpm · ${p.style} · ${p.mood}'),
      trailing: p.ownerId == _myId ? const Chip(label: Text('Yours')) : Wrap(mainAxisSize: MainAxisSize.min, children: [
        IconButton(tooltip: 'Report project', icon: const Icon(Icons.flag_outlined), onPressed: () => _safetyAction(userId: p.ownerId, songId: p.projectId)),
        FilledButton.tonal(onPressed: () => _sendRequest(toUserId: p.ownerId, projectId: p.projectId), child: const Text('Collab')),
      ]),
    )),
  ]);

  Widget _buildMusicians() {
    final profiles = _profiles.where((p) => p.userId != _myId).toList();
    return ListView(padding: const EdgeInsets.all(16), children: [
      if (profiles.isEmpty) const ListTile(title: Text('No collaborators found yet')),
      for (final p in profiles) Card(child: ListTile(
        title: Text(p.username), subtitle: Text([if (p.instruments.isNotEmpty) p.instruments.join(', '), if (p.genres.isNotEmpty) p.genres.join(', '), if (p.lookingFor.isNotEmpty) 'Looking for: ${p.lookingFor.join(', ')}'].join('\n')),
        trailing: Wrap(mainAxisSize: MainAxisSize.min, children: [
          IconButton(tooltip: 'Block or report', icon: const Icon(Icons.more_vert), onPressed: () => _safetyAction(userId: p.userId)),
          FilledButton.tonal(onPressed: () => _sendRequest(toUserId: p.userId), child: const Text('Collab')),
        ]),
      )),
    ]);
  }

  Widget _buildRequests() => ListView(padding: const EdgeInsets.all(16), children: [
    if (_requests.isEmpty) const ListTile(title: Text('No requests yet')),
    for (final r in _requests) Card(child: ListTile(
      title: Text('From ${_shortId(r.fromUserId)}'), subtitle: Text(r.message),
      trailing: r.status == 'pending' ? Wrap(mainAxisSize: MainAxisSize.min, children: [
        IconButton(tooltip: 'Block or report', icon: const Icon(Icons.more_vert), onPressed: () => _safetyAction(userId: r.fromUserId)),
        IconButton(icon: const Icon(Icons.check), onPressed: () => _respondTo(r, accept: true)),
        IconButton(icon: const Icon(Icons.close), onPressed: () => _respondTo(r, accept: false)),
      ]) : Text(r.status),
    )),
  ]);
}

class _CollabRequestDialog extends StatefulWidget {
  const _CollabRequestDialog();
  @override
  State<_CollabRequestDialog> createState() => _CollabRequestDialogState();
}
class _CollabRequestDialogState extends State<_CollabRequestDialog> {
  final _messageController = TextEditingController();
  @override
  void dispose() { _messageController.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Request collaboration'),
    content: TextField(controller: _messageController, maxLines: 3, decoration: const InputDecoration(hintText: 'Short intro + what you are looking for (optional)')),
    actions: [TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')), FilledButton(onPressed: () => Navigator.of(context).pop(_messageController.text.trim()), child: const Text('Send'))],
  );
}
