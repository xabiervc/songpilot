import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../models/models.dart';
import '../services/supabase_service.dart';

/// Home dashboard: real list of the user's songs from Supabase, with
/// loading / empty / error states and pull-to-refresh.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<SongProject> _projects = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadProjects();
  }

  Future<void> _loadProjects() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final projects = await ProjectService().listMyProjects();
      if (mounted) {
        setState(() => _projects = projects);
      }
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

  String _subtitleFor(SongProject p) => '${p.key} · ${p.tempo} bpm · ${p.style}';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('SongPilot'),
        actions: [
          IconButton(
            icon: const Icon(Icons.person_outline),
            tooltip: 'Profile',
            onPressed: () => context.push('/profile'),
          ),
          IconButton(
            icon: const Icon(Icons.people_outline),
            tooltip: 'Collaborate',
            onPressed: () => context.push('/collab'),
          ),
        ],
      ),
      body: _buildBody(),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/editor/new'),
        icon: const Icon(Icons.add),
        label: const Text('New song'),
      ),
    );
  }

  Widget _buildBody() {
    if (_loading && _projects.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    return RefreshIndicator(
      onRefresh: _loadProjects,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('Your projects',
              style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 12),
          if (_error != null)
            Card(
              child: ListTile(
                leading: Icon(Icons.error_outline,
                    color: Theme.of(context).colorScheme.error),
                title: const Text('Could not load projects'),
                subtitle: Text(_error!),
                trailing: TextButton(
                  onPressed: _loadProjects,
                  child: const Text('Retry'),
                ),
              ),
            )
          else if (_projects.isEmpty)
            _EmptyProjectsState(
              onCreate: () => context.push('/editor/new'),
            )
          else
            ..._projects.map(
              (p) => Card(
                child: ListTile(
                  leading: const Icon(Icons.music_note_outlined),
                  title: Text(p.title),
                  subtitle: Text(_subtitleFor(p)),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => context.push('/editor/${p.projectId}'),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _EmptyProjectsState extends StatelessWidget {
  final VoidCallback onCreate;
  const _EmptyProjectsState({required this.onCreate});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 48),
      child: Column(
        children: [
          Icon(Icons.music_note_outlined,
              size: 48, color: Theme.of(context).colorScheme.outline),
          const SizedBox(height: 16),
          Text('No songs yet', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          Text(
            'Start a new song and let SongPilot suggest where to take it.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 16),
          FilledButton(
              onPressed: onCreate, child: const Text('Create your first song')),
        ],
      ),
    );
  }
}
