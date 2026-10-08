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
  testWidgets(
    'gender step requires explicit choice and allows returning to edit',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(home: BirthForm(session: ProfileSession())),
      );
      expect(find.text('Gender *', findRichText: true), findsOneWidget);
      expect(find.byType(TextField), findsWidgets);
      await tester.tap(find.byKey(const ValueKey('gender-prefer_not_to_say')));
      await tester.pump();
      expect(
        tester
            .widget<ChoiceChip>(
              find.byKey(const ValueKey('gender-prefer_not_to_say')),
            )
            .selected,
        true,
      );
      await tester.tap(find.byKey(const ValueKey('gender-female')));
      await tester.pump();
      expect(
        tester
            .widget<ChoiceChip>(find.byKey(const ValueKey('gender-female')))
            .selected,
        true,
      );
      expect(
        tester
            .widget<ChoiceChip>(
              find.byKey(const ValueKey('gender-prefer_not_to_say')),
            )
            .selected,
        false,
      );
      expect(tester.takeException(), null);
    },
  );

  test('gender survives restart, edits preserve chats without recalculation, old records restore', () async {
    String? disk;
    var calculations = 0;
    final vault = LocalProfileVault(
      read: () async => disk,
      write: (value) async {
        disk = value;
      },
    );
    JyotaraApiClient api() => JyotaraApiClient(
      baseUrl: 'https://example.test',
      client: MockClient((request) async {
        calculations++;
        expect(request.url.path, '/api/astrology/kundli');
        expect(jsonDecode(request.body).containsKey('gender'), false);
        return http.Response(
          jsonEncode({
            'sandbox': false,
            'chartTicket': 'ticket',
            'profileId': 'profile',
            'result': {
              'data': {
                'nakshatra_details': {
                  'chandra_rasi': {'name': 'Meena'},
                  'nakshatra': {'name': 'Uttara Bhadrapada'},
                },
              },
            },
          }),
          200,
        );
      }),
    );
    final session = ProfileSession(api: api(), vault: vault);
    Future<void> save(ProfileGender gender) => session.calculate(
      dateTime: '2000-01-01T12:00:00+05:30',
      latitude: 10,
      longitude: 78,
      exactTime: false,
      gender: gender,
    );
    await save(ProfileGender.female);
    session
        .conversation('Aadhirai')
        .messages
        .add(const ChatMessage(fromUser: true, text: 'Saved question'));
    await save(ProfileGender.nonBinary);
    await session.flushStorage();
    expect(calculations, 1);
    final restored = ProfileSession(api: api(), vault: vault);
    await restored.restore();
    expect(restored.gender, ProfileGender.nonBinary);
    expect(
      restored.conversation('Aadhirai').messages.single.text,
      'Saved question',
    );
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
