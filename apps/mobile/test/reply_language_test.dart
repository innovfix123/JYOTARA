import 'package:flutter_test/flutter_test.dart';
import 'package:jyotara/services/reply_language.dart';

void main() {
  test('English words and names do not match Tanglish substrings', () {
    for (final question in [
      'Should I move to Chennai for work?',
      'Should I study in Vienna?',
      'Can I work with Cheyenne?',
      'My salary is paid in yen. What should I focus on?',
      'Can I ask about www.enaku.com?',
      'Contact enaku@example.com about work.',
    ]) {
      expect(detectReplyLanguage(question), 'english', reason: question);
    }
  });
  test('Tamil script and common Tanglish spelling variants are detected', () {
    expect(detectReplyLanguage('எனக்கு வேலை மாற்றம் நல்லதா?'), 'tamil');
    for (final question in [
      'Enaku promotion chance iruka?',
      'ENAKKU job kidaikuma?',
      'Velaila eppadi focus pannanum?',
      'Job change pannalama, sollunga?',
      'Inniku interview irukku.',
      'https://example.com Enna next step?',
    ]) {
      expect(detectReplyLanguage(question), 'tanglish', reason: question);
    }
  });
  test('Explicit preference overrides detected script and ambiguous words', () {
    expect(detectReplyLanguage('எனக்கு வேலை?', preference: 'english'), 'english');
    expect(detectReplyLanguage('Should I change jobs?', preference: 'tamil'), 'tamil');
    expect(detectReplyLanguage('Should I change jobs?', preference: 'tanglish'), 'tanglish');
    expect(detectReplyLanguage('Should I change jobs?', preference: 'invalid'), 'english');
  });
}
