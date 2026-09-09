import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:jyotara/discovery_screens.dart';
import 'package:jyotara/birth_form.dart';
import 'package:jyotara/services/profile_session.dart';
import 'package:jyotara/services/profile_gender.dart';

void main(){
 setUp(()=>FlutterSecureStorage.setMockInitialValues({}));
 testWidgets('editing matching details restores the confirmed time and submits from the real button',(tester)async{
  Map<String,dynamic>? submitted;
  await tester.pumpWidget(MaterialApp(home:Builder(builder:(context)=>Scaffold(body:TextButton(
   onPressed:()=>Navigator.of(context).push(MaterialPageRoute<void>(builder:(_)=>BirthForm(
    session:ProfileSession(),initialGender:ProfileGender.male,
    initialDetails:{'nickname':'Test Person','datetime':'1995-01-10T08:30:00+05:30','latitude':11.34,'longitude':77.72,'exactTime':true,'birthplaceLabel':'Erode'},
    onSubmit:(body)async{submitted=body;},
   ))),child:const Text('Open form'),
  )))));
  await tester.tap(find.text('Open form'));await tester.pumpAndSettle();
  await tester.scrollUntilVisible(find.byType(CheckboxListTile),200,scrollable:find.byType(Scrollable).first);await tester.ensureVisible(find.byType(Checkbox).last);await tester.pumpAndSettle();
  await tester.tap(find.byType(Checkbox).last);await tester.pump();
  await tester.scrollUntilVisible(find.text('Use these birth details'),200,scrollable:find.byType(Scrollable).first);await tester.ensureVisible(find.text('Use these birth details'));await tester.pumpAndSettle();
  await tester.tap(find.text('Use these birth details'));await tester.pumpAndSettle();
  expect(submitted,isNotNull);
  expect(submitted!['datetime'],'1995-01-10T08:30:00+05:30');
  expect(submitted!['exactTime'],true);
  expect(submitted!['birthplaceLabel'],'Erode');
  expect(find.text('Open form'),findsOneWidget);
 });
 testWidgets('matching button gives visible feedback when both profiles are missing',(tester)async{
  await tester.pumpWidget(const MaterialApp(home:MatchingScreen()));await tester.pumpAndSettle();
  await tester.scrollUntilVisible(find.text('Match Horoscope'),200,scrollable:find.byType(Scrollable).first);await tester.ensureVisible(find.text('Match Horoscope'));await tester.pumpAndSettle();
  await tester.tap(find.text('Match Horoscope'));await tester.pumpAndSettle();
  expect(find.byType(AlertDialog),findsOneWidget);
  expect(find.text('Check matching details'),findsOneWidget);
 });
 testWidgets('direct birth details reach matching without calculating separate charts and show result',(tester)async{
  var calls=0;Map<String,dynamic>? submitted;
  await tester.pumpWidget(MaterialApp(home:MatchingScreen(request:(path,body)async{
   calls++;submitted=body;expect(path,'/api/kundli/matching');
   return {'score':24.5,'maximum':36,'interpretation':'Test chart comparison.','note':'Traditional interpretation.','source':'Fixture'};
  })));await tester.pumpAndSettle();
  for(final male in [true,false]){
   final label='${male?'Boy':'Girl'}: Enter birth details';
   await tester.scrollUntilVisible(find.text(label),200,scrollable:find.byType(Scrollable).first);await tester.ensureVisible(find.text(label));await tester.pumpAndSettle();
   await tester.tap(find.text(label));await tester.pumpAndSettle();
   final form=tester.widget<BirthForm>(find.byType(BirthForm));
   expect(form.onSubmit,isNotNull);
   await form.onSubmit!({'nickname':male?'Test A':'Test B','datetime':male?'1995-01-10T08:00:00+05:30':'1996-06-15T09:00:00+05:30','latitude':11.34,'longitude':77.72,'exactTime':true});
   Navigator.of(tester.element(find.byType(BirthForm))).pop();await tester.pumpAndSettle();
  }
  await tester.scrollUntilVisible(find.byType(CheckboxListTile),200,scrollable:find.byType(Scrollable).first);await tester.ensureVisible(find.byType(Checkbox).last);await tester.pumpAndSettle();
  await tester.tap(find.byType(Checkbox));await tester.pump();
  await tester.scrollUntilVisible(find.text('Match Horoscope'),200,scrollable:find.byType(Scrollable).first);await tester.ensureVisible(find.text('Match Horoscope'));await tester.pumpAndSettle();
  await tester.tap(find.text('Match Horoscope'));await tester.pumpAndSettle();
  expect(calls,1);expect(submitted!['consent'],true);
  expect(submitted!['boy']['nickname'],'Test A');
  expect(find.text('Matching result: 24.5 / 36'),findsOneWidget);
  expect(tester.takeException(),isNull);
 });
}
