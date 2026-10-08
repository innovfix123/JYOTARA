import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jyotara/birth_date_picker.dart';
import 'package:jyotara/birth_form.dart';
import 'package:jyotara/services/profile_session.dart';

void main() {
  const formatter = BirthDateInputFormatter();
  TextEditingValue value(String text, [int? offset]) => TextEditingValue(
    text: text,
    selection: TextSelection.collapsed(offset: offset ?? text.length),
  );
  test(
    'DD/MM/YYYY typing and pasting, invalid dates and separator backspace',
    () {
      var current = value('');
      for (final digit in '15072005'.split('')) {
        current = formatter.formatEditUpdate(
          current,
          value('${current.text}$digit'),
        );
      }
      expect(current.text, '15/07/2005');
      expect(
        formatter.formatEditUpdate(value(''), value('15072005')).text,
        '15/07/2005',
      );
      expect(
        formatter.formatEditUpdate(value(''), value('150720059')).text,
        '15/07/2005',
      );
      expect(
        formatter.formatEditUpdate(value('15/07', 3), value('1507', 2)).text,
        '10/7',
      );
      expect(parseBirthDate('31/02/2005'), isNull);
      expect(parseBirthDate('29/02/2004'), DateTime(2004, 2, 29));
      expect(parseBirthDate('29/02/2005'), isNull);
    },
  );
  testWidgets(
    'JYOT-14 typed date updates heading, rejects invalid dates and saves DD/MM',
    (tester) async {
      DateTime? result;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => TextButton(
              onPressed: () async {
                result = await showBirthDatePicker(
                  context: context,
                  initialDate: DateTime(2000, 10, 3),
                  firstDate: DateTime(1900),
                  lastDate: DateTime(2013),
                );
              },
              child: const Text('Date'),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Date'));
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.edit_outlined));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const Key('birth-date-input')),
        '15072005',
      );
      await tester.pump();
      expect(
        tester
            .widget<TextField>(find.byKey(const Key('birth-date-input')))
            .controller!
            .text,
        '15/07/2005',
      );
      final heading = tester
          .widget<Text>(find.byKey(const Key('birth-date-heading')))
          .data!;
      expect(heading, contains('Jul 15'));
      await tester.enterText(
        find.byKey(const Key('birth-date-input')),
        '31022005',
      );
      await tester.tap(find.text('OK'));
      await tester.pump();
      expect(result, isNull);
      expect(find.byKey(const Key('birth-date-input')), findsOneWidget);
      await tester.enterText(
        find.byKey(const Key('birth-date-input')),
        '15072025',
      );
      await tester.tap(find.text('OK'));
      await tester.pump();
      expect(result, isNull);
      await tester.enterText(
        find.byKey(const Key('birth-date-input')),
        '15072005',
      );
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();
      expect(result, DateTime(2005, 7, 15));
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'JYOT-13/15/21 full name, required marks, alignment and unknown time',
    (tester) async {
      tester.view.physicalSize = const Size(430, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MaterialApp(home: BirthForm(session: ProfileSession())),
      );
      Finder label(String name) => find.text('$name *', findRichText: true);
      expect(find.text('Enter full name'), findsOneWidget);
      for (final name in [
      'Enter full name',
        'Gender',
        'Date of birth',
        'Exact birth time',
        'Birthplace',
      ]) {
        expect(label(name), findsOneWidget);
      }
      final left = tester.getTopLeft(label('Gender')).dx;
      expect(tester.getTopLeft(label('Date of birth')).dx, left);
      expect(tester.getTopLeft(label('Exact birth time')).dx, left);
      final tiles = tester.widgetList<ListTile>(find.byType(ListTile));
      expect(
        tiles.every((tile) => tile.contentPadding == EdgeInsets.zero),
        true,
      );
      final toggle = find.byType(SwitchListTile);
      expect(
        tester.widget<SwitchListTile>(toggle).contentPadding,
        EdgeInsets.zero,
      );
      await tester.tap(toggle);
      await tester.pump();
      expect(label('Exact birth time'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
}
