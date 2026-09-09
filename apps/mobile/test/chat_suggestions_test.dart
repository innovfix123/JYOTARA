import 'package:flutter_test/flutter_test.dart';

import 'package:jyotara/services/chat_suggestions.dart';

void main() {
  test('three suggestions remain available, rotate and follow typed topic', () {
    for (final category in [
      'Love',
      'Relationships',
      'Marriage',
      'Family',
      'Career',
      'Education',
      'Business',
      'Property',
      'Spiritual',
      'Daily',
    ]) {
      for (final language in ['english', 'tamil', 'tanglish']) {
        final first = chatSuggestions(category, language, []);
        expect(first.length, 3);
        expect(first.toSet().length, 3);
        final next = chatSuggestions(category, language, [first.first]);
        expect(next.length, 3);
        expect(next, isNot(contains(first.first)));
      }
    }
    expect(
      chatSuggestions('Love', 'english', ['I need a job']).first,
      contains('work'),
    );
    expect(
      chatSuggestions('Career', 'tanglish', ['En kalyanam eppo?']).first,
      contains('kalyanam'),
    );
  });
}
