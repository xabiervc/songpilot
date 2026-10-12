import 'package:flutter/material.dart';

import '../services/supabase_service.dart';

class ModerationScreen extends StatefulWidget {
  const ModerationScreen({super.key});
  @override
  State<ModerationScreen> createState() => _ModerationScreenState();
}

class _ModerationScreenState extends State<ModerationScreen> {
  List<Map<String, dynamic>> _reports = const [];
  bool _loading = true;
  String? _error;

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final reports = await CommunitySafetyService().listReports(status: 'pending');
      if (mounted) setState(() => _reports = reports);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _setStatus(String id, String status) async {
    try {
      await CommunitySafetyService().updateReportStatus(id, status);
      await _load();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not update report: $e')));
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Moderation')),
    body: _loading
        ? const Center(child: CircularProgressIndicator())
        : _error != null
            ? Center(child: Column(mainAxisSize: MainAxisSize.min, children: [Text(_error!), FilledButton(onPressed: _load, child: const Text('Retry'))]))
            : RefreshIndicator(
                onRefresh: _load,
                child: ListView(padding: const EdgeInsets.all(16), children: [
                  if (_reports.isEmpty) const ListTile(title: Text('No pending reports')),
                  for (final report in _reports)
                    Card(child: ListTile(
                      title: Text(report['reported_user_id'] == null ? 'Reported song ${report['song_id']}' : 'Reported user ${report['reported_user_id']}'),
                      subtitle: Text('${report['reason']}\nReceived: ${report['created_at']}'),
                      isThreeLine: true,
                      trailing: PopupMenuButton<String>(
                        onSelected: (status) => _setStatus(report['id'] as String, status),
                        itemBuilder: (_) => const [
                          PopupMenuItem(value: 'reviewing', child: Text('Mark reviewing')),
                          PopupMenuItem(value: 'resolved', child: Text('Resolve')),
                          PopupMenuItem(value: 'dismissed', child: Text('Dismiss')),
                        ],
                      ),
                    )),
                ]),
              ),
  );
}
