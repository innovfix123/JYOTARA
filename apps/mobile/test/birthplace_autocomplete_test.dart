import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:jyotara/birth_form.dart';
import 'package:jyotara/services/jyotara_api.dart';
import 'package:jyotara/services/profile_session.dart';
import 'package:jyotara/services/profile_gender.dart';
void main() {
 testWidgets('typing debounces lookup and ignores stale district results', (tester) async {
  final requests = <String, Completer<http.Response>>{};
  final session = ProfileSession(api: JyotaraApiClient(baseUrl:'https://example.test', client:MockClient((r) {
   final query=jsonDecode(r.body)['query'] as String;
   final response=Completer<http.Response>(); requests[query]=response; return response.future;
  })));
  await tester.pumpWidget(MaterialApp(home:BirthForm(session:session, initialGender:ProfileGender.male)));
  final field=find.widgetWithText(TextField,'Birth town, city or district');
  await tester.ensureVisible(field);
  await tester.enterText(field,'Ero'); await tester.pump(const Duration(milliseconds:200)); expect(requests,isEmpty);
  await tester.enterText(field,'Erode'); await tester.pump(const Duration(milliseconds:351)); expect(requests.keys,['Erode']);
  await tester.enterText(field,'Kochi'); await tester.pump(const Duration(milliseconds:351));
  http.Response reply(String name)=>http.Response(jsonEncode({'data':[[name,name,'Kerala','','IN','Asia/Kolkata',9.9,76.2]]}),200);
  requests['Kochi']!.complete(reply('Kochi')); await tester.pumpAndSettle(); expect(find.text('Kochi, Kerala'),findsOneWidget);
  requests['Erode']!.complete(reply('Erode')); await tester.pumpAndSettle(); expect(find.text('Erode, Kerala'),findsNothing);
  await tester.pumpWidget(const SizedBox());
 });
}
