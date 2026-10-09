import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:jyotara/coin_wallet.dart';
import 'package:jyotara/payment_support.dart';
import 'package:jyotara/discovery_screens.dart';

class MatchWallet extends AccountService {
  MatchWallet({this.quoteCost})
    : super(
        token: () => 'token',
        tester: () => 'tester',
        account: () => 'account',
      );
  final int? quoteCost;
  @override
  Future<Map<String, dynamic>> post(
    String path,
    Map<String, dynamic> body,
  ) async => {
    'category': 'Basic matching',
    'cost': quoteCost ?? matchingCoinCost,
    'canProceed': true,
    'quote': 'fresh-quote',
    'balance': 1000,
  };
}

void main() {
  testWidgets(
    'matching uses the same live wallet as its quote without a confirmation popup',
    (tester) async {
      coinAccount = MatchWallet();
      await tester.pumpWidget(
        MaterialApp(navigatorKey: coinNavigator, home: const Scaffold()),
      );
      Map<String, dynamic>? sent;
      String? mode;
      String? catalog;
      final client = MockClient((request) async {
        mode = request.headers['X-Jyotara-Wallet-Mode'];
        catalog = request.headers['X-Jyotara-Wallet-Catalog'];
        sent = jsonDecode(request.body) as Map<String, dynamic>;
        return http.Response(
          jsonEncode({
            'score': 18,
            'maximum': 36,
            'wallet': {'coins': matchingCoinCost},
          }),
          200,
        );
      });
      final result = await discoveryRequest('/api/kundli/matching', {
        'boy': {'nickname': 'A'},
        'girl': {'nickname': 'B'},
        'consent': true,
      }, client: client);
      expect(mode, 'live');
      expect(catalog, minuteBillingEnabled ? '2' : null);
      expect(sent?['coinQuote'], 'fresh-quote');
      expect(result['score'], 18);
      expect(find.byType(AlertDialog), findsNothing);
      await tester.pumpWidget(const SizedBox());
      coinAccount = null;
    },
  );
  testWidgets('a stale Matching price is rejected before the provider call', (
    tester,
  ) async {
    coinAccount = MatchWallet(quoteCost: matchingCoinCost + 1);
    await tester.pumpWidget(
      MaterialApp(navigatorKey: coinNavigator, home: const Scaffold()),
    );
    var called = false;
    final client = MockClient((request) async {
      called = true;
      return http.Response('{}', 200);
    });
    await expectLater(
      discoveryRequest('/api/kundli/matching', {
        'boy': {'nickname': 'A'},
        'girl': {'nickname': 'B'},
        'consent': true,
      }, client: client),
      throwsException,
    );
    expect(called, false);
    expect(find.byType(AlertDialog), findsNothing);
    coinAccount = null;
  });
  for (final score in [18, 27]) {
    testWidgets('matching percentage is calculated from score $score', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: MatchingReport(
                value: {
                  'score': score,
                  'maximum': 36,
                  'boyName': 'Demo A',
                  'girlName': 'Demo B',
                  'interpretation': 'Comparison',
                  'note': 'Traditional chart score',
                  'factors': [],
                },
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('${(score / 36 * 100).round()}%'), findsOneWidget);
    });
  }
  testWidgets(
    'matching factor uses its actual chart percentage and a short friendly label',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: MatchingReport(
                value: {
                  'score': 18,
                  'maximum': 36,
                  'interpretation': 'Traditional comparison',
                  'note': 'Chart points',
                  'factors': [
                    {
                      'id': 6,
                      'name': 'Personality Fit',
                      'score': 2,
                      'maximum': 6,
                      'description': 'Compares your personality types based on your birth stars.',
                    },
                  ],
                },
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Personality Fit'), findsOneWidget);
      expect(find.text('33%'), findsOneWidget);
      expect(find.text('2 / 6'), findsNothing);
      expect(find.text('Partial points'), findsNothing);
    },
  );
}
