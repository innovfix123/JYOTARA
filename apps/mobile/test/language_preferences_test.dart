import 'package:flutter_test/flutter_test.dart';
import 'package:jyotara/services/language_preferences.dart';
import 'package:jyotara/services/profile_session.dart';

void main() {
  test('preference reloads and applies to a new guide session', () async {
    String? stored;
    LanguagePreferences create() => LanguagePreferences(
      read: () async => stored,
      write: (v) async {
        stored = v;
      },
    );
    final first = create();
    await first.set('tanglish');
    final reopened = create();
    await reopened.load();
    final session = ProfileSession(preferences: reopened);
    expect(session.conversation('Arivan').language, 'tanglish');
    await session.setChatLanguage('english');
    expect(session.conversation('Arivan').language, 'english');
    expect(session.conversation('Medha').language, 'english');
    session.clear();
    expect(session.conversation('Arivan').language, 'english');
    expect(stored, 'english');
  });
  test(
    'invalid values default safely and failed writes do not claim success',
    () async {
      final preferences = LanguagePreferences(
        read: () async => 'unsupported',
        write: (_) async => throw StateError('disk unavailable'),
      );
      await preferences.load();
      expect(preferences.value, 'auto');
      await expectLater(preferences.set('tamil'), throwsStateError);
      expect(preferences.value, 'auto');
      await expectLater(preferences.set('invalid'), throwsArgumentError);
    },
  );
  test('queued writes preserve the latest requested choice', () async {
    final values = <String>[];
    final preferences = LanguagePreferences(
      read: () async => null,
      write: (v) async {
        values.add(v);
      },
    );
    await Future.wait([preferences.set('tamil'), preferences.set('english')]);
    expect(values, ['tamil', 'english']);
    expect(preferences.value, 'english');
  });
}
