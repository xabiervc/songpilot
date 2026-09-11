/// Pure-Dart pitch detection from PCM16 audio.
///
/// Uses the Goertzel algorithm to measure energy at each MIDI note frequency
/// and aggregates per pitch class. Deliberately humble: it ranks notes by
/// measured energy and returns an empty list for silence/unpitched input
/// rather than guessing.
library pitch_detector;

import 'dart:math' as math;
import 'dart:typed_data';

import '../core/music_theory.dart';

/// One ranked pitch-class result.
class PitchClassScore {
  final String name;
  final double energy;

  const PitchClassScore(this.name, this.energy);

  @override
  String toString() => '$name($energy)';
}

const int _minMidi = 36; // C2
const int _maxMidi = 96; // C7

double _freqOf(int midi) =>
    (440.0 * math.pow(2.0, (midi - 69) / 12.0)).toDouble();

/// Goertzel power of `samples` at target frequency `freq` (Hz).
double _goertzelPower(List<double> samples, double freq, int sampleRate) {
  final n = samples.length;
  if (n == 0) return 0;
  final k = n * freq / sampleRate;
  final omega = 2 * math.pi * k / n;
  final coeff = 2 * math.cos(omega);
  var q0 = 0.0;
  var q1 = 0.0;
  var q2 = 0.0;
  for (final s in samples) {
    q0 = coeff * q1 - q2 + s;
    q2 = q1;
    q1 = q0;
  }
  final power = q1 * q1 + q2 * q2 - q0 * q1 * coeff;
  return power < 0 ? 0.0 : power;
}

/// Decode little-endian PCM16 into normalized [-1, 1] samples.
List<double> decodePcm16(Uint8List bytes) {
  final count = bytes.length ~/ 2;
  final view = ByteData.sublistView(bytes);
  return [
    for (var i = 0; i < count; i++)
      view.getInt16(i * 2, Endian.little) / 32768.0,
  ];
}

/// Ranks pitch classes found in a PCM16 mono buffer.
/// Returns up to [top] scores sorted by energy, or an empty list when the
/// signal carries no meaningful pitched energy.
List<PitchClassScore> detectTopNotes(
  List<double> samples,
  int sampleRate, {
  int top = 3,
}) {
  if (samples.length < sampleRate ~/ 4) return const []; // < ~250ms is noise

  // Per pitch class: strongest octave energy.
  final bestPerClass = List<double>.filled(12, 0);
  for (var midi = _minMidi; midi <= _maxMidi; midi++) {
    final power = _goertzelPower(samples, _freqOf(midi), sampleRate);
    final midiIndex = midi % 12;
    final midiClass = (9 + midiIndex) % 12; // MIDI 69 = A is index of 'A'
    if (power > bestPerClass[midiClass]) {
      bestPerClass[midiClass] = power;
    }
  }

  final peak = bestPerClass.reduce(math.max);
  if (peak <= 0) return const [];

  // Reject effectively silent buffers: keep only classes within 25% of peak.
  final floor = peak * 0.04;
  final scores = <PitchClassScore>[
    for (var c = 0; c < 12; c++)
      if (bestPerClass[c] >= floor)
        PitchClassScore(noteNames[c], bestPerClass[c]),
  ]..sort((a, b) => b.energy.compareTo(a.energy));

  return scores.take(top).toList();
}

/// Convenience: detect directly from a captured PCM16 LE buffer.
List<PitchClassScore> detectTopNotesFromBytes(
  Uint8List pcm16le,
  int sampleRate, {
  int top = 3,
}) =>
    detectTopNotes(decodePcm16(pcm16le), sampleRate, top: top);
