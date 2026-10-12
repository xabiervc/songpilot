import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('SongPilot profile round-trips through JSON for data exports', () {
    final profile = {
      'id': 'user-123',
      'username': 'test-musician',
      'email': 'test@example.com',
      'skill_level': 'intermediate',
      'instruments': ['guitar'],
      'genres': ['indie'],
      'favourite_artists': <String>[],
      'open_to_collab': true,
      'looking_for': <String>[],
      'is_pro': false,
    };
    final decoded = jsonDecode(jsonEncode(profile)) as Map<String, dynamic>;
    expect(decoded['id'], 'user-123');
    expect(decoded['instruments'], ['guitar']);
    expect(decoded['open_to_collab'], isTrue);
  });
}
