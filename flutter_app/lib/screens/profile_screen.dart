import 'package:flutter/material.dart';

import '../main.dart';
import '../services/supabase_service.dart';

/// Profile & settings. The "open to collaboration" preference is loaded from
/// and persisted to the `profiles` table; other fields land in later slices.
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  bool _openToCollab = false;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    final userId = supabase.auth.currentUser?.id;
    if (userId == null) return;
    try {
      final profile = await ProfileService().getProfile(userId);
      if (profile != null && mounted) {
        setState(() => _openToCollab = profile.openToCollab);
      }
    } catch (_) {
      // No profile row yet or network issue; defaults are fine.
    }
  }

  Future<void> _toggleCollab(bool value) async {
    final previous = _openToCollab;
    setState(() => _openToCollab = value);

    final userId = supabase.auth.currentUser?.id;
    if (userId == null) return;

    setState(() => _saving = true);
    try {
      await ProfileService().setOpenToCollab(userId, value);
    } catch (e) {
      if (!mounted) return;
      setState(() => _openToCollab = previous);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not save preference: $e')),
      );
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

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
          if (_saving) const LinearProgressIndicator(),
          const SizedBox(height: 24),
          SwitchListTile(
            title: const Text('Open to collaboration'),
            subtitle:
                const Text('Let other musicians find and message you'),
            value: _openToCollab,
            onChanged: _saving ? null : _toggleCollab,
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
