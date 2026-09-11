/// Thin wrapper around audioplayers for chord previews.
/// Usage: `await player.playChords(['C', 'F', 'G'])`.
library chord_preview_player;

import 'package:audioplayers/audioplayers.dart';

import 'wav_synth.dart';

class ChordPreviewPlayer {
  ChordPreviewPlayer();

  final AudioPlayer _player = AudioPlayer();

  /// Renders and plays the chord sequence. Safe to spam: a new play() call
  /// stops whatever is currently playing first.
  Future<void> playChords(List<String> chords) async {
    if (chords.isEmpty) return;
    final wav = synthesizeProgressionWav(chords);
    await _player.stop();
    await _player.play(BytesSource(wav));
  }

  Future<void> stop() => _player.stop();

  void dispose() {
    _player.dispose();
  }
}
