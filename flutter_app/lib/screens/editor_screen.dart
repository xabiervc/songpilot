import 'package:flutter/material.dart';

import '../core/music_theory.dart';
import '../core/suggestion_engine.dart';
import '../models/models.dart';
import '../services/supabase_service.dart';

/// Song editor: chord input + suggestion panel + Supabase persistence.
/// Suggestions come from the tested songpilot_core Dart logic
/// (music_theory.dart, suggestion_engine.dart).
class EditorScreen extends StatefulWidget {
  final String projectId;
  const EditorScreen({super.key, required this.projectId});

  @override
  State<EditorScreen> createState() => _EditorScreenState();
}

class _EditorScreenState extends State<EditorScreen> {
  late final TextEditingController _chordController;
  late final TextEditingController _titleController;
  late String _projectId;

  String _selectedKey = 'C';
  String _selectedStyle = 'rock';
  String _selectedMood = 'driving';
  List<Suggestion> _suggestions = [];
  String? _error;
  bool _saving = false;

  final List<String> _styles = ['rock', 'pop', 'blues', 'jazz', 'indie'];
  final List<String> _moods = [
    'driving',
    'uplifting',
    'laidback',
    'smooth',
    'melancholic',
    'bittersweet'
  ];
  final List<String> _keys = noteNames;

  @override
  void initState() {
    super.initState();
    _projectId = widget.projectId;
    _chordController = TextEditingController(text: 'C, F, G');
    _titleController = TextEditingController();
    _getSuggestions();
  }

  @override
  void dispose() {
    _chordController.dispose();
    _titleController.dispose();
    super.dispose();
  }

  List<String> get _parsedChords => _chordController.text
      .split(',')
      .map((c) => c.trim())
      .where((c) => c.isNotEmpty)
      .toList();

  void _getSuggestions() {
    setState(() {
      _error = null;
      try {
        _suggestions = suggestNext(
          key: _selectedKey,
          style: _selectedStyle,
          mood: _selectedMood,
        );
      } catch (e) {
        _error = e.toString();
        _suggestions = [];
      }
    });
  }

  Future<void> _saveProject() async {
    setState(() {
      _error = null;
      _saving = true;
    });
    try {
      final chords = _parsedChords;
      for (final chord in chords) {
        parseChord(chord); // validates; throws InvalidChordError on bad input
      }

      final title = _titleController.text.trim();
      final section = SongSection(
        sectionType: SectionType.verse,
        key: _selectedKey,
        chords: chords,
        barCount: chords.isEmpty ? 4 : chords.length,
      );
      final project = SongProject(
        projectId: _projectId == 'new' ? '' : _projectId,
        ownerId: '',
        title: title.isEmpty ? 'Untitled song' : title,
        key: _selectedKey,
        style: _selectedStyle,
        mood: _selectedMood,
        sections: [section],
      );

      final saved = await ProjectService().saveProject(project);
      if (!mounted) return;
      setState(() => _projectId = saved.projectId);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Song saved')),
      );
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Song: $_projectId'),
        actions: [
          IconButton(
            icon: const Icon(Icons.save_outlined),
            tooltip: 'Save song',
            onPressed: _saving ? null : _saveProject,
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(
            controller: _titleController,
            decoration: const InputDecoration(
              labelText: 'Song title',
              hintText: 'e.g. Midnight Groove',
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _chordController,
            decoration: const InputDecoration(
              labelText: 'Your idea (chords, comma separated)',
              hintText: 'e.g. Amaj7, C#m7, D, E',
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<String>(
                  initialValue: _selectedKey,
                  decoration: const InputDecoration(labelText: 'Key'),
                  items: _keys
                      .map((k) => DropdownMenuItem(value: k, child: Text(k)))
                      .toList(),
                  onChanged: (v) =>
                      setState(() => _selectedKey = v ?? _selectedKey),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: DropdownButtonFormField<String>(
                  initialValue: _selectedStyle,
                  decoration: const InputDecoration(labelText: 'Style'),
                  items: _styles
                      .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                      .toList(),
                  onChanged: (v) =>
                      setState(() => _selectedStyle = v ?? _selectedStyle),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: DropdownButtonFormField<String>(
                  initialValue: _selectedMood,
                  decoration: const InputDecoration(labelText: 'Mood'),
                  items: _moods
                      .map((m) => DropdownMenuItem(value: m, child: Text(m)))
                      .toList(),
                  onChanged: (v) =>
                      setState(() => _selectedMood = v ?? _selectedMood),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: _getSuggestions,
            icon: const Icon(Icons.auto_awesome),
            label: const Text('Suggest next'),
          ),
          const SizedBox(height: 24),
          if (_error != null)
            Text(_error!,
                style:
                    TextStyle(color: Theme.of(context).colorScheme.error)),
          Text('Suggestions', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 12),
          ..._suggestions.map((s) => _SuggestionCard(suggestion: s)),
        ],
      ),
    );
  }
}

class _SuggestionCard extends StatefulWidget {
  final Suggestion suggestion;
  const _SuggestionCard({required this.suggestion});

  @override
  State<_SuggestionCard> createState() => _SuggestionCardState();
}

class _SuggestionCardState extends State<_SuggestionCard> {
  bool _showTheory = false;

  @override
  Widget build(BuildContext context) {
    final s = widget.suggestion;
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: 8,
              children: s.chords.map((c) => Chip(label: Text(c))).toList(),
            ),
            const SizedBox(height: 8),
            Text('${s.style} · ${s.mood}',
                style: Theme.of(context).textTheme.labelMedium),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () => setState(() => _showTheory = !_showTheory),
              child: Text(_showTheory ? 'Hide theory' : 'Why this works?'),
            ),
            if (_showTheory) Text(s.explanation),
          ],
        ),
      ),
    );
  }
}
