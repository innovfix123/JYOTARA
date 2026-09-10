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
      contains('Kalyanam'),
    );
  });

  test('suggestions follow concerns and never recycle exhausted questions', () {
    final money = chatSuggestions('Love', 'english', [
      'My partner asks for money',
    ]);
    expect(money.first, contains('money'));
    expect(money, isNot(contains('What can I do next?')));
    final family = chatSuggestions('Love', 'english', [
      'How can I tell my parents?',
    ]);
    expect(family.first, contains('parents'));
    expect(family, isNot(equals(money)));
    final initial = chatSuggestions('Love', 'english', []);
    final follow = chatSuggestions('Love', 'english', initial);
    final exhausted = chatSuggestions('Love', 'english', [
      ...initial,
      ...follow,
    ]);
    expect(exhausted, isEmpty);
    expect(
      chatSuggestions('Love', 'tamil', [
        'இதை எளிதாக சொல்லுங்கள்',
      ], lastReply: 'பணம் அனுப்ப அழுத்தம் தேவையில்லை.').first,
      contains('பணம்'),
    );
  });
}
