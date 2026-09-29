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
  bool _requestingDeletion = false;

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

  Future<void> _requestAccountDeletion() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Request account deletion?'),
        content: const Text(
          'We will begin deleting your SongPilot account and associated data '
          'after securely processing this request. This action cannot be undone '
          'once completed.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
              foregroundColor: Theme.of(context).colorScheme.onError,
            ),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Request deletion'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    setState(() => _requestingDeletion = true);
    try {
      await AccountService().requestAccountDeletion();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Your deletion request was received. We will notify you when it is processed.',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not request account deletion: $e')),
      );
    } finally {
      if (mounted) setState(() => _requestingDeletion = false);
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
          if (_saving || _requestingDeletion) const LinearProgressIndicator(),
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
          Text('Account', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          ListTile(
            leading: Icon(
              Icons.delete_outline,
              color: Theme.of(context).colorScheme.error,
            ),
            title: const Text('Request account deletion'),
            subtitle: const Text(
              'Permanently delete your account and associated data',
            ),
            enabled: !_requestingDeletion,
            onTap: _requestingDeletion ? null : _requestAccountDeletion,
          ),
          const SizedBox(height: 24),
          OutlinedButton(onPressed: _signOut, child: const Text('Log out')),
        ],
      ),
    );
  }
}
