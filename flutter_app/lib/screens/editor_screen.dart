import 'package:flutter/material.dart';
import '../core/suggestion_engine.dart';
import '../core/music_theory.dart';

/// Song editor: chord timeline + suggestion panel.
/// This wires directly to the tested songpilot_core Dart logic
/// (music_theory.dart, suggestion_engine.dart) for suggestions.
class EditorScreen extends StatefulWidget {
  final String projectId;
  const EditorScreen({super.key, required this.projectId});

  @override
  State<EditorScreen> createState() => _EditorScreenState();
}

class _EditorScreenState extends State<EditorScreen> {
  final _chordController = TextEditingController(text: 'C, F, G');
  String _selectedKey = 'C';
  String _selectedStyle = 'rock';
  String _selectedMood = 'driving';
  List<Suggestion> _suggestions = [];
  String? _error;

  final List<String> _styles = ['rock', 'pop', 'blues', 'jazz', 'indie'];
  final List<String> _moods = [
    'driving', 'uplifting', 'laidback', 'smooth', 'melancholic', 'bittersweet'
  ];
  final List<String> _keys = noteNames;

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

  @override
  void initState() {
    super.initState();
    _getSuggestions();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Song: ${widget.projectId}')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
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
                  onChanged: (v) => setState(() => _selectedKey = v ?? _selectedKey),
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
                  onChanged: (v) => setState(() => _selectedStyle = v ?? _selectedStyle),
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
                  onChanged: (v) => setState(() => _selectedMood = v ?? _selectedMood),
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
            Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
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
              children: s.chords
                  .map((c) => Chip(label: Text(c)))
                  .toList(),
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
