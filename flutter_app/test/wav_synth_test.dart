import 'dart:typed_data';

import 'package:test/test.dart';
import 'package:songpilot/audio/wav_synth.dart';

void main() {
  group('chordToMidis', () {
    test('major chord: bass root plus root, third, fifth', () {
      final midis = chordToMidis('C', baseMidi: 48);
      expect(midis.length, 4); // bass octave + 3 chord tones
      expect(midis[0], 36); // C2 bass
      expect(midis[1], 48); // C3 root
      expect(midis[2], 52); // E3 major third
      expect(midis[3], 55); // G3 fifth
    });

    test('minor chord uses minor third', () {
      final midis = chordToMidis('Am', baseMidi: 48);
      // A root index 9 -> 57; m3 = 57 + 3 = 60
      expect(midis.contains(60), isTrue);
      expect(midis.contains(61), isFalse);
    });

    test('dominant seventh includes flat seventh', () {
      final midis = chordToMidis('G7', baseMidi: 48);
      // G root = 55; b7 = 55 + 10 = 65 (F)
      expect(midis.contains(65), isTrue);
    });

    test('diminished triad', () {
      final midis = chordToMidis('Bdim', baseMidi: 48);
      // B root = 59; dim third = 62, dim fifth = 65
      expect(midis.contains(62), isTrue);
      expect(midis.contains(65), isTrue);
    });

    test('unknown quality falls back to major triad', () {
      final exotic = chordToMidis('Cadd9', baseMidi: 48);
      final plain = chordToMidis('C', baseMidi: 48);
      expect(exotic, equals(plain));
    });
  });

  group('midiToFreq', () {
    test('A4 (69) is 440 Hz', () {
      expect(midiToFreq(69), closeTo(440.0, 0.0001));
    });

    test('octave doubles frequency', () {
      expect(midiToFreq(81), closeTo(midiToFreq(69) * 2, 0.01));
    });
  });

  group('synthesizeProgressionWav (pure tone)', () {
    test('empty input produces header-only WAV', () {
      final wav = synthesizeProgressionWav(const [], sampleRate: 1000);
      expect(wav.length, 44);
    });

    test('header structure', () {
      final wav = synthesizeProgressionWav(const ['C'], sampleRate: 1000);
      // 'RIFF'
      expect([wav[0], wav[1], wav[2], wav[3]], [82, 73, 70, 70]);
      // 'WAVE'
      expect([wav[8], wav[9], wav[10], wav[11]], [87, 65, 86, 69]);
      // 'data'
      expect([wav[36], wav[37], wav[38], wav[39]], [100, 97, 116, 97]);
      expect(wav[22], 1); // mono
      final sampleRate =
          ByteData.sublistView(wav).getUint32(24, Endian.little);
      expect(sampleRate, 1000);
    });

    test('data length matches frames', () {
      final wav = synthesizeProgressionWav(const ['C', 'G'],
          secondsPerChord: 0.5, sampleRate: 1000);
      // 2 chords * 0.5s * 1000 frames * 2 bytes + 44 header
      expect(wav.length, 44 + 2 * 500 * 2);
      final dataSize =
          ByteData.sublistView(wav).getUint32(40, Endian.little);
      expect(dataSize, wav.length - 44);
    });

    test('samples stay within int16 range', () {
      final wav = synthesizeProgressionWav(
        const ['C', 'Am', 'F', 'G'],
        secondsPerChord: 0.2,
        sampleRate: 8000,
      );
      final data = ByteData.sublistView(wav);
      for (var i = 44; i < wav.length; i += 2) {
        final v = data.getInt16(i, Endian.little);
        expect(v >= -32768 && v <= 32767, isTrue);
      }
    });

    test('maxChords truncation', () {
      final many = List.filled(50, 'C');
      final wav = synthesizeProgressionWav(many,
          secondsPerChord: 0.1, sampleRate: 1000, maxChords: 24);
      // 24 chords * 0.1s * 1000 frames * 2 bytes + header
      expect(wav.length, 44 + 24 * 100 * 2);
    });
  });

  group('synthesizeProgressionWav (plucked tone)', () {
    test('same framing as pure tone', () {
      final wav = synthesizeProgressionWav(
        const ['C', 'G'],
        secondsPerChord: 0.5,
        sampleRate: 1000,
        tone: SynthTone.plucked,
      );
      expect(wav.length, 44 + 2 * 500 * 2);
    });

    test('deterministic: same input gives identical bytes', () {
      final a = synthesizeProgressionWav(
        const ['Am', 'G'],
        secondsPerChord: 0.3,
        sampleRate: 8000,
        tone: SynthTone.plucked,
      );
      final b = synthesizeProgressionWav(
        const ['Am', 'G'],
        secondsPerChord: 0.3,
        sampleRate: 8000,
        tone: SynthTone.plucked,
      );
      expect(a, equals(b));
    });

    test('differs from pure tone', () {
      final pure = synthesizeProgressionWav(
        const ['C'],
        secondsPerChord: 0.3,
        sampleRate: 8000,
      );
      final plucked = synthesizeProgressionWav(
        const ['C'],
        secondsPerChord: 0.3,
        sampleRate: 8000,
        tone: SynthTone.plucked,
      );
      expect(pure, isNot(equals(plucked)));
    });

    test('samples stay within int16 range', () {
      final wav = synthesizeProgressionWav(
        const ['C', 'F', 'G'],
        secondsPerChord: 0.3,
        sampleRate: 16000,
        tone: SynthTone.plucked,
      );
      final data = ByteData.sublistView(wav);
      var maxAbs = 0;
      for (var i = 44; i < wav.length; i += 2) {
        final v = data.getInt16(i, Endian.little).abs();
        if (v > maxAbs) maxAbs = v;
      }
      expect(maxAbs, lessThanOrEqualTo(32767));
      expect(maxAbs, greaterThan(0)); // actually produced sound
    });
  });
}
