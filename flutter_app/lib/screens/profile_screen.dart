import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../main.dart';
import '../services/supabase_service.dart';

const privacyPolicyUrl = String.fromEnvironment(
  'PRIVACY_POLICY_URL',
  defaultValue: '',
);

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});
  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  bool _openToCollab = false;
  bool _saving = false;
  bool _requestingDeletion = false;
  bool _exporting = false;
  String? _deletionStatus;

  @override
  void initState() {
    super.initState();
    _loadProfile();
    _loadDeletionStatus();
  }

  Future<void> _loadDeletionStatus() async {
    try {
      final status = await AccountService().deletionRequestStatus();
      if (mounted) setState(() => _deletionStatus = status);
    } catch (_) {}
  }

  Future<void> _loadProfile() async {
    final userId = supabase.auth.currentUser?.id;
    if (userId == null) return;
    try {
      final profile = await ProfileService().getProfile(userId);
      if (profile != null && mounted) setState(() => _openToCollab = profile.openToCollab);
    } catch (_) {}
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
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not save preference: $e')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _exportData() async {
    setState(() => _exporting = true);
    try {
      final data = await AccountService().exportMyData();
      final json = const JsonEncoder.withIndent('  ').convert(data);
      await Clipboard.setData(ClipboardData(text: json));
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Your data export was copied as JSON.')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not export data: $e')));
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  Future<void> _requestAccountDeletion() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Request account deletion?'),
        content: const Text('Your request will be queued for secure processing. The account is not deleted instantly.'),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('Request deletion')),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _requestingDeletion = true);
    try {
      await AccountService().requestAccountDeletion();
      await _loadDeletionStatus();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Deletion request received.')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not request deletion: $e')));
    } finally {
      if (mounted) setState(() => _requestingDeletion = false);
    }
  }

  Future<void> _signOut() async => supabase.auth.signOut();

  @override
  Widget build(BuildContext context) {
    final user = supabase.auth.currentUser;
    return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        Text(user?.email ?? 'Not signed in', style: Theme.of(context).textTheme.titleMedium),
        if (_saving || _requestingDeletion || _exporting) const LinearProgressIndicator(),
        const SizedBox(height: 24),
        SwitchListTile(title: const Text('Open to collaboration'), subtitle: const Text('Let other musicians find and message you'), value: _openToCollab, onChanged: _saving ? null : _toggleCollab),
        const Divider(),
        const ListTile(title: Text('Plan'), subtitle: Text('Free'), trailing: Chip(label: Text('Upgrade to Pro'))),
        const SizedBox(height: 24),
        Text('Privacy & account', style: Theme.of(context).textTheme.titleMedium),
        ListTile(leading: const Icon(Icons.download_outlined), title: const Text('Export my data'), onTap: _exporting ? null : _exportData),
        if (privacyPolicyUrl.startsWith('https://'))
          ListTile(leading: const Icon(Icons.privacy_tip_outlined), title: const Text('Privacy policy'), subtitle: Text(privacyPolicyUrl), onTap: () => Clipboard.setData(ClipboardData(text: privacyPolicyUrl))),
        ListTile(leading: const Icon(Icons.delete_outline), title: const Text('Request account deletion'), subtitle: Text(_deletionStatus == null ? 'No open request' : 'Request status: $_deletionStatus'), enabled: !_requestingDeletion, onTap: _requestingDeletion ? null : _requestAccountDeletion),
        const SizedBox(height: 24),
        OutlinedButton(onPressed: _signOut, child: const Text('Log out')),
      ]),
    );
  }
}
