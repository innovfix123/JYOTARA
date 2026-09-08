import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:jyotara/birth_form.dart';
import 'package:jyotara/services/conversation.dart';
import 'package:jyotara/services/jyotara_api.dart';
import 'package:jyotara/services/local_profile_vault.dart';
import 'package:jyotara/services/profile_gender.dart';
import 'package:jyotara/services/profile_session.dart';

void main() {
  testWidgets('gender step requires explicit choice and allows returning to edit', (tester) async {
    await tester.pumpWidget(MaterialApp(home: BirthForm(session: ProfileSession())));
    final next = find.byKey(const ValueKey('gender-continue'));
    expect(tester.widget<FilledButton>(next).onPressed, null);
    expect(find.text('Select your gender'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('gender-prefer_not_to_say')));
    await tester.pump();
    await tester.tap(next);
    await tester.pumpAndSettle();
    expect(find.text('Date of birth'), findsOneWidget);
    expect(find.text('Prefer not to say'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('edit-gender')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('gender-female')));
    await tester.pump();
    await tester.tap(next);
    await tester.pumpAndSettle();
    expect(find.text('Female'), findsOneWidget);
    expect(tester.takeException(), null);
  });

  test('gender survives restart, edits preserve chats without recalculation, old records restore', () async {
    String? disk; var calculations = 0;
    final vault = LocalProfileVault(read: () async => disk, write: (value) async { disk = value; });
    JyotaraApiClient api() => JyotaraApiClient(baseUrl: 'https://example.test', client: MockClient((request) async {
      calculations++;
      expect(request.url.path, '/api/astrology/kundli');
      expect(jsonDecode(request.body).containsKey('gender'), false);
      return http.Response(jsonEncode({
        'sandbox': false, 'chartTicket': 'ticket', 'profileId': 'profile',
        'result': {'data': {'nakshatra_details': {
          'chandra_rasi': {'name': 'Meena'}, 'nakshatra': {'name': 'Uttara Bhadrapada'},
        }}},
      }), 200);
    }));
    final session = ProfileSession(api: api(), vault: vault);
    Future<void> save(ProfileGender gender) => session.calculate(
      dateTime: '2000-01-01T12:00:00+05:30', latitude: 10, longitude: 78,
      exactTime: false, gender: gender,
    );
    await save(ProfileGender.female);
    session.conversation('Aadhirai').messages.add(const ChatMessage(fromUser: true, text: 'Saved question'));
    await save(ProfileGender.nonBinary);
    await session.flushStorage();
    expect(calculations, 1);
    final restored = ProfileSession(api: api(), vault: vault);
    await restored.restore();
    expect(restored.gender, ProfileGender.nonBinary);
    expect(restored.conversation('Aadhirai').messages.single.text, 'Saved question');
    final legacy = (await vault.load())!..remove('gender');
    await vault.save(legacy);
    final oldProfile = ProfileSession(api: api(), vault: vault);
    await oldProfile.restore();
    expect(oldProfile.gender, null);
    expect(oldProfile.facts, isNotNull);
    expect(oldProfile.storageError, null);
    expect(calculations, 1);
    await restored.clear();
    expect(restored.gender, null);
    expect(disk, null);
  });
}
