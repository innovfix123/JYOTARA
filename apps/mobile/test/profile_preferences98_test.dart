import 'package:flutter_test/flutter_test.dart';
import 'package:http/testing.dart';
import 'package:jyotara/services/profile_session.dart';
import 'package:jyotara/services/local_profile_vault.dart';
import 'package:jyotara/services/jyotara_api.dart';
import 'profile_replacement_test.dart' show chartReply;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('profile preferences survive encrypted vault restore and set new chat language', () async {
    String? disk;
    final vault = LocalProfileVault(read: () async => disk, write: (v) async => disk = v);
    ProfileSession make() => ProfileSession(vault: vault, api: JyotaraApiClient(baseUrl: 'https://example.test', client: MockClient((_) async => chartReply('preferences'))));
    final first = make();
    await first.calculate(dateTime: '2002-07-29T05:00:00+05:30', latitude: 11, longitude: 77, exactTime: true);
    await first.saveProfilePreferences(language: 'tanglish', relationship: 'Single', occupation: 'Student');
    final restored = make();
    await restored.restore();
    expect(restored.relationshipStatus, 'Single');
    expect(restored.profession, 'Student');
    expect(restored.conversation('Meera').language, 'tanglish');
    expect(restored.storageError, isNull);
    await expectLater(restored.saveProfilePreferences(language: 'unknown', relationship: '', occupation: ''), throwsArgumentError);
    first.dispose(); restored.dispose();
  });
}
