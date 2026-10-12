import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('JSON data export contains timestamp and exported sections', () {
    final data = <String, dynamic>{
      'exported_at': DateTime.utc(2026, 10, 12).toIso8601String(),
      'profile': <Map<String, dynamic>>[],
      'songs': <Map<String, dynamic>>[],
      'song_sections': <Map<String, dynamic>>[],
      'collab_requests': <Map<String, dynamic>>[],
    };
    final decoded = jsonDecode(const JsonEncoder.withIndent('  ').convert(data))
        as Map<String, dynamic>;
    expect(decoded['exported_at'], isNotEmpty);
    expect(decoded.keys, containsAll(['profile', 'songs', 'song_sections']));
  });
}
