import 'dart:async';

import 'package:flutter/material.dart';

import '../audio/chord_preview_player.dart';
import '../audio/mic_note_listener.dart';
import '../audio/wav_synth.dart';
import '../core/chord_shapes.dart';
import '../core/music_theory.dart';
import '../core/song_form.dart';
import '../core/suggestion_engine.dart';
import '../core/tab_shapes.dart';
import '../dsp/pitch_detector.dart';
import '../models/models.dart';
import '../services/supabase_service.dart';
import '../widgets/chord_palette.dart';

/// Song editor: multi-section arrangement + chord palette + tabs editor +
/// microphone note capture + audio preview + suggestions + persistence.
class EditorScreen extends StatefulWidget {
  final String projectId;
  const EditorScreen({super.key, required this.projectId});

  @override
  State<EditorScreen> createState() => _EditorScreenState();
}

/// Editable draft for one section in the arrangement.
class _SectionDraft {
  _SectionDraft({
    required this.sectionType,
    String chordsText = '',
    String tabs = '',
    this.barCount = 4,
  })  : chordsController = TextEditingController(text: chordsText),
        tabsController = TextEditingController(text: tabs);

  SectionType sectionType;
  final TextEditingController chordsController;
  final TextEditingController tabsController;
  int barCount;

  void dispose() {
    chordsController.dispose();
    tabsController.dispose();
  }

  List<String> get parsedChords => chordsController.text
      .split(',')
      .map((c) => c.trim())
      .where((c) => c.isNotEmpty)
      .toList();

  SongSection toSection(String key) => SongSection(
        sectionType: sectionType,
        key: key,
        chords: parsedChords,
        barCount: barCount,
        tabs: tabsController.text,
      );
}

class _EditorScreenState extends State<EditorScreen> {
  late final TextEditingController _titleController;
  late String _projectId;

  final ChordPreviewPlayer _previewPlayer = ChordPreviewPlayer();
  final MicNoteListener _micListener = MicNoteListener();
  Timer? _recordTimer;

  String _selectedKey = 'C';
  String _selectedStyle = 'rock';
  String _selectedMood = 'driving';
  List<Suggestion> _suggestions = [];
  List<_SectionDraft> _sections = [];
  int _activeSectionIndex = 0;
  String? _error;
  bool _saving = false;
  bool _loading = false;
  bool _previewingAll = false;
  bool _recording = false;
  bool _naturalSound = false;

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
    _titleController = TextEditingController();
    _sections = [_SectionDraft(sectionType: SectionType.verse)];
    _getSuggestions();
    _loadProject();
  }

  @override
  void dispose() {
    _recordTimer?.cancel();
    _titleController.dispose();
    for (final draft in _sections) {
      draft.dispose();
    }
    _previewPlayer.dispose();
    _micListener.dispose();
    super.dispose();
  }

  Future<void> _loadProject() async {
    if (_projectId == 'new') return;
    setState(() => _loading = true);
    try {
      final project = await ProjectService().getProject(_projectId);
      if (!mounted) return;
      if (project == null) {
        setState(() => _error = 'Song not found.');
        return;
      }
      setState(() {
        for (final draft in _sections) {
          draft.dispose();
        }
        _titleController.text = project.title;
        _selectedKey = project.key;
        _selectedStyle = project.style;
        _selectedMood = project.mood;
        _sections = project.sections.isEmpty
            ? [_SectionDraft(sectionType: SectionType.verse)]
            : [
                for (final s in project.sections)
                  _SectionDraft(
                    sectionType: s.sectionType,
                    chordsText: s.chords.join(', '),
                    tabs: s.tabs,
                    barCount: s.barCount,
                  ),
              ];
      });
      _getSuggestions();
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

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

  int get _totalBars => _sections.fold(0, (sum, d) => sum + d.barCount);

  void _markSectionActive(int index) {
    _activeSectionIndex = index;
  }

  void _appendChord(String chord) {
    if (_sections.isEmpty) return;
    var index = _activeSectionIndex;
    if (index < 0 || index >= _sections.length) index = _sections.length - 1;
    final draft = _sections[index];
    final current = draft.chordsController.text.trimRight();
    final next = current.isEmpty ? chord : '$current, $chord';
    draft.chordsController
      ..text = next
      ..selection = TextSelection.collapsed(offset: next.length);
  }

  void _generateTabsForSection(int index) {
    if (index < 0 || index >= _sections.length) return;
    final chords = _sections[index].parsedChords;
    if (chords.isEmpty) return;
    setState(() {
      _sections[index].tabsController.text = tabsForProgression(chords);
    });
  }

  void _addSection() {
    setState(() =>
        _sections.add(_SectionDraft(sectionType: SectionType.verse)));
  }

  void _removeSection(int index) {
    if (_sections.length <= 1) return;
    setState(() {
      final removed = _sections.removeAt(index);
      removed.dispose();
      if (_activeSectionIndex >= _sections.length) {
        _activeSectionIndex = _sections.length - 1;
      }
    });
  }

  void _moveSection(int index, int delta) {
    final targetIndex = index + delta;
    if (targetIndex < 0 || targetIndex >= _sections.length) return;
    setState(() {
      final item = _sections.removeAt(index);
      _sections.insert(targetIndex, item);
    });
  }

  void _changeBars(int index, int delta) {
    setState(() {
      final next = _sections[index].barCount + delta;
      if (next >= 1 && next <= 64) {
        _sections[index].barCount = next;
      }
    });
  }

  void _applySuggestion(Suggestion s) {
    final lastType =
        _sections.isEmpty ? SectionType.verse : _sections.last.sectionType;
    setState(() {
      _sections.add(
        _SectionDraft(
          sectionType: nextSectionAfter(lastType),
          chordsText: s.chords.join(', '),
          barCount: s.chords.length,
        ),
      );
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Suggestion added to arrangement')),
    );
  }

  void _toggleNaturalSound() {
    setState(() => _naturalSound = !_naturalSound);
    _previewPlayer.tone =
        _naturalSound ? SynthTone.plucked : SynthTone.pure;
  }

  Future<void> _previewSection(int index) async {
    if (index < 0 || index >= _sections.length) return;
    await _previewPlayer.playChords(_sections[index].parsedChords);
  }

  Future<void> _togglePreviewAll() async {
    if (_previewingAll) {
      await _previewPlayer.stop();
      if (mounted) setState(() => _previewingAll = false);
      return;
    }
    final chords = [for (final d in _sections) ...d.parsedChords];
    if (chords.isEmpty) return;
    setState(() => _previewingAll = true);
    await _previewPlayer.playChords(chords);
    if (mounted) setState(() => _previewingAll = false);
  }

  Future<void> _toggleRecording() async {
    if (_recording) {
      _recordTimer?.cancel();
      final bytes = await _micListener.stopAndCollect();
      if (!mounted) return;
      setState(() => _recording = false);
      final detected = detectTopNotesFromBytes(
        bytes,
        MicNoteListener.sampleRate,
      );
      if (!mounted) return;
      _showDetectedNotes(detected);
      return;
    }

    final started = await _micListener.start();
    if (!mounted) return;
    if (!started) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Microphone permission needed to capture notes')),
      );
      return;
    }
    setState(() => _recording = true);
    _recordTimer = Timer(MicNoteListener.maxWindow, () {
      if (_recording) _toggleRecording();
    });
  }

  void _showDetectedNotes(List<PitchClassScore> notes) {
    showModalBottomSheet<void>(
      context: context,
      builder: (sheetContext) {
        return Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Detected notes',
                  style: Theme.of(sheetContext).textTheme.titleMedium),
              const SizedBox(height: 8),
              if (notes.isEmpty)
                const Text(
                    "Couldn't pick out a clear note — try a louder, steadier sound.")
              else ...[
                Text(
                  'Tap to add as a chord to the active section:',
                  style: Theme.of(sheetContext).textTheme.bodyMedium,
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final n in notes)
                      ActionChip(
                        label: Text(n.name),
                        onPressed: () {
                          _appendChord(n.name);
                          Navigator.of(sheetContext).pop();
                        },
                      ),
                  ],
                ),
              ],
              const SizedBox(height: 12),
            ],
          ),
        );
      },
    );
  }

  Future<void> _saveProject() async {
    setState(() {
      _error = null;
      _saving = true;
    });
    try {
      for (final draft in _sections) {
        for (final chord in draft.parsedChords) {
          parseChord(chord); // validates; throws InvalidChordError on bad input
        }
      }

      final title = _titleController.text.trim();
      final project = SongProject(
        projectId: _projectId == 'new' ? '' : _projectId,
        ownerId: '',
        title: title.isEmpty ? 'Untitled song' : title,
        key: _selectedKey,
        style: _selectedStyle,
        mood: _selectedMood,
        sections: [
          for (final d in _sections) d.toSection(_selectedKey),
        ],
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
        title: const Text('Song editor'),
        actions: [
          IconButton(
            icon: Icon(_naturalSound
                ? Icons.graphic_eq
                : Icons.music_note_outlined),
            tooltip: _naturalSound
                ? 'Natural pluck sound: on'
                : 'Natural pluck sound: off',
            onPressed: _toggleNaturalSound,
          ),
          if (_saving)
            const Padding(
              padding: EdgeInsets.only(right: 8),
              child: CircularProgressIndicator(),
            )
          else
            IconButton(
              icon: const Icon(Icons.save_outlined),
              tooltip: 'Save song',
              onPressed: _saving || _loading ? null : _saveProject,
            ),
        ],
      ),
      body: _loading && _sections.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                TextField(
                  controller: _titleController,
                  decoration: const InputDecoration(
                    labelText: 'Song title',
                    hintText: 'e.g. Midnight Groove',
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
                            .map((k) =>
                                DropdownMenuItem(value: k, child: Text(k)))
                            .toList(),
                        onChanged: (v) => setState(
                            () => _selectedKey = v ?? _selectedKey),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        initialValue: _selectedStyle,
                        decoration: const InputDecoration(labelText: 'Style'),
                        items: _styles
                            .map((s) =>
                                DropdownMenuItem(value: s, child: Text(s)))
                            .toList(),
                        onChanged: (v) => setState(
                            () => _selectedStyle = v ?? _selectedStyle),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        initialValue: _selectedMood,
                        decoration: const InputDecoration(labelText: 'Mood'),
                        items: _moods
                            .map((m) =>
                                DropdownMenuItem(value: m, child: Text(m)))
                            .toList(),
                        onChanged: (v) => setState(
                            () => _selectedMood = v ?? _selectedMood),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: ChordPalette(
                        chords: paletteChords(_selectedKey),
                        onChordTap: _appendChord,
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      icon: Icon(
                        _recording ? Icons.stop_circle : Icons.mic_outlined,
                        color: _recording
                            ? Theme.of(context).colorScheme.error
                            : null,
                      ),
                      tooltip: _recording
                          ? 'Stop and detect notes'
                          : 'Capture notes with microphone',
                      onPressed: _toggleRecording,
                    ),
                  ],
                ),
                if (_recording)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text('Recording… tap the mic again to analyze',
                        style: TextStyle(
                            color: Theme.of(context).colorScheme.error)),
                  ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Text('Arrangement',
                        style: Theme.of(context).textTheme.titleLarge),
                    const Spacer(),
                    IconButton(
                      icon: Icon(_previewingAll
                          ? Icons.stop_circle_outlined
                          : Icons.play_circle_outline),
                      tooltip: 'Preview arrangement',
                      onPressed: _togglePreviewAll,
                    ),
                    Text('$_totalBars bars',
                        style: Theme.of(context).textTheme.labelMedium),
                  ],
                ),
                const SizedBox(height: 12),
                if (_sections.isEmpty)
                  const _EmptyArrangementState()
                else
                  ...[
                    for (var i = 0; i < _sections.length; i++)
                      _SectionCard(
                        index: i,
                        draft: _sections[i],
                        totalSections: _sections.length,
                        isActive: i == _activeSectionIndex,
                        onFieldFocus: () => _markSectionActive(i),
                        onPreview: () => _previewSection(i),
                        onGenerateTabs: () => _generateTabsForSection(i),
                        onRemove: () => _removeSection(i),
                        onMoveUp: () => _moveSection(i, -1),
                        onMoveDown: () => _moveSection(i, 1),
                        onBarsChanged: (d) => _changeBars(i, d),
                      ),
                  ],
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: _addSection,
                  icon: const Icon(Icons.add),
                  label: const Text('Add section'),
                ),
                const SizedBox(height: 16),
                OutlinedButton.icon(
                  onPressed: _saving || _loading ? null : _saveProject,
                  icon: const Icon(Icons.save_outlined),
                  label: const Text('Save song'),
                ),
                const SizedBox(height: 24),
                Text('Suggestions',
                    style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 8),
                FilledButton.icon(
                  onPressed: _getSuggestions,
                  icon: const Icon(Icons.auto_awesome),
                  label: const Text('Suggest next'),
                ),
                const SizedBox(height: 12),
                if (_error != null)
                  Text(_error!,
                      style: TextStyle(
                          color: Theme.of(context).colorScheme.error)),
                if (_suggestions.isEmpty)
                  const _EmptySuggestionsState()
                else
                  ..._suggestions.map(
                    (s) => _SuggestionCard(
                      suggestion: s,
                      onApply: () => _applySuggestion(s),
                      onPreview: () => _previewPlayer.playChords(s.chords),
                    ),
                  ),
              ],
            ),
    );
  }
}

class _EmptyArrangementState extends StatelessWidget {
  const _EmptyArrangementState();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Column(
        children: [
          Icon(Icons.queue_music_outlined,
              size: 48, color: Theme.of(context).colorScheme.outline),
          const SizedBox(height: 12),
          const Text('No sections yet'),
          const SizedBox(height: 4),
          const Text('Add your first verse or apply a suggestion below.'),
        ],
      ),
    );
  }
}

class _EmptySuggestionsState extends StatelessWidget {
  const _EmptySuggestionsState();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Column(
        children: [
          Icon(Icons.auto_awesome_outlined,
              size: 48, color: Theme.of(context).colorScheme.outline),
          const SizedBox(height: 12),
          const Text('No suggestions yet'),
          const SizedBox(height: 4),
          const Text(
              'Tap "Suggest next" for starter chords, styles, and theory.'),
        ],
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  final int index;
  final _SectionDraft draft;
  final int totalSections;
  final bool isActive;
  final VoidCallback onFieldFocus;
  final VoidCallback onPreview;
  final VoidCallback onGenerateTabs;
  final VoidCallback onRemove;
  final VoidCallback onMoveUp;
  final VoidCallback onMoveDown;
  final ValueChanged<int> onBarsChanged;

  const _SectionCard({
    required this.index,
    required this.draft,
    required this.totalSections,
    required this.isActive,
    required this.onFieldFocus,
    required this.onPreview,
    required this.onGenerateTabs,
    required this.onRemove,
    required this.onMoveUp,
    required this.onMoveDown,
    required this.onBarsChanged,
  });

  @override
  Widget build(BuildContext context) {
    final typeOptions = SectionType.values;
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: isActive
          ? RoundedRectangleBorder(
              side: BorderSide(color: Theme.of(context).colorScheme.primary),
              borderRadius: BorderRadius.circular(12),
            )
          : null,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text('${index + 1}',
                    style: Theme.of(context).textTheme.titleSmall),
                const SizedBox(width: 12),
                Expanded(
                  child: DropdownButtonFormField<SectionType>(
                    initialValue: draft.sectionType,
                    decoration: const InputDecoration(
                      labelText: 'Section',
                      isDense: true,
                    ),
                    items: typeOptions
                        .map((t) => DropdownMenuItem(
                              value: t,
                              child: Text(sectionTypeLabels[t] ?? t.name),
                            ))
                        .toList(),
                    onChanged: (t) => draft.sectionType = t ?? draft.sectionType,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            TextField(
              controller: draft.chordsController,
              onTap: onFieldFocus,
              onChanged: (_) => onFieldFocus(),
              decoration: const InputDecoration(
                labelText: 'Chords (comma separated)',
                hintText: 'e.g. Am, G, F, E',
                isDense: true,
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                const Text('Bars'),
                IconButton(
                  icon: const Icon(Icons.remove),
                  tooltip: 'Fewer bars',
                  onPressed: draft.barCount <= 1
                      ? null
                      : () => onBarsChanged(-1),
                ),
                Text('${draft.barCount}'),
                IconButton(
                  icon: const Icon(Icons.add),
                  tooltip: 'More bars',
                  onPressed: draft.barCount >= 64
                      ? null
                      : () => onBarsChanged(1),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.play_arrow),
                  tooltip: 'Preview section',
                  onPressed: onPreview,
                ),
                IconButton(
                  icon: const Icon(Icons.arrow_upward),
                  tooltip: 'Move up',
                  onPressed: index > 0 ? onMoveUp : null,
                ),
                IconButton(
                  icon: const Icon(Icons.arrow_downward),
                  tooltip: 'Move down',
                  onPressed: index < totalSections - 1 ? onMoveDown : null,
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline),
                  tooltip: 'Remove section',
                  onPressed: totalSections > 1 ? onRemove : null,
                ),
              ],
            ),
            ExpansionTile(
              title: Text('Tabs (guitar)',
                  style: Theme.of(context).textTheme.labelLarge),
              tilePadding: EdgeInsets.zero,
              childrenPadding: EdgeInsets.zero,
              children: [
                Align(
                  alignment: Alignment.centerLeft,
                  child: FilledButton.tonalIcon(
                    onPressed: onGenerateTabs,
                    icon: const Icon(Icons.auto_fix_high),
                    label: const Text('Generate from chords'),
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: draft.tabsController,
                  maxLines: 6,
                  minLines: 6,
                  style: const TextStyle(
                      fontFamily: 'monospace', fontSize: 13),
                  decoration: const InputDecoration(
                    hintText: 'e|--0--|\nB|--1--|\nG|--0--|\nD|--2--|\nA|--3--|\nE|-----|',
                    isDense: true,
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _SuggestionCard extends StatefulWidget {
  final Suggestion suggestion;
  final VoidCallback onApply;
  final VoidCallback onPreview;

  const _SuggestionCard({
    required this.suggestion,
    required this.onApply,
    required this.onPreview,
  });

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
            Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.play_circle_outline),
                  tooltip: 'Preview suggestion',
                  onPressed: widget.onPreview,
                ),
                TextButton(
                  onPressed: () =>
                      setState(() => _showTheory = !_showTheory),
                  child: Text(_showTheory ? 'Hide theory' : 'Why this works?'),
                ),
                const Spacer(),
                TextButton.icon(
                  onPressed: widget.onApply,
                  icon: const Icon(Icons.add),
                  label: const Text('Add to arrangement'),
                ),
              ],
            ),
            if (_showTheory) Text(s.explanation),
          ],
        ),
      ),
    );
  }
}
