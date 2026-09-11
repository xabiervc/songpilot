import 'package:flutter/material.dart';

/// Tap-to-append chord buttons for the current key.
/// Purely presentational: the parent decides where a tapped chord goes.
class ChordPalette extends StatelessWidget {
  final List<String> chords;
  final ValueChanged<String> onChordTap;

  const ChordPalette({
    super.key,
    required this.chords,
    required this.onChordTap,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Chord palette', style: Theme.of(context).textTheme.labelLarge),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final chord in chords)
              ActionChip(
                label: Text(chord),
                onPressed: () => onChordTap(chord),
              ),
          ],
        ),
      ],
    );
  }
}
