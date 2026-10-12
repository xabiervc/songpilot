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
  bool _loading = true;
  String? _error;

  String? get _myId => supabase.auth.currentUser?.id;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final blocked = await CommunitySafetyService().blockedUserIds();
      final allProjects = await ProjectService().listDiscoverableProjects();
      final allProfiles = await ProfileService().listOpenProfiles();
      final requests = await CollaborationService().listIncoming();
      if (!mounted) return;
      setState(() {
        _projects = allProjects
            .where((project) => !blocked.contains(project.ownerId))
            .toList();
        _profiles = allProfiles
            .where((profile) => !blocked.contains(profile.userId))
            .toList();
        _requests = requests
            .where((request) => !blocked.contains(request.fromUserId))
            .toList();
      });
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _message(String text) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  Future<void> _sendRequest({required String toUserId, String? projectId}) async {
    final message = await showDialog<String>(
      context: context,
      builder: (_) => const _CollabRequestDialog(),
    );
    if (!mounted || message == null) return;
    try {
      await CollaborationService().sendRequest(
        toUserId: toUserId,
        projectId: projectId,
        message: message,
      );
      if (mounted) _message('Collaboration request sent.');
    } catch (error) {
      if (mounted) _message('Could not send request: $error');
    }
  }

  Future<void> _respondTo(
    CollaborationRequest request, {
    required bool accept,
  }) async {
    try {
      await CollaborationService().respond(request.requestId, accept: accept);
      if (mounted) await _load();
    } catch (error) {
      if (mounted) _message('Could not update request: $error');
    }
  }

  Future<String?> _askReason() async {
    final controller = TextEditingController();
    try {
      return await showDialog<String>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Report content'),
          content: TextField(
            controller: controller,
            maxLength: 500,
            maxLines: 3,
            decoration: const InputDecoration(
              hintText: 'Describe the issue (at least 3 characters)',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                final reason = controller.text.trim();
                if (reason.length >= 3) {
                  Navigator.pop(dialogContext, reason);
                }
              },
              child: const Text('Submit'),
            ),
          ],
        ),
      );
    } finally {
      controller.dispose();
    }
  }

  Future<void> _safetyMenu({required String userId, String? songId}) async {
    final action = await showModalBottomSheet<String>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.block),
              title: const Text('Block user'),
              onTap: () => Navigator.pop(sheetContext, 'block'),
            ),
            ListTile(
              leading: const Icon(Icons.flag_outlined),
              title: const Text('Report'),
              onTap: () => Navigator.pop(sheetContext, 'report'),
            ),
          ],
        ),
      ),
    );
    if (!mounted || action == null) return;

    try {
      if (action == 'block') {
        final confirmed = await showDialog<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: const Text('Block this user?'),
            content: const Text(
              'Their profiles and projects will be hidden from your collaboration lists.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(dialogContext, true),
                child: const Text('Block'),
              ),
            ],
          ),
        );
        if (!mounted || confirmed != true) return;
        await CommunitySafetyService().blockUser(userId);
        if (!mounted) return;
        await _load();
        if (mounted) _message('User blocked and hidden from your lists.');
      } else {
        final reason = await _askReason();
        if (!mounted || reason == null) return;
        if (songId == null) {
          await CommunitySafetyService().reportUser(
            reportedUserId: userId,
            reason: reason,
          );
        } else {
          await CommunitySafetyService().reportSong(
            songId: songId,
            reason: reason,
          );
        }
        if (mounted) _message('Report submitted.');
      }
    } catch (error) {
      if (mounted) _message('Action failed: $error');
    }
  }

  String _shortId(String id) => id.length <= 8 ? id : '${id.substring(0, 8)}…';

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Collaborate')),
        body: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
              child: SegmentedButton<_CollabView>(
                showSelectedIcon: false,
                segments: const [
                  ButtonSegment(
                    value: _CollabView.projects,
                    icon: Icon(Icons.music_note_outlined),
                    label: Text('Projects'),
                  ),
                  ButtonSegment(
                    value: _CollabView.musicians,
                    icon: Icon(Icons.person_outline),
                    label: Text('Musicians'),
                  ),
                  ButtonSegment(
                    value: _CollabView.requests,
                    icon: Icon(Icons.inbox_outlined),
                    label: Text('Requests'),
                  ),
                ],
                selected: {_view},
                onSelectionChanged: (selection) {
                  setState(() => _view = selection.first);
                },
              ),
            ),
            Expanded(child: _buildContent()),
          ],
        ),
      );

  Widget _buildContent() {
    if (_loading && _projects.isEmpty && _profiles.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_error!),
            FilledButton(onPressed: _load, child: const Text('Retry')),
          ],
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: _load,
      child: switch (_view) {
        _CollabView.projects => _buildProjects(),
        _CollabView.musicians => _buildMusicians(),
        _CollabView.requests => _buildRequests(),
      },
    );
  }

  Widget _buildProjects() => ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (_projects.isEmpty)
            const ListTile(title: Text('No open projects yet')),
          for (final project in _projects)
            Card(
              child: ListTile(
                title: Text(project.title),
                subtitle: Text(
                  '${project.key} · ${project.tempo} bpm · ${project.style} · ${project.mood}',
                ),
                trailing: project.ownerId == _myId
                    ? const Chip(label: Text('Yours'))
                    : Wrap(
                        children: [
                          IconButton(
                            tooltip: 'Report or block owner',
                            icon: const Icon(Icons.more_vert),
                            onPressed: () => _safetyMenu(
                              userId: project.ownerId,
                              songId: project.projectId,
                            ),
                          ),
                          FilledButton.tonal(
                            onPressed: () => _sendRequest(
                              toUserId: project.ownerId,
                              projectId: project.projectId,
                            ),
                            child: const Text('Collab'),
                          ),
                        ],
                      ),
              ),
            ),
        ],
      );

  Widget _buildMusicians() {
    final profiles = _profiles.where((profile) => profile.userId != _myId);
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (profiles.isEmpty)
          const ListTile(title: Text('No collaborators found yet')),
        for (final profile in profiles)
          Card(
            child: ListTile(
              title: Text(profile.username),
              subtitle: Text([
                if (profile.instruments.isNotEmpty)
                  profile.instruments.join(', '),
                if (profile.genres.isNotEmpty) profile.genres.join(', '),
                if (profile.lookingFor.isNotEmpty)
                  'Looking for: ${profile.lookingFor.join(', ')}',
              ].join('\n')),
              trailing: Wrap(
                children: [
                  IconButton(
                    tooltip: 'Report or block',
                    icon: const Icon(Icons.more_vert),
                    onPressed: () => _safetyMenu(userId: profile.userId),
                  ),
                  FilledButton.tonal(
                    onPressed: () => _sendRequest(toUserId: profile.userId),
                    child: const Text('Collab'),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildRequests() => ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (_requests.isEmpty)
            const ListTile(title: Text('No requests yet')),
          for (final request in _requests)
            Card(
              child: ListTile(
                title: Text('From ${_shortId(request.fromUserId)}'),
                subtitle: Text(request.message),
                trailing: request.status == 'pending'
                    ? Wrap(
                        children: [
                          IconButton(
                            tooltip: 'Report or block',
                            icon: const Icon(Icons.more_vert),
                            onPressed: () =>
                                _safetyMenu(userId: request.fromUserId),
                          ),
                          IconButton(
                            icon: const Icon(Icons.check),
                            onPressed: () =>
                                _respondTo(request, accept: true),
                          ),
                          IconButton(
                            icon: const Icon(Icons.close),
                            onPressed: () =>
                                _respondTo(request, accept: false),
                          ),
                        ],
                      )
                    : Text(request.status),
              ),
            ),
        ],
      );
}

class _CollabRequestDialog extends StatefulWidget {
  const _CollabRequestDialog();

  @override
  State<_CollabRequestDialog> createState() => _CollabRequestDialogState();
}

class _CollabRequestDialogState extends State<_CollabRequestDialog> {
  final TextEditingController _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: const Text('Collaboration request'),
        content: TextField(
          controller: _controller,
          autofocus: true,
          maxLength: 500,
          maxLines: 3,
          decoration: const InputDecoration(
            hintText: 'Introduce yourself and say what you have in mind',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(_controller.text.trim()),
            child: const Text('Send'),
          ),
        ],
      );
}
