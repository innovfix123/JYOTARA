import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:jyotara/services/jyotara_api.dart';
import 'package:jyotara/services/profile_session.dart';

void main() {
  test('recovered chart keeps original calculation time instead of extending freshness', () async {
    final session = ProfileSession(clock: () => DateTime.utc(2026,9,7,10), api: JyotaraApiClient(client: MockClient((_) async => http.Response('''{
      "sandbox":false,"profileRecovered":true,"chartCalculatedAt":"2026-09-07T01:00:00Z",
      "profileId":"synthetic","chartTicket":"TEST",
      "result":{"data":{"nakshatra_details":{"chandra_rasi":{"name":"Meena"},"nakshatra":{"name":"Uttara Bhadrapada"}}}}
    }''',200))));
    await session.calculate(dateTime:'2002-07-29T05:00:00+05:30',latitude:11,longitude:77,exactTime:true);
    expect(session.profileRecovered,true);
    expect(session.calculatedAt,DateTime.utc(2026,9,7,1));
    expect(session.profileRequestUnconfirmed,false);
  });
  test('malformed recovery metadata cannot silently appear as a fresh chart', () {
    for(final value in [
      {'profileRecovered':true},
      {'profileRecovered':'true','chartCalculatedAt':'2026-09-07T01:00:00Z'},
      {'profileRecovered':true,'chartCalculatedAt':'2026-02-30T01:00:00Z'},
    ]) {
      expect(()=>ChartResponse.fromJson(value),throwsA(isA<JyotaraApiException>()));
    }
    expect(ChartResponse.fromJson({}).chart,isEmpty,reason:'Legacy unrecovered payloads remain compatible');
  });
}
