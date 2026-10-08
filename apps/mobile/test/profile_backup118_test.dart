import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:jyotara/services/profile_backup.dart';
import 'package:jyotara/services/local_profile_vault.dart';
import 'package:jyotara/services/profile_session.dart';
import 'package:jyotara/services/jyotara_api.dart';
import 'package:jyotara/services/phone_access.dart';

void main() {
  test(
    'backup strips chats, retries failed saves and deduplicates success',
    () async {
      var attempts = 0;
      final backup = ProfileBackup(
        token: () => 'protected-token',
        client: MockClient((r) async {
          expect(r.headers['Authorization'], 'Bearer protected-token');
          final body = jsonDecode(r.body) as Map;
          expect(body['profile']['conversations'], isNull);
          expect(body['profile']['requestIds'], isNull);
          attempts++;
          return http.Response(
            attempts == 1 ? '{}' : '{"saved":true}',
            attempts == 1 ? 503 : 200,
          );
        }),
      );
      final record = {
        'version': 1,
        'nickname': 'Saran',
        'conversations': {'secret': 'message'},
        'requestIds': {'secret': 'identity'},
      };
      await expectLater(
        backup.save(record),
        throwsA(isA<JyotaraApiException>()),
      );
      await backup.save(record);
      await backup.save(record);
      expect(attempts, 2);
    },
  );
  test(
    'fresh phone restores profile and unknown birth time without chart request',
    () async {
      final chart = {
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
      };
      final cloud = {
        'version': 1,
        'origin': 'https://api.jyotara.in',
        'session': 'nirayana_pilot_session=session-test',
        'profileKey': '2002-07-29T12:00:00+05:30|11.0|77.0|false',
        'nickname': 'Saran',
        'birthTimeKnown': false,
        'calculatedAt': DateTime.now().toUtc().toIso8601String(),
        'raw': chart,
      };
      String? disk;
      final session = ProfileSession(
        api: JyotaraApiClient(
          baseUrl: 'https://api.jyotara.in',
          client: MockClient(
            (_) async => throw StateError('No calculation needed'),
          ),
        ),
        vault: LocalProfileVault(
          read: () async => disk,
          write: (v) async {
            disk = v;
          },
        ),
      );
      var reads = 0;
      final backup = ProfileBackup(
        token: () => 'token',
        client: MockClient((r) async {
          final body = jsonDecode(r.body);
          if (body['action'] == 'load') {
            reads++;
            return http.Response(jsonEncode({'profile': cloud}), 200);
          }
          return http.Response('{"saved":true}', 200);
        }),
      );
      await restoreBirthProfile(backup: backup, session: session);
      expect(session.savedReadFailed, false);
      expect(session.nickname, 'Saran');
      expect(session.facts, isNotNull);
      expect(session.birthTimeKnown, false);
      expect(reads, 1);
      expect(jsonDecode(disk!)['conversations'], isEmpty);
    },
  );
  test('same birth profile keeps device chats while restoring cloud preferences', () async {
    String? disk;
    final chart={'sandbox':false,'chartTicket':'TEST','profileId':'profile-test','result':{'data':{'nakshatra_details':{'chandra_rasi':{'name':'Meena'},'nakshatra':{'name':'Uttara Bhadrapada'}}}}};
    final session=ProfileSession(api:JyotaraApiClient(baseUrl:'https://api.jyotara.in',client:MockClient((_)async=>http.Response(jsonEncode(chart),200,headers:{'set-cookie':'nirayana_pilot_session=session-test; HttpOnly'}))),vault:LocalProfileVault(read:()async=>disk,write:(v)async{disk=v;}));
    await session.calculate(dateTime:'2002-07-29T12:00:00+05:30',latitude:11,longitude:77,exactTime:false,nickname:'Old name');await session.flushStorage();
    final local=jsonDecode(disk!) as Map<String,dynamic>;
    local['conversations']={'aravind':{'language':'english','messages':[{'fromUser':true,'text':'Device private question'}],'ended':false,'depth':'standard'}};
    disk=jsonEncode(local);await session.restore();
    final cloud={...birthProfileBackup(local),'nickname':'New name','preferredChatLanguage':'tamil'};
    final backup=ProfileBackup(token:()=> 'token',client:MockClient((r)async=>jsonDecode(r.body)['action']=='load'?http.Response(jsonEncode({'profile':cloud}),200):http.Response('{"saved":true}',200)));
    await restoreBirthProfile(backup:backup,session:session);
    expect(session.nickname,'New name');expect(session.preferredChatLanguage,'tamil');expect(jsonDecode(disk!)['conversations']['aravind']['messages'][0]['text'],'Device private question');
  });
  test('old restored chart refreshes from saved birth details without a renewal loop', () async {
    var now=DateTime.utc(2026,8,1), calculations=0, renewals=0;
    final session=ProfileSession(clock:()=>now,api:JyotaraApiClient(baseUrl:'https://api.jyotara.in',client:MockClient((r)async {
      if(r.url.path.endsWith('/renew')) {renewals++;return http.Response('{"error":"Expired","code":"renewal_unavailable"}',401);}
      calculations++;
      final request=jsonDecode(r.body);expect(request['datetime'],'2002-07-29T12:00:00+05:30');
      return http.Response(jsonEncode({'sandbox':false,'chartTicket':'TEST','profileId':'profile-test','result':{'data':{'nakshatra_details':{'chandra_rasi':{'name':'Meena'},'nakshatra':{'name':'Uttara Bhadrapada'}}}}}),200,headers:{'set-cookie':'nirayana_pilot_session=session-test; HttpOnly'});
    })));
    await session.calculate(dateTime:'2002-07-29T12:00:00+05:30',latitude:11,longitude:77,exactTime:false,nickname:'Saran');
    now=DateTime.utc(2026,10,7);
    await session.renewChatAccess().timeout(const Duration(seconds:2));
    expect(renewals,1);expect(calculations,2);expect(session.nickname,'Saran');expect(session.birthTimeKnown,false);
  });
  test(
    'backup outage keeps verified login retryable without another OTP',
    () async {
      String? disk;
      var restores = 0;
      var verifies = 0;
      final access = PhoneAccess(
        testerCode: () => null,
        read: () async => disk,
        write: (v) async {
          disk = v;
        },
        prepareAccount: (_) async {},
        restoreVerifiedProfile: (a, t) async {
          restores++;
          if (restores == 1) throw StateError('offline');
        },
        client: MockClient((r) async {
          if (r.url.path.endsWith('/send'))
            return http.Response(jsonEncode({'challengeId': 'b' * 48}), 200);
          verifies++;
          return http.Response(
            jsonEncode({
              'token': 'a' * 64,
              'accountId': 'account',
              'expiresAt': DateTime.now()
                  .add(const Duration(days: 1))
                  .millisecondsSinceEpoch,
            }),
            200,
          );
        }),
      );
      await access.send('9000000000');
      await access.verify('123456');
      expect(access.authorized, false);
      expect(access.profileRestorePending, true);
      expect(access.token, isNotNull);
      await access.retryProfileRestore();
      expect(access.authorized, true);
      expect(verifies, 1);
      await access.signOut();
      expect(access.profileRestorePending, false);
    },
  );
}
