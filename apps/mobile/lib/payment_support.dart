import 'coin_wallet.dart' show minuteBillingEnabled;
import 'services/remote_config.dart';
import 'services/user_journey.dart';

import 'dart:convert';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:razorpay_flutter/razorpay_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import 'services/jyotara_api.dart';

const configuredWalletMode = String.fromEnvironment(
  'JYOTARA_WALLET_MODE',
  defaultValue: 'test',
);
bool Function() officeDemoAccount = () => false;
String get walletMode => officeDemoAccount() ? 'test' : configuredWalletMode;
const paymentQaEnabled = bool.fromEnvironment(
  'JYOTARA_TEST_PAYMENTS',
  defaultValue: false,
);
String requestId() => List.generate(
  24,
  (_) => Random.secure().nextInt(256).toRadixString(16).padLeft(2, '0'),
).join();

class AccountService {
  AccountService({
    required this.token,
    required this.tester,
    required this.account,
  });
  final String? Function() token, tester, account;
  Future<Map<String, dynamic>> post(
    String path,
    Map<String, dynamic> body,
  ) async {
    final feature = path.startsWith('/api/notifications/')
        ? 'notification'
        : path.startsWith('/api/support/')
        ? 'support'
        : 'wallet';
    final event = path.endsWith('/create')
        ? (feature == 'support' ? 'support.send' : 'payment.start')
        : path.endsWith('/verify')
        ? 'payment.verify'
        : path.endsWith('/refresh')
        ? 'payment.refresh'
        : 'api.request';
    final watch = Stopwatch()..start();
    userJourney.event(
      event,
      metadata: {'feature': feature, 'outcome': 'started'},
    );
    final base = Uri.parse(defaultApiBaseUrl);
    if (base.scheme != 'https' || token() == null) {
      userJourney.event(
        event,
        metadata: {
          'feature': feature,
          'outcome': 'failed',
          'error': 'unauthorized',
        },
      );
      throw Exception('Please sign in again.');
    }
    try {
      final r = await http
          .post(
            base.resolve(path),
            headers: {
              'Content-Type': 'application/json',
              'X-Jyotara-Wallet-Mode': walletMode,
              if (minuteBillingEnabled) 'X-Jyotara-Wallet-Catalog': '2',
              'Authorization': 'Bearer ${token()}',
              if (tester() != null) 'X-Jyotara-Tester-Code': tester()!,
            },
            body: jsonEncode(body),
          )
          .timeout(const Duration(seconds: 25));
      final data = jsonDecode(r.body);
      if (data is! Map<String, dynamic>) throw const FormatException();
      userJourney.event(
        event,
        metadata: {
          'feature': feature,
          'outcome': r.statusCode == 200 ? 'success' : 'failed',
          'status': r.statusCode,
          'durationMs': watch.elapsedMilliseconds,
        },
      );
      if (r.statusCode != 200) {
        throw AccountServiceError(
          data['error'] is String
              ? data['error']
              : 'Request could not be completed.',
          code: data['code'] is String ? data['code'] : null,
        );
      }
      return data;
    } on AccountServiceError {
      rethrow;
    } catch (_) {
      userJourney.event(
        event,
        metadata: {
          'feature': feature,
          'outcome': 'failed',
          'error': 'network',
          'durationMs': watch.elapsedMilliseconds,
        },
      );
      throw const AccountServiceError(
        'Unable to confirm the request. Check your connection and refresh before trying again.',
      );
    }
  }
}

class AccountServiceError implements Exception {
  const AccountServiceError(this.message, {this.code});
  final String message;
  final String? code;
  @override
  String toString() => message;
}

class TestPaymentScreen extends StatefulWidget {
  const TestPaymentScreen({super.key, required this.api});
  final AccountService api;
  @override
  State<TestPaymentScreen> createState() => _TestPaymentScreenState();
}

class _TestPaymentScreenState extends State<TestPaymentScreen> {
  late final Razorpay _razor;
  final _storage = const FlutterSecureStorage();
  String? _order, _message;
  bool _busy = false;
  int _credits = 0;
  List<dynamic> _orders = [];
  String get _key => 'jyotara.test-payment.${widget.api.account()}';
  @override
  void initState() {
    super.initState();
    _razor = Razorpay();
    _razor.on(Razorpay.EVENT_PAYMENT_SUCCESS, _success);
    _razor.on(Razorpay.EVENT_PAYMENT_ERROR, _failure);
    _razor.on(Razorpay.EVENT_EXTERNAL_WALLET, _wallet);
    _load();
  }

  @override
  void dispose() {
    _razor.clear();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final d = await widget.api.post('/api/payments/test/history', {});
      if (mounted) {
        setState(() {
          _orders = d['orders'] as List<dynamic>;
          _credits = d['demoCredits'] as int;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _message = e.toString());
    }
  }

  Future<void> _pay() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _message = null;
    });
    try {
      var id = await _storage.read(key: _key);
      id ??= requestId();
      await _storage.write(key: _key, value: id);
      final d = await widget.api.post('/api/payments/test/create', {
        'requestId': id,
      });
      if (d['mode'] != 'test' ||
          !(d['keyId'] as String).startsWith('rzp_test_') ||
          d['amount'] != 100) {
        throw const AccountServiceError(
          'Unexpected payment configuration. Contact support.',
        );
      }
      _order = d['id'] as String;
      _razor.open({
        'key': d['keyId'],
        'order_id': d['orderId'],
        'amount': 100,
        'currency': 'INR',
        'name': 'Jyotara Test',
        'description': 'Test payment only — no real money',
        'retry': {'enabled': false},
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _busy = false;
          _message = e.toString();
        });
      }
    }
  }

  Future<void> _success(PaymentSuccessResponse r) async {
    if (_order == null || r.paymentId == null || r.signature == null) {
      if (mounted) {
        setState(() {
          _busy = false;
          _message =
              'Payment result incomplete. Refresh the order to confirm it.';
        });
      }
      return;
    }
    try {
      final d = await widget.api.post('/api/payments/test/verify', {
        'id': _order,
        'paymentId': r.paymentId,
        'signature': r.signature,
      });
      if (d['status'] == 'paid') {
        await _storage.delete(key: _key);
        _message = 'Test payment verified. One demo credit recorded.';
      } else {
        _message = 'Payment pending. Refresh history; do not pay again.';
      }
    } catch (e) {
      _message = e.toString();
    } finally {
      if (mounted) setState(() => _busy = false);
      await _load();
    }
  }

  void _failure(PaymentFailureResponse r) {
    if (mounted) {
      setState(() {
        _busy = false;
        _message = 'Checkout cancelled or unsuccessful. No credit has been added. You can retry the same order.';
      });
    }
    _load();
  }

  void _wallet(ExternalWalletResponse r) {
    if (mounted) {
      setState(() {
        _busy = false;
        _message = 'Wallet opened. Refresh payment status before trying again.';
      });
    }
  }

  Future<void> _refresh(Map<String, dynamic> row) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final d = await widget.api.post('/api/payments/test/refresh', {
        'id': row['id'],
      });
      _message = 'Payment status: ${d['status']}';
      if (d['status'] == 'paid' || d['status'] == 'refunded') {
        await _storage.delete(key: _key);
      }
    } catch (e) {
      _message = e.toString();
    } finally {
      if (mounted) setState(() => _busy = false);
      await _load();
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Test payments')),
    body: ListView(
      padding: const EdgeInsets.all(20),
      children: [
        const Text('TEST MODE', style: TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 12),
        const Text(
          'No real money is charged. This ₹1 test order checks the payment connection. Demo credits cannot be spent on AI chat; launch pricing is not set.',
        ),
        const SizedBox(height: 16),
        Text(
          'Demo credits: $_credits',
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const SizedBox(height: 16),
        FilledButton(
          onPressed: _busy ? null : _pay,
          child: Text(_busy ? 'Please wait…' : 'Start ₹1 test payment'),
        ),
        if (_message != null)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Text(_message!),
          ),
        TextButton(
          onPressed: _busy ? null : _load,
          child: const Text('Reload history'),
        ),
        for (final value in _orders)
          Card(
            child: ListTile(
              title: Text('₹1 test • ${value['status']}'),
              subtitle: Text(
                'Order ${value['provider_order'] ?? 'not confirmed'}',
              ),
              trailing: IconButton(
                tooltip: 'Check payment status',
                onPressed: _busy
                    ? null
                    : () => _refresh(Map<String, dynamic>.from(value)),
                icon: const Icon(Icons.refresh),
              ),
            ),
          ),
        TextButton(
          onPressed: () => Navigator.push(
            context,
            MaterialPageRoute<void>(
              builder: (_) => SupportScreen(api: widget.api),
            ),
          ),
          child: const Text('Payment problem? Contact support'),
        ),
      ],
    ),
  );
}

class SupportScreen extends StatefulWidget {
  const SupportScreen({super.key, required this.api, this.ticketsOnly = false});
  final bool ticketsOnly;
  final AccountService api;
  @override
  State<SupportScreen> createState() => _SupportScreenState();
}

class _SupportScreenState extends State<SupportScreen> {
  final _text = TextEditingController();
  String _category = 'app', _id = requestId();
  bool _consent = false, _busy = false, _loadingTickets = true;
  String? _message;
  List<dynamic> _tickets = [];
  @override
  void initState() {
    super.initState();
    if (paymentQaEnabled || const bool.fromEnvironment('JYOTARA_COIN_WALLET')) {
      _load();
    }
  }

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final d = await widget.api.post('/api/support/list', {});
      if (mounted) {
        setState(() {
          _tickets = d['tickets'] as List<dynamic>;
          _message = null;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _message = e.toString());
    } finally {
      if (mounted) setState(() => _loadingTickets = false);
    }
  }

  Future<void> _send() async {
    if (_busy || !_consent) return;
    setState(() => _busy = true);
    try {
      final d = await widget.api.post('/api/support/create', {
        'requestId': _id,
        'category': _category,
        'message': _text.text.trim(),
        'consent': true,
      });
      _message =
          'Ticket raised successfully. Reference: ${d['id']}. Our team will get back to you soon.';
      _id = requestId();
      _text.clear();
      _consent = false;
      await _load();
    } catch (e) {
      _message = e.toString();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _email() async {
    final uri = Uri(
      scheme: 'mailto',
      path: remoteConfig.supportEmail,
      queryParameters: {'subject': 'Jyotara support'},
    );
    if (!await launchUrl(uri) && mounted) {
      setState(
        () => _message =
            'Email ${remoteConfig.supportEmail} using your email app.',
      );
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(widget.ticketsOnly ? 'My Tickets' : 'Help & Support'),
    ),
    body: RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(20),
        children: [
          if (!widget.ticketsOnly) ...[
            const Text(
              'Tell us about an app, account or payment problem. Never send passwords, OTPs or card details.',
            ),
            const SizedBox(height: 12),
            SelectableText(remoteConfig.supportEmail),
            TextButton.icon(
              onPressed: _email,
              icon: const Icon(Icons.email_outlined),
              label: const Text('Email support'),
            ),
          ],
          if ((paymentQaEnabled ||
              const bool.fromEnvironment('JYOTARA_COIN_WALLET'))) ...[
            if (!widget.ticketsOnly) ...[
              DropdownButtonFormField<String>(
                initialValue: _category,
                items: const ['app', 'payment', 'account', 'other']
                    .map((v) => DropdownMenuItem(value: v, child: Text(v)))
                    .toList(),
                onChanged: _busy ? null : (v) => setState(() => _category = v!),
              ),
              TextField(
                controller: _text,
                maxLength: 3000,
                minLines: 4,
                maxLines: 8,
                enabled: !_busy,
                decoration: const InputDecoration(
                  labelText: 'Describe the problem',
                ),
              ),
              CheckboxListTile(
                value: _consent,
                onChanged: _busy
                    ? null
                    : (v) => setState(() => _consent = v ?? false),
                title: const Text(
                  'Send this description and category to the Jyotara team. No chat history or birth details are attached automatically.',
                ),
              ),
              FilledButton(
                onPressed: _busy || !_consent ? null : _send,
                child: Text(_busy ? 'Sending…' : 'Submit request'),
              ),
              if (_message != null)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Text(_message!),
                ),
            ],
            if (_loadingTickets) const LinearProgressIndicator(),
            if (widget.ticketsOnly && _message != null) Text(_message!),
            if (!_loadingTickets && _message == null && _tickets.isEmpty)
              const Padding(
                padding: EdgeInsets.all(20),
                child: Text('No support requests yet.'),
              ),
            TextButton(
              onPressed: _load,
              child: const Text('Refresh my requests'),
            ),
            for (final t in _tickets)
              Card(
                margin: const EdgeInsets.only(bottom: 12),
                child: ListTile(
                  title: Text(
                    '${t['category']}'.replaceFirstMapped(
                      RegExp(r'^.'),
                      (m) => m[0]!.toUpperCase(),
                    ),
                  ),
                  subtitle: Text(
                    '${t['message'] ?? ''}\n#${t['id'].toString().substring(0, 8).toUpperCase()} · ${DateTime.fromMillisecondsSinceEpoch((t['created_at'] as num).toInt()).toLocal()}',
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                  trailing: Chip(
                    backgroundColor:
                        t['status'] == 'closed' || t['status'] == 'resolved'
                        ? const Color(0xFF264D35)
                        : const Color(0xFF5F4928),
                    label: Text(
                      t['status'] == 'submitted'
                          ? 'Open'
                          : '${t['status']}'
                                .replaceAll('_', ' ')
                                .replaceFirstMapped(
                                  RegExp(r'^.'),
                                  (m) => m[0]!.toUpperCase(),
                                ),
                    ),
                  ),
                  onTap: () => showDialog<void>(
                    context: context,
                    builder: (dialog) => AlertDialog(
                      title: Text(
                        'Ticket #${t['id'].toString().substring(0, 8).toUpperCase()}',
                      ),
                      content: SingleChildScrollView(
                        child: Text(
                          '${t['category']} · ${t['status']}\n\n${t['message'] ?? ''}'
                          '${(t['replies'] as List? ?? []).map((r) => '\n\nSupport · ${DateTime.fromMillisecondsSinceEpoch((r['createdAt'] as num).toInt()).toLocal()}\n${r['message']}').join()}',
                        ),
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(dialog),
                          child: const Text('Close'),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ] else if (_message != null)
            Text(_message!),
        ],
      ),
    ),
  );
}
