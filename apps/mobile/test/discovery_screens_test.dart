import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:jyotara/discovery_screens.dart';
import 'package:jyotara/birth_form.dart';

void main(){
 TestWidgetsFlutterBinding.ensureInitialized();
 test('Kundli library survives reload and deletion leaves the personal vault untouched',()async{
  FlutterSecureStorage.setMockInitialValues({'nirayana.private-profile.v1':'personal-record'});
  final a=await KundliLibrary.create([]);
  final b=await KundliLibrary.create([a]);
  final restored=await KundliLibrary.load();
  expect(restored.map((r)=>r.id),[a.id,b.id]);
  await KundliLibrary.remove(restored.first,restored);
  expect((await KundliLibrary.load()).map((r)=>r.id),[b.id]);
  expect(await KundliLibrary.storage.read(key:'nirayana.private-profile.v1'),'personal-record');
 });
 testWidgets('cancelled new Kundli leaves no unfinished row and Create works again',(tester)async{
  FlutterSecureStorage.setMockInitialValues({});
  await tester.pumpWidget(const MaterialApp(home:KundliLibraryScreen()));await tester.pumpAndSettle();
  for(var i=0;i<2;i++){
   await tester.ensureVisible(find.text('Create New Kundli'));await tester.tap(find.text('Create New Kundli'));await tester.pumpAndSettle();
   expect(find.byType(BirthForm),findsOneWidget);
   Navigator.of(tester.element(find.byType(BirthForm))).pop();await tester.pumpAndSettle();
   expect(await KundliLibrary.load(),isEmpty);
   expect(find.text('Unfinished Kundli'),findsNothing);
  }
 });
 testWidgets('failed library load cannot replace the saved index',(tester)async{
  FlutterSecureStorage.setMockInitialValues({KundliLibrary.indexKey:'unreadable'});
  await tester.pumpWidget(const MaterialApp(home:KundliLibraryScreen()));
  await tester.pumpAndSettle();
  expect(find.text('Retry loading Kundlis'),findsOneWidget);
  expect(tester.widget<FilledButton>(find.widgetWithText(FilledButton,'Create New Kundli')).onPressed,isNull);
  expect(await KundliLibrary.storage.read(key:KundliLibrary.indexKey),'unreadable');
 });
 testWidgets('wallet preview cannot collect money and caps choices at 4000',(tester)async{
   await tester.pumpWidget(const MaterialApp(home:WalletScreen()));
   await tester.scrollUntilVisible(find.text('₹4000'),200);
   await tester.tap(find.text('₹4000'));await tester.pump();
   await tester.scrollUntilVisible(find.text('Payments coming later'),200);
   expect(find.text('Selected recharge: ₹4000'),findsOneWidget);
   expect(tester.widget<FilledButton>(find.widgetWithText(FilledButton,'Payments coming later')).onPressed,isNull);
   expect(find.text('₹8000'),findsNothing);
   expect(tester.takeException(),isNull);
 });
 testWidgets('home shortcuts include the three requested tools and wallet',(tester)async{
  await tester.pumpWidget(const MaterialApp(home:Scaffold(body:DiscoveryActions())));
  expect(find.text('Daily\nHoroscope'),findsOneWidget);
  expect(find.text('Free\nKundli'),findsOneWidget);
  expect(find.text('Kundli\nMatching'),findsOneWidget);
  await tester.tap(find.text('Wallet · ₹0  +'));await tester.pumpAndSettle();
  expect(find.text('Wallet preview'),findsOneWidget);
 });
}
