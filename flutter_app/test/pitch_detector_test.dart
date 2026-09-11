import 'dart:math' as math;
import 'dart:typed_data';

import 'package:test/test.dart';
import 'package:songpilot/dsp/pitch_detector.dart';

Uint8List sinePcm16(double freq, int sampleRate, {double seconds = 0.5}) {
  final frames = (seconds * sampleRate).round();
  final bytes = ByteData(frames * 2);
  for (var i = 0; i < frames; i++) {
    final t = i / sampleRate;
    final v = (math.sin(2 * math.pi * freq * t) * 20000).round();
    bytes.setInt16(i * 2, v, Endian.little);
  }
  return bytes.buffer.asUint8List();
}

void main() {
  group('decodePcm16', () {
    test('round trips int16 little-endian values', () {
      final bytes = ByteData(4)
        ..setInt16(0, 1000, Endian.little)
        ..setInt16(2, -1000, Endian.little);
      final samples = decodePcm16(bytes.buffer.asUint8List());
      expect(samples.length, 2);
      expect(samples[0], closeTo(1000 / 32768.0, 1e-9));
      expect(samples[1], closeTo(-1000 / 32768.0, 1e-9));
    });
  });

  group('detectTopNotesFromBytes', () {
    const sr = 16000;

    test('A440 sine is detected as A', () {
      final bytes = sinePcm16(440.0, sr);
      final scores = detectTopNotesFromBytes(bytes, sr);
      expect(scores, isNotEmpty);
      expect(scores.first.name, 'A');
    });

    test('C4 sine is detected as C', () {
      final bytes = sinePcm16(261.63, sr);
      final scores = detectTopNotesFromBytes(bytes, sr);
      expect(scores, isNotEmpty);
      expect(scores.first.name, 'C');
    });

    test('E4 sine is detected as E', () {
      final bytes = sinePcm16(329.63, sr);
      final scores = detectTopNotesFromBytes(bytes, sr);
      expect(scores.first.name, 'E');
    });

    test('silence returns no notes', () {
      final bytes = Uint8List(sr); // 0.5 s of zeros
      final scores = detectTopNotesFromBytes(bytes, sr);
      expect(scores, isEmpty);
    });

    test('very short buffers return no notes instead of noise', () {
      final bytes = Uint8List(1000);
      final scores = detectTopNotesFromBytes(bytes, sr); // 500 samples only
      expect(scores, isEmpty);
    });

    test('honours the top parameter', () {
      final bytes = sinePcm16(440.0, sr);
      final scores = detectTopNotesFromBytes(bytes, sr, top: 1);
      expect(scores.length, lessThanOrEqualTo(1));
    });
  });
}
