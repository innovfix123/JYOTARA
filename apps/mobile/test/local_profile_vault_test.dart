import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:jyotara/services/local_profile_vault.dart';
import 'package:jyotara/services/profile_session.dart';
import 'package:jyotara/services/jyotara_api.dart';
import 'package:jyotara/services/conversation.dart';

void main() {
  test(
    'serialization failure is asynchronous and later saves recover',
    () async {
      String? disk;
      final vault = LocalProfileVault(
        read: () async => disk,
        write: (value) async {
          disk = value;
        },
      );
      final invalid = <String, dynamic>{'version': 1};
      invalid['cycle'] = invalid;
      Future<void>? result;
      expect(() {
        result = vault.save(invalid);
      }, returnsNormally);
      await expectLater(result!, throwsA(isA<JsonCyclicError>()));
      await vault.save({'version': 1, 'value': 'recovered'});
      expect((await vault.load())?['value'], 'recovered');
    },
  );
  test('saved profile, cookie and conversation restore without recalculation, deletion survives restart', () async {
    String? disk;
    final vault = LocalProfileVault(
      read: () async => disk,
      write: (value) async {
        disk = value;
      },
    );
    var calculations = 0;
    final consentFlags = <bool>[];
    JyotaraApiClient api() => JyotaraApiClient(
      baseUrl: 'https://example.test',
      client: MockClient((request) async {
        if (request.url.path.endsWith('kundli')) {
          calculations++;
          return http.Response(
            jsonEncode({
              'sandbox': false,
              'chartTicket': 'TEST',
              'profileId': 'profile-test',
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
            headers: {
              'set-cookie': 'nirayana_pilot_session=session-test; HttpOnly',
            },
          );
        }
        expect(
          request.headers['Cookie'],
          'nirayana_pilot_session=session-test',
        );
        expect(jsonDecode(request.body)['chartTicket'], 'TEST');
        consentFlags.add(jsonDecode(request.body)['researchConsent'] == true);
        return http.Response(
          '{"profileId":"profile-test","answer":"Fixture response","evidence":[]}',
          200,
        );
      }),
    );
    final first = ProfileSession(api: api(), vault: vault);
    await first.calculate(
      dateTime: '2002-07-29T05:00:00+05:30',
      latitude: 11,
      longitude: 77,
      exactTime: false,
    );
    final chat = first.conversation('Arivan');
    chat.messages.add(
      const ChatMessage(fromUser: true, text: 'Saved question'),
    );
    chat.language = 'tanglish';
    chat.pending = true;
    chat.changed();
    await first.flushStorage();
    final second = ProfileSession(api: api(), vault: vault);
    await second.restore();
    expect(second.facts?['rashi'], 'Meena');
    expect(second.birthTimeKnown, false);
    expect(second.conversation('Arivan').messages.first.text, 'Saved question');
    expect(second.conversation('Arivan').language, 'tanglish');
    expect(
      second.conversation('Arivan').messages.last.label,
      'INTERRUPTED REQUEST',
    );
    expect(
      second.conversation('Arivan').pending,
      false,
      reason: 'Never automatically retry a paid request after restart',
    );
    await second.ask(
      category: 'Career',
      question: 'Job?',
      responseStyle: 'english',
    );
    expect(calculations, 1);
    second.setResearchConsent(true);
    await second.ask(
      category: 'Career',
      question: 'Next step?',
      responseStyle: 'english',
    );
    second.setResearchConsent(false);
    await second.ask(
      category: 'Career',
      question: 'Skills?',
      responseStyle: 'english',
    );
    expect(consentFlags, [false, true, false]);
    second.setResearchConsent(true);
    await second.clear();
    expect(second.researchConsent, false);
    expect(disk, null);
    final third = ProfileSession(api: api(), vault: vault);
    await third.restore();
    expect(third.facts, null);
    expect(third.researchConsent, false);
    expect(third.conversation('Arivan').messages, isEmpty);
  });
  test(
    'queued writes cannot resurrect deleted data and failed deletes surface',
    () async {
      String? disk;
      final gate = Completer<void>();
      var block = true, failDelete = false;
      final vault = LocalProfileVault(
        read: () async => disk,
        write: (value) async {
          if (block) {
            block = false;
            await gate.future;
          }
          if (value == null && failDelete) throw StateError('delete failed');
          disk = value;
        },
      );
      final save = vault.save({'version': 1, 'value': 'old'});
      final deletion = vault.delete();
      gate.complete();
      await save;
      await deletion;
      expect(disk, null);
      await vault.save({'version': 1});
      failDelete = true;
      await expectLater(vault.delete(), throwsStateError);
      expect(disk, isNotNull);
      failDelete = false;
      await vault.delete();
      expect(disk, null);
    },
  );
  test(
    'corrupt or different-origin saved records are preserved and reported',
    () async {
      var disk = '{"version":1,"origin":"https://other.test"}';
      final vault = LocalProfileVault(
        read: () async => disk,
        write: (value) async {
          disk = value ?? '';
        },
      );
      final session = ProfileSession(vault: vault);
      await session.restore();
      expect(session.facts, null);
      expect(session.storageError, isNotNull);
      expect(disk, contains('other.test'));
      disk = 'invalid json';
      await session.restore();
      expect(disk, 'invalid json');
      expect(session.storageError, isNotNull);
    },
  );
}
