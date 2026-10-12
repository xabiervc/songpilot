import 'dart:convert';
import 'dart:html' as html;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../main.dart';
import '../services/supabase_service.dart';

const privacyPolicyUrl = String.fromEnvironment('PRIVACY_POLICY_URL', defaultValue: '');

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});
  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  bool _openToCollab = false;
  bool _saving = false;
  bool _busy = false;
  String? _deletionStatus;

  @override
  void initState() {
    super.initState();
    _loadProfile();
    _loadDeletionStatus();
  }

  Future<void> _loadProfile() async {
    final id = supabase.auth.currentUser?.id;
    if (id == null) return;
    try {
      final profile = await ProfileService().getProfile(id);
      if (profile != null && mounted) setState(() => _openToCollab = profile.openToCollab);
    } catch (_) {}
  }

  Future<void> _loadDeletionStatus() async {
    try {
      final status = await AccountService().deletionRequestStatus();
      if (mounted) setState(() => _deletionStatus = status);
    } catch (_) {}
  }

  Future<void> _toggleCollab(bool value) async {
    final old = _openToCollab;
    setState(() { _openToCollab = value; _saving = true; });
    try {
      final id = supabase.auth.currentUser?.id;
      if (id == null) throw StateError('Please sign in again.');
      await ProfileService().setOpenToCollab(id, value);
    } catch (e) {
      if (mounted) {
        setState(() => _openToCollab = old);
        _showMessage('Could not save preference: $e');
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _showMessage(String message) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));

  Future<void> _exportData() async {
    setState(() => _busy = true);
    try {
      final data = await AccountService().exportMyData();
      final json = const JsonEncoder.withIndent('  ').convert(data);
      if (kIsWeb) {
        final bytes = utf8.encode(json);
        final blob = html.Blob([bytes], 'application/json');
        final url = html.Url.createObjectUrlFromBlob(blob);
        html.AnchorElement(href: url)
          ..setAttribute('download', 'songpilot-data-export.json')
          ..click();
        html.Url.revokeObjectUrl(url);
      } else {
        await Clipboard.setData(ClipboardData(text: json));
      }
      if (mounted) _showMessage(kIsWeb ? 'Data export downloaded.' : 'Data export copied as JSON.');
    } catch (e) {
      if (mounted) _showMessage('Could not export data: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _requestDeletion() async {
    final ok = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(
      title: const Text('Request account deletion?'),
      content: const Text('This sends a request for secure processing; your account is not deleted instantly.'),
      actions: [TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')), FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Request deletion'))],
    ));
    if (ok != true) return;
    setState(() => _busy = true);
    try {
      await AccountService().requestAccountDeletion();
      await _loadDeletionStatus();
      if (mounted) _showMessage('Deletion request submitted.');
    } catch (e) {
      if (mounted) _showMessage('Could not request deletion: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _openPrivacyPolicy() async {
    if (!privacyPolicyUrl.startsWith('https://')) {
      _showMessage('Privacy policy URL has not been configured yet.');
      return;
    }
    final uri = Uri.tryParse(privacyPolicyUrl);
    if (uri == null || !await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      if (mounted) _showMessage('Could not open privacy policy.');
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
        if (_saving || _busy) const LinearProgressIndicator(),
        const SizedBox(height: 24),
        SwitchListTile(title: const Text('Open to collaboration'), subtitle: const Text('Let other musicians find and message you'), value: _openToCollab, onChanged: _saving ? null : _toggleCollab),
        const Divider(),
        const ListTile(title: Text('Plan'), subtitle: Text('Free'), trailing: Chip(label: Text('Upgrade to Pro'))),
        const SizedBox(height: 24),
        Text('Privacy & account', style: Theme.of(context).textTheme.titleMedium),
        ListTile(leading: const Icon(Icons.download_outlined), title: const Text('Export my data'), onTap: _busy ? null : _exportData),
        ListTile(leading: const Icon(Icons.privacy_tip_outlined), title: const Text('Privacy policy'), subtitle: Text(privacyPolicyUrl.isEmpty ? 'Not configured' : privacyPolicyUrl), onTap: _openPrivacyPolicy),
        ListTile(leading: const Icon(Icons.delete_outline), title: const Text('Request account deletion'), subtitle: Text(_deletionStatus == null ? 'No request found' : 'Status: $_deletionStatus'), enabled: !_busy, onTap: _busy ? null : _requestDeletion),
        const SizedBox(height: 24),
        OutlinedButton(onPressed: _signOut, child: const Text('Log out')),
      ]),
    );
  }
}
