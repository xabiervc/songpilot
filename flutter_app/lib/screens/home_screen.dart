import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../main.dart';

/// Home dashboard: recent projects + quick actions.
/// Project data fetching from Supabase is stubbed with TODOs — wire up
/// the `songs` table query once your schema is created.
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('SongPilot'),
        actions: [
          IconButton(
            icon: const Icon(Icons.person_outline),
            onPressed: () => context.push('/profile'),
          ),
          IconButton(
            icon: const Icon(Icons.people_outline),
            onPressed: () => context.push('/collab'),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('Your projects', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 12),
          // TODO: replace with a real query:
          // await supabase.from('songs').select().eq('owner_id', supabase.auth.currentUser!.id)
          _EmptyProjectsState(
            onCreate: () => context.push('/editor/new'),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/editor/new'),
        icon: const Icon(Icons.add),
        label: const Text('New song'),
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
          FilledButton(onPressed: onCreate, child: const Text('Create your first song')),
        ],
      ),
    );
  }
}
