import 'package:flutter/material.dart';

/// Musician collaboration hub — NOT a dating UI.
/// Lists public collab-open projects and profiles looking for collaborators.
/// Supabase queries are stubbed with TODOs pending schema setup.
class CollabScreen extends StatelessWidget {
  const CollabScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Collaborate')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('Open to collaborate', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          Text(
            'Find musicians looking for bandmates, co-writers, or session players.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 24),
          // TODO: query `profiles` where open_to_collab = true
          // and `songs` where visibility = 'collab_open'
          const _EmptyCollabState(),
        ],
      ),
    );
  }
}

class _EmptyCollabState extends StatelessWidget {
  const _EmptyCollabState();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 48),
      child: Column(
        children: [
          Icon(Icons.groups_outlined,
              size: 48, color: Theme.of(context).colorScheme.outline),
          const SizedBox(height: 16),
          const Text('No collaborators found yet'),
          const SizedBox(height: 8),
          const Text(
            'Mark your profile as "open to collaborate" to appear here.',
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
