import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/testing.dart';
import 'package:jyotara/discovery_screens.dart';
import 'package:jyotara/services/jyotara_api.dart';
import 'package:jyotara/services/profile_session.dart';
import 'profile_replacement_test.dart' show chartReply;

void main() {
 testWidgets('saved library searches, selects both people and submits their own details', (tester) async {
  FlutterSecureStorage.setMockInitialValues({});
  tester.view.physicalSize = const Size(1000,2600); tester.view.devicePixelRatio=1;
  addTearDown(tester.view.resetPhysicalSize); addTearDown(tester.view.resetDevicePixelRatio);
  Future<SavedKundli> profile(String name, String date) async {
   final s=ProfileSession(api:JyotaraApiClient(baseUrl:'https://test',client:MockClient((_) async => chartReply(name))));
   await s.calculate(dateTime:'${date}T05:00:00+05:30',latitude:11,longitude:77,exactTime:true,nickname:name,birthplaceLabel:'Erode');
   return SavedKundli(name,s);
  }
  final one=await profile('Saran','2002-07-29'); final two=await profile('Shakthi','2001-09-16');
  Map<String,dynamic>? sent;
  await tester.pumpWidget(MaterialApp(home:MatchingScreen(loadKundlis:()async=>[one,two],request:(path,body)async {
   sent=jsonDecode(jsonEncode(body)) as Map<String,dynamic>;
   return {'score':17.5,'maximum':36,'interpretation':'Traditional comparison.','note':'Test reading.','factors':[{'name':'Tara','score':1.5,'maximum':3,'description':'Birth stars.'}]};
  })));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Open Kundli')); await tester.pumpAndSettle();
  await tester.enterText(find.byType(TextField),'saran'); await tester.pump();
  expect(find.byKey(const ValueKey('matching-saved-Shakthi')),findsNothing);
  await tester.tap(find.byKey(const ValueKey('matching-saved-Saran'))); await tester.pump();
  await tester.enterText(find.byType(TextField),''); await tester.pump();
  await tester.tap(find.text('Girl’s Kundli')); await tester.pump();
  expect(tester.widget<ListTile>(find.byKey(const ValueKey('matching-saved-Saran'))).onTap,isNull);
  await tester.tap(find.byKey(const ValueKey('matching-saved-Shakthi'))); await tester.pump();
  await tester.ensureVisible(find.byType(CheckboxListTile)); await tester.tap(find.byType(CheckboxListTile)); await tester.pump();
  await tester.ensureVisible(find.text('Match Horoscope')); await tester.tap(find.text('Match Horoscope')); await tester.pumpAndSettle();
  expect(sent!['boy']['datetime'],'2002-07-29T05:00:00+05:30'); expect(sent!['girl']['datetime'],'2001-09-16T05:00:00+05:30');
  expect(find.text('17.5 / 36'),findsWidgets); expect(find.text('1.5 / 3'),findsWidgets);
  await tester.pumpWidget(const SizedBox()); one.session.dispose(); two.session.dispose();
 });
}
