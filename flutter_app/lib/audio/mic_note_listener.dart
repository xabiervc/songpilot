/// Microphone capture for note/chord detection.
///
/// Records a short PCM16 window and hands the bytes to the DSP layer.
/// Wraps the `record` package; all real analysis lives in dsp/pitch_detector.
library mic_note_listener;

import 'dart:typed_data';

import 'package:record/record.dart';

class MicNoteListener {
  static const int sampleRate = 16000;
  static const Duration maxWindow = Duration(seconds: 4);

  final AudioRecorder _recorder = AudioRecorder();
  final BytesBuilder _buffer = BytesBuilder();
  bool _recording = false;

  bool get isRecording => _recording;

  /// Starts capturing. Returns false if the user denied microphone access.
  Future<bool> start() async {
    if (_recording) return true;
    final allowed = await _recorder.hasPermission();
    if (!allowed) return false;

    _buffer.clear();
    final stream = await _recorder.startStream(
      const RecordConfig(
        encoder: AudioEncoder.pcm16bits,
        sampleRate: sampleRate,
        numChannels: 1,
      ),
    );
    _recording = true;
    stream.listen(_buffer.add, onDone: () => _recording = false);
    return true;
  }

  /// Stops capturing and returns the raw PCM16 little-endian buffer.
  Future<Uint8List> stopAndCollect() async {
    if (!_recording) return Uint8List(0);
    _recording = false;
    await _recorder.stop();
    return _buffer.takeBytes();
  }

  void dispose() {
    _recorder.dispose();
  }
}
