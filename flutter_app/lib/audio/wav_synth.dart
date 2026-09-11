/// Pure-Dart WAV synthesizer for chord previews.
///
/// Two tones:
///  - [SynthTone.pure]: summed sine waves (with a bass root an octave down).
///  - [SynthTone.plucked]: Karplus-Strong plucked-string model per note,
///    a much more guitar-like color with no audio assets required.
library wav_synth;

import 'dart:math' as math;
import 'dart:typed_data';

import '../core/music_theory.dart';

const int defaultSampleRate = 22050;

enum SynthTone { pure, plucked }

/// Frequency of a MIDI note number (A4 = 69 = 440 Hz).
double midiToFreq(int midiNote) =>
    (440.0 * math.pow(2.0, (midiNote - 69) / 12.0)).toDouble();

int _rootIndexOf(String note) => noteNames.indexOf(normalizeNote(note));

List<int> _intervalsFor(String quality) => switch (quality) {
      'm' || 'min' => const [0, 3, 7],
      'maj7' => const [0, 4, 7, 11],
      'm7' => const [0, 3, 7, 10],
      '7' => const [0, 4, 7, 10],
      'dim' => const [0, 3, 6],
      'sus4' => const [0, 5, 7],
      'sus2' => const [0, 2, 7],
      _ => const [0, 4, 7],
    };

/// MIDI notes for a chord name: bass root (one octave down) plus the voiced
/// triad/seventh around C3 (MIDI 48) so previews sit in a comfortable range.
List<int> chordToMidis(String chord, {int baseMidi = 48}) {
  final parts = parseChord(chord);
  final rootMidi = baseMidi + _rootIndexOf(parts.root);
  return [
    rootMidi - 12,
    for (final interval in _intervalsFor(parts.quality)) rootMidi + interval,
  ];
}

double _envelope(int frame, int totalFrames, int sampleRate) {
  final attack = (0.01 * sampleRate).round();
  final release = (0.1 * sampleRate).round();
  if (attack > 0 && frame < attack) return frame / attack;
  final remaining = totalFrames - frame;
  if (release > 0 && remaining < release) {
    final r = remaining / release;
    return r < 0 ? 0.0 : (r > 1.0 ? 1.0 : r);
  }
  return 1.0;
}

/// Karplus-Strong plucked string into `out` starting at `offset`.
/// Deterministic: the excitation noise is seeded from the frequency.
void _pluckedInto(
  Float64List out,
  int offset,
  double frequency, {
  required int frames,
  required int sampleRate,
  required double gain,
}) {
  final periodRaw = sampleRate / frequency;
  final period = periodRaw < 2 ? 2 : (periodRaw > sampleRate ? sampleRate : periodRaw.round());
  final ring = Float64List(period);
  final random = math.Random((frequency * 1000).round());
  for (var i = 0; i < period; i++) {
    ring[i] = random.nextDouble() * 2 - 1;
  }
  var idx = 0;
  const damping = 0.996;
  for (var f = 0; f < frames && offset + f < out.length; f++) {
    final current = ring[idx];
    final next = ring[(idx + 1) % period];
    final damped = (current + next) * 0.5 * damping;
    ring[idx] = damped;
    out[offset + f] += damped * gain;
    idx = (idx + 1) % period;
  }
}

/// Builds a mono 16-bit PCM WAV for a chord sequence.
/// Chords longer than [maxChords] are truncated to keep previews snappy.
Uint8List synthesizeProgressionWav(
  List<String> chords, {
  double secondsPerChord = 0.7,
  int sampleRate = defaultSampleRate,
  int maxChords = 24,
  SynthTone tone = SynthTone.pure,
}) {
  final limited = chords.take(maxChords).toList();
  final framesPerChord = (secondsPerChord * sampleRate).round();
  final totalFrames = framesPerChord * limited.length;
  final dataSize = totalFrames * 2;

  final bytes = ByteData(44 + dataSize);

  // RIFF header
  bytes.setUint8(0, 82); // R
  bytes.setUint8(1, 73); // I
  bytes.setUint8(2, 70); // F
  bytes.setUint8(3, 70); // F
  bytes.setUint32(4, 36 + dataSize, Endian.little);
  bytes.setUint8(8, 87); // W
  bytes.setUint8(9, 65); // A
  bytes.setUint8(10, 86); // V
  bytes.setUint8(11, 69); // E
  // fmt chunk
  bytes.setUint8(12, 102); // f
  bytes.setUint8(13, 109); // m
  bytes.setUint8(14, 116); // t
  bytes.setUint8(15, 32); // (space)
  bytes.setUint32(16, 16, Endian.little); // PCM chunk size
  bytes.setUint16(20, 1, Endian.little); // PCM format
  bytes.setUint16(22, 1, Endian.little); // mono
  bytes.setUint32(24, sampleRate, Endian.little);
  bytes.setUint32(28, sampleRate * 2, Endian.little); // byte rate
  bytes.setUint16(32, 2, Endian.little); // block align
  bytes.setUint16(34, 16, Endian.little); // bits per sample
  // data chunk
  bytes.setUint8(36, 100); // d
  bytes.setUint8(37, 97); // a
  bytes.setUint8(38, 116); // t
  bytes.setUint8(39, 97); // a
  bytes.setUint32(40, dataSize, Endian.little);

  if (totalFrames == 0) return bytes.buffer.asUint8List();

  final samples = Float64List(totalFrames);
  for (var ci = 0; ci < limited.length; ci++) {
    final midis = chordToMidis(limited[ci]);
    final start = ci * framesPerChord;
    switch (tone) {
      case SynthTone.pure:
        for (var f = 0; f < framesPerChord; f++) {
          final t = f / sampleRate;
          final env = _envelope(f, framesPerChord, sampleRate);
          var mix = 0.0;
          for (final m in midis) {
            mix += math.sin(2 * math.pi * midiToFreq(m) * t);
          }
          samples[start + f] = (mix / midis.length) * env * 0.6;
        }
      case SynthTone.plucked:
        final gain = 0.9 / midis.length;
        for (final m in midis) {
          _pluckedInto(
            samples,
            start,
            midiToFreq(m),
            frames: framesPerChord,
            sampleRate: sampleRate,
            gain: gain,
          );
        }
    }
  }

  for (var i = 0; i < totalFrames; i++) {
    var sample = samples[i];
    if (sample > 0.95) sample = 0.95;
    if (sample < -0.95) sample = -0.95;
    final v = (sample * 32767).round();
    final clamped = v < -32768 ? -32768 : (v > 32767 ? 32767 : v);
    bytes.setInt16(44 + i * 2, clamped, Endian.little);
  }
  return bytes.buffer.asUint8List();
}
