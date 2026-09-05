import 'package:flutter/material.dart';
import '../main.dart';

/// Profile & settings: instruments, genres, collaboration preferences,
/// plan status. Fields persist to the `profiles` table (TODO: wire up).
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  bool _openToCollab = false;

  Future<void> _signOut() async {
    await supabase.auth.signOut();
  }

  @override
  Widget build(BuildContext context) {
    final user = supabase.auth.currentUser;
    return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(user?.email ?? 'Not signed in',
              style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 24),
          SwitchListTile(
            title: const Text('Open to collaboration'),
            subtitle: const Text('Let other musicians find and message you'),
            value: _openToCollab,
            onChanged: (v) => setState(() => _openToCollab = v),
          ),
          const Divider(),
          const ListTile(
            title: Text('Plan'),
            subtitle: Text('Free'),
            trailing: Chip(label: Text('Upgrade to Pro')),
          ),
          const SizedBox(height: 24),
          OutlinedButton(onPressed: _signOut, child: const Text('Log out')),
        ],
      ),
    );
  }
}
