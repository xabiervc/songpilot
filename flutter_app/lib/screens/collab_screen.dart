import 'package:flutter/material.dart';

import '../main.dart';
import '../models/models.dart';
import '../services/supabase_service.dart';

/// Collaboration hub: discover projects and musicians who opted in, send
/// collaboration requests, and answer incoming ones.
///
/// Deliberately work-like, not dating-like: no swiping, no matching gimmicks.
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
      final projects = await ProjectService().listDiscoverableProjects();
      final profiles = await ProfileService().listOpenProfiles();
      final requests = await CollaborationService().listIncoming();
      if (!mounted) return;
      setState(() {
        _projects = projects;
        _profiles = profiles;
        _requests = requests;
      });
    } catch (e) {
      if (mounted) {
        setState(() => _error = e.toString());
      }
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _sendRequest({required String toUserId, String? projectId}) async {
    final message = await showDialog<String>(
      context: context,
      builder: (_) => const _CollabRequestDialog(),
    );
    if (message == null) return;
    try {
      await CollaborationService().sendRequest(
        toUserId: toUserId,
        projectId: projectId,
        message: message,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Collaboration request sent')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not send request: $e')),
      );
    }
  }

  Future<void> _respondTo(CollaborationRequest request,
      {required bool accept}) async {
    try {
      await CollaborationService().respond(request.requestId, accept: accept);
      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not update request: $e')),
      );
    }
  }

  String _shortId(String id) => id.length <= 8 ? id : '${id.substring(0, 8)}…';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
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
              onSelectionChanged: (selection) =>
                  setState(() => _view = selection.first),
            ),
          ),
          Expanded(child: _buildContent()),
        ],
      ),
    );
  }

  Widget _buildContent() {
    if (_loading && _projects.isEmpty && _profiles.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return _ErrorState(message: _error!, onRetry: _load);
    }
    return RefreshIndicator(
      onRefresh: _load,
      child: switch (_view) {
        _CollabView.projects => _buildProjectsList(),
        _CollabView.musicians => _buildMusiciansList(),
        _CollabView.requests => _buildRequestsList(),
      },
    );
  }

  Widget _buildProjectsList() {
    if (_projects.isEmpty) {
      return const _EmptyCollabState(
        icon: Icons.music_off_outlined,
        title: 'No open projects yet',
        message:
            'Mark a song as public or collaboration-open to appear here.',
      );
    }
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        for (final p in _projects)
          Card(
            child: ListTile(
              leading: const Icon(Icons.music_note_outlined),
              title: Text(p.title),
              subtitle: Text(
                  '${p.key} · ${p.tempo} bpm · ${p.style} · ${p.mood}'),
              trailing: p.ownerId == _myId
                  ? const Chip(label: Text('Yours'))
                  : FilledButton.tonal(
                      onPressed: () => _sendRequest(
                        toUserId: p.ownerId,
                        projectId: p.projectId,
                      ),
                      child: const Text('Collab'),
                    ),
            ),
          ),
      ],
    );
  }

  Widget _buildMusiciansList() {
    final profiles =
        _profiles.where((p) => p.userId != _myId).toList(growable: false);
    if (profiles.isEmpty) {
      return const _EmptyCollabState(
        icon: Icons.groups_outlined,
        title: 'No collaborators found yet',
        message: 'Mark your profile as "open to collaborate" to appear here.',
      );
    }
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        for (final p in profiles)
          Card(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: ListTile(
                leading: const Icon(Icons.person_outline),
                title: Text(p.username),
                subtitle: Text([
                  if (p.instruments.isNotEmpty) p.instruments.join(', '),
                  if (p.genres.isNotEmpty) p.genres.join(', '),
                  if (p.lookingFor.isNotEmpty)
                    'Looking for: ${p.lookingFor.join(', ')}',
                ].join('\n')),
                isThreeLine: true,
                trailing: FilledButton.tonal(
                  onPressed: () => _sendRequest(toUserId: p.userId),
                  child: const Text('Collab'),
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildRequestsList() {
    if (_requests.isEmpty) {
      return const _EmptyCollabState(
        icon: Icons.inbox_outlined,
        title: 'No requests yet',
        message: 'When someone wants to collaborate, it shows up here.',
      );
    }
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        for (final r in _requests)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text('From ${_shortId(r.fromUserId)}',
                            style:
                                Theme.of(context).textTheme.titleSmall),
                      ),
                      _StatusChip(status: r.status),
                    ],
                  ),
                  if (r.message.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(r.message),
                  ],
                  if (r.projectId.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text('About song ${_shortId(r.projectId)}',
                        style: Theme.of(context).textTheme.labelMedium),
                  ],
                  if (r.status == 'pending') ...[
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        FilledButton(
                          onPressed: () => _respondTo(r, accept: true),
                          child: const Text('Accept'),
                        ),
                        const SizedBox(width: 8),
                        OutlinedButton(
                          onPressed: () => _respondTo(r, accept: false),
                          child: const Text('Decline'),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),
      ],
    );
  }
}

class _StatusChip extends StatelessWidget {
  final String status;
  const _StatusChip({required this.status});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final (color, label) = switch (status) {
      'accepted' => (scheme.primary, 'Accepted'),
      'declined' => (scheme.error, 'Declined'),
      _ => (scheme.outline, 'Pending'),
    };
    return Chip(
      label: Text(label, style: TextStyle(color: color)),
      side: BorderSide(color: color),
      backgroundColor: Colors.transparent,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
    );
  }
}

class _ErrorState extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _ErrorState({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline,
                size: 40, color: Theme.of(context).colorScheme.error),
            const SizedBox(height: 12),
            Text('Could not load collaboration data',
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            FilledButton(onPressed: onRetry, child: const Text('Retry')),
          ],
        ),
      ),
    );
  }
}

class _EmptyCollabState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;

  const _EmptyCollabState({
    required this.icon,
    required this.title,
    required this.message,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 24),
      child: Column(
        children: [
          Icon(icon, size: 48, color: Theme.of(context).colorScheme.outline),
          const SizedBox(height: 16),
          Text(title, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          Text(message, textAlign: TextAlign.center),
        ],
      ),
    );
  }
}

class _CollabRequestDialog extends StatefulWidget {
  const _CollabRequestDialog();

  @override
  State<_CollabRequestDialog> createState() => _CollabRequestDialogState();
}

class _CollabRequestDialogState extends State<_CollabRequestDialog> {
  final _messageController = TextEditingController();

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Request collaboration'),
      content: TextField(
        controller: _messageController,
        maxLines: 3,
        decoration: const InputDecoration(
          hintText:
              'Short intro + what you are looking for (optional)',
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () =>
              Navigator.of(context).pop(_messageController.text.trim()),
          child: const Text('Send'),
        ),
      ],
    );
  }
}
