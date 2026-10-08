import 'bronze_theme.dart';
import 'services/marketing_analytics.dart';
import 'services/user_journey.dart';
import 'services/remote_config.dart';
import 'services/ui_language.dart';
import 'services/notification_inbox.dart';
import 'route_nav.dart';

import 'dart:convert';
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:razorpay_flutter/razorpay_flutter.dart';

import 'payment_support.dart';
import 'launch_intro.dart';

const coinWalletEnabled = bool.fromEnvironment('JYOTARA_COIN_WALLET');
// Receipt amounts are server-authoritative; free allowance is not a paid answer.
String coinReceiptLabel(Map<String, dynamic> receipt) {
  final depth = receipt['depth'];
  if (receipt['coins'] == 0 && receipt['freeReason'] == 'general_guidance') {
    return '$depth · General guidance · Free';
  }
  if (receipt['status'] == 'failed') return '$depth · Not charged';
  if (receipt['trial'] == true && receipt['coins'] == 0) {
    return '$depth · Introductory answer · Free';
  }
  return '$depth · ${receipt['coins']} coins';
}

final coinNavigator = GlobalKey<NavigatorState>();
AccountService? coinAccount;

Future<void> recordWalletNotices(
  Map<String, dynamic> data,
  String? owner,
) async {
  if (owner == null) return;
  for (final order in (data['orders'] as List? ?? []).whereType<Map>()) {
    if (!['paid', 'complimentary'].contains(order['status'])) continue;
    final coins = order['coins'];
    if (coins is! num || coins <= 0) continue;
    await notificationInbox.add(
      AppNotice(
        id: 'wallet:$owner:${order['id']}',
        account: owner,
        title: 'Coins added',
        body: '$coins coins added to your wallet',
        time: DateTime.fromMillisecondsSinceEpoch(
          (order['updated_at'] as num? ??
                  order['created_at'] as num? ??
                  DateTime.now().millisecondsSinceEpoch)
              .toInt(),
        ),
      ),
    );
  }
}

final coinWalletRevision = ValueNotifier<int>(0);
final _coinConsentZone = Object();

// Explicit top-of-chat selection authorizes the displayed price schedule only.
// The server still quotes every request and enforces the actual debit.
class CoinChatConsent {
  const CoinChatConsent(
    this.account,
    this.depth,
    this.maximum, {
    this.upgrade,
    this.generalCoins,
    this.relationshipCoins,
  });
  final String? account;
  final String depth;
  final int maximum;
  final String? upgrade;
  final int? generalCoins;
  final int? relationshipCoins;
  bool accepts(
    String? owner,
    Map<String, dynamic> payload,
    Map<String, dynamic> quote,
  ) =>
      owner != null &&
      owner == account &&
      payload['depth'] == depth &&
      payload['upgradeFrom'] == upgrade &&
      quote['depth'] == depth &&
      quote['cost'] is num &&
      quote['cost'] >= 0 &&
      quote['cost'] <= maximum &&
      (quote['cost'] == 0 ||
          quote['cost'] ==
              (upgrade != null
                  ? maximum
                  : ([
                          'Love',
                          'Relationships',
                          'Breakup',
                          'Marriage',
                        ].contains(quote['category'])
                        ? (relationshipCoins ?? (depth == 'detailed' ? 30 : 15))
                        : (generalCoins ??
                              (depth == 'detailed' ? 20 : 10))))) &&
      quote['canProceed'] == true;
}

Future<T> withCoinChatConsent<T>(
  CoinChatConsent? consent,
  Future<T> Function() action,
) => runZoned(action, zoneValues: {_coinConsentZone: consent});

Future<Map<String, dynamic>> confirmCoins(
  String action,
  Map<String, dynamic> payload,
) async {
  final api = coinAccount;
  if (api == null) {
    throw const AccountServiceError('Sign in to open your coin wallet.');
  }
  final account = api.account();
  final q = await api.post('/api/wallet/quote', {
    'action': action,
    'payload': payload,
  });
  final context = coinNavigator.currentContext;
  if (context == null || !context.mounted) {
    throw const AccountServiceError('Please reopen this screen.');
  }
  if (account != api.account()) {
    throw const AccountServiceError('Your account changed. Please try again.');
  }
  if (q['reopening'] == true) return {...payload, 'coinQuote': q['quote']};
  // The matching action itself displays the fixed price; no duplicate popup.
  if (action == 'matching') {
    if (q['category'] != 'Basic matching' || q['cost'] != 20) {
      throw const AccountServiceError(
        'Matching price changed. Please reopen matching before continuing.',
      );
    }
    if (q['canProceed'] != true) {
      final topUp = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Not enough coins'),
          content: Text(
            'Matching needs 20 coins. Your balance is ${q['balance']} coins. No coins used.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Get coins'),
            ),
          ],
        ),
      );
      if (topUp == true && context.mounted) {
        await Navigator.of(context).push(
          MaterialPageRoute<void>(builder: (_) => CoinWalletScreen(api: api)),
        );
      }
      throw const AccountServiceError(
        'Not enough coins. Top up, then tap Match again. No coins used.',
      );
    }
    return {...payload, 'coinQuote': q['quote']};
  }

  final consent = Zone.current[_coinConsentZone] as CoinChatConsent?;
  if (action == 'guidance' && consent?.accepts(account, payload, q) == true) {
    return {...payload, 'coinQuote': q['quote']};
  }
  if (action == 'guidance' && consent != null && q['canProceed'] != true) {
    throw const AccountServiceError(
      'Not enough coins for this reading. Open coin packages on Home to top up. No coins used.',
    );
  }
  final accepted = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(
        '${q['category']} · ${q['depth'] == 'detailed' ? 'Detailed' : 'Standard'}',
      ),
      content: Text(
        '${q['trial'] == true ? 'Your introductory Standard answer is free.' : 'This reading costs ${q['cost']} coins.'}\n\n${action == 'matching' ? 'Both selected birth profiles will be compared. Reopening this result is free.' : 'Coins are used only for a completed reading. Failed answers are free.'}${walletMode == 'test' ? '\n\nTest wallet — no real money.' : ''}',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: const Text('Cancel'),
        ),
        if (q['canProceed'] != true)
          FilledButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Not enough coins'),
          )
        else
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(
              q['cost'] == 0 ? 'Continue free' : 'Use ${q['cost']} coins',
            ),
          ),
      ],
    ),
  );
  if (accepted != true) {
    throw const AccountServiceError(
      'Reading cancelled. No coins used. Open Coin wallet to add coins.',
    );
  }
  if (account != api.account()) {
    throw const AccountServiceError('Your account changed. Please try again.');
  }
  return {...payload, 'coinQuote': q['quote']};
}

class HomeCoinCard extends StatefulWidget {
  const HomeCoinCard({super.key, this.compact = false});
  final bool compact;
  @override
  State<HomeCoinCard> createState() => _HomeCoinCardState();
}

class _HomeCoinCardState extends State<HomeCoinCard>
    with WidgetsBindingObserver {
  Map<String, dynamic>? _data;
  String? _owner;
  bool _failed = false;
  int _request = 0;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    coinWalletRevision.addListener(_load);
    _load();
  }

  @override
  void dispose() {
    coinWalletRevision.removeListener(_load);
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _load();
  }

  Future<void> _load() async {
    final api = coinAccount;
    final owner = api?.account();
    final request = ++_request;
    if (owner == null || api == null) {
      if (mounted) {
        setState(() {
          _data = null;
          _owner = null;
        });
      }
      return;
    }
    try {
      final data = await api.post('/api/wallet/status', {});
      if (owner == api.account()) await recordWalletNotices(data, owner);
      if (owner == api.account()) {
        await marketingAnalytics.reconcilePurchases(data);
      }
      if (mounted && request == _request && owner == api.account()) {
        setState(() {
          _data = data;
          _owner = owner;
          _failed = false;
        });
      }
    } catch (_) {
      if (mounted && request == _request) {
        setState(() {
          _data = null;
          _failed = true;
        });
      }
    }
  }

  Future<void> _open() async {
    final api = coinAccount;
    if (api == null) return;
    await Navigator.push(
      context,
      MaterialPageRoute<void>(
        builder: (_) => CoinWalletScreen(api: api, originTab: 0),
      ),
    );
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    final data = _owner == coinAccount?.account() ? _data : null;
    if (widget.compact) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: BronzePalette.accent,
            borderRadius: BorderRadius.circular(16),
          ),
          child: TextButton(
            key: const Key('headerCoins'),
            style: TextButton.styleFrom(
              foregroundColor: BronzePalette.onAccent,
              minimumSize: const Size(44, 44),
              padding: const EdgeInsets.symmetric(horizontal: 10),
            ),
            onPressed: _open,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const RupeeCoinIcon(size: 20),
                const SizedBox(width: 5),
                Text(
                  data == null
                      ? uiText(context, 'Coins')
                      : '${data['balance']}',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(width: 4),
                const Icon(Icons.add, size: 13),
              ],
            ),
          ),
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: OutlinedButton(
        style: OutlinedButton.styleFrom(
          backgroundColor: BronzePalette.card,
          foregroundColor: BronzePalette.ink,
          side: const BorderSide(color: BronzePalette.border),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        onPressed: _open,
        child: Row(
          children: [
            const _HomeGoldCoin(),
            const SizedBox(width: 12),
            Expanded(
              child: UiText(
                data == null
                    ? (_failed ? 'Balance unavailable' : 'Coins · …')
                    : '${data['balance']} coins',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            const Icon(Icons.chevron_right, color: BronzePalette.gold),
          ],
        ),
      ),
    );
  }
}

/// A raised gold coin, distinct from the wallet's navigation icons.
class _HomeGoldCoin extends StatelessWidget {
  const _HomeGoldCoin();
  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: Container(
      width: 42,
      height: 42,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFFFE9A4), Color(0xFFE5B958), Color(0xFFAC7025)],
        ),
        border: Border.all(color: const Color(0xFFF9D784), width: 1.5),
        boxShadow: const [
          BoxShadow(
            color: Color(0x44100000),
            blurRadius: 5,
            offset: Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.all(3),
      child: Container(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: const Color(0xFF9E692B)),
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFFCD973D), Color(0xFFF6D784)],
          ),
        ),
        child: const Center(
          child: Text(
            '₹',
            style: TextStyle(
              fontFamily: 'JyotaraEditorial',
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: Color(0xFF8B581C),
              shadows: [Shadow(color: Color(0xFFFFEDB4), offset: Offset(0, 1))],
            ),
          ),
        ),
      ),
    ),
  );
}

List<Color> _packColors(dynamic id) => id == 'regular'
    ? [const Color(0xFF352719), BronzePalette.gold]
    : [BronzePalette.card, BronzePalette.gold];

class CoinWalletScreen extends StatefulWidget {
  const CoinWalletScreen({super.key, required this.api, this.originTab = 4});
  final int originTab;
  final AccountService api;
  @override
  State<CoinWalletScreen> createState() => _CoinWalletScreenState();
}

class _CoinWalletScreenState extends State<CoinWalletScreen>
    with WidgetsBindingObserver {
  final _store = const FlutterSecureStorage();
  late final Razorpay _razor;
  String? _providerOrder;
  Map<String, dynamic>? _data;
  String? _error, _order;
  bool _busy = false;
  String get _key =>
      'jyotara.coin-purchase.$walletMode.${widget.api.account()}';
  @override
  void initState() {
    super.initState();
    userJourney.screen('wallet');
    WidgetsBinding.instance.addObserver(this);
    _razor = Razorpay();
    _razor.on(Razorpay.EVENT_PAYMENT_SUCCESS, _paymentSuccess);
    _razor.on(Razorpay.EVENT_PAYMENT_ERROR, _paymentFailure);
    _razor.on(Razorpay.EVENT_EXTERNAL_WALLET, _externalWallet);

    _load();
  }

  @override
  void dispose() {
    _razor.clear();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final owner = widget.api.account();
      final data = await widget.api.post('/api/wallet/status', {});
      if (owner == widget.api.account()) await recordWalletNotices(data, owner);
      if (owner == widget.api.account()) {
        await marketingAnalytics.reconcilePurchases(data);
      }
      if (data['mode'] != walletMode) {
        throw const AccountServiceError(
          'Wallet mode mismatch. Please update the app.',
        );
      }
      if (mounted) setState(() => _data = data);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      if (_order != null) {
        _refresh(_order!);
      } else {
        _load();
      }
    }
  }

  Future<void> _buy(
    Map<String, dynamic> pack, {
    String method = 'checkout',
  }) async {
    if (_busy) return;
    if (!remoteConfig.enabled('purchases')) {
      setState(() => _error = remoteConfig.message);
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      // Each package retains its own retry ID; an abandoned pack must not
      // prevent buying another one or lose late payment reconciliation.
      final legacyKey = method == 'qr' ? '$_key.qr' : _key;
      final legacyRaw = await _store.read(key: legacyKey);
      if (legacyRaw != null) {
        final legacy = Map<String, dynamic>.from(jsonDecode(legacyRaw));
        final migratedKey = '$_key.$method.${legacy['packId']}';
        if (await _store.read(key: migratedKey) == null) {
          await _store.write(key: migratedKey, value: legacyRaw);
        }
        await _store.delete(key: legacyKey);
      }
      await _load();
      await _clearFinished();
      final purchaseKey = '$_key.$method.${pack['id']}';
      final saved = await _store.read(key: purchaseKey);
      final pending = saved == null
          ? {
              'requestId': requestId(),
              'packId': pack['id'],
              'paymentMethod': method,
            }
          : Map<String, dynamic>.from(jsonDecode(saved));
      if (pending['packId'] != pack['id']) {
        throw const AccountServiceError(
          'A different pack is awaiting confirmation. Refresh its order first.',
        );
      }
      await _store.write(key: purchaseKey, value: jsonEncode(pending));
      final order = await widget.api.post('/api/wallet/create', pending);
      if (order['id'] is String && order['mode'] == walletMode) {
        await marketingAnalytics.purchaseStarted(order['id'], walletMode);
      }
      if (method == 'qr') {
        if (order['mode'] != walletMode ||
            order['paymentMethod'] != 'qr' ||
            order['amount'] != pack['rupees'] * 100 ||
            order['coins'] != pack['coins'] ||
            order['currency'] != 'INR') {
          throw const AccountServiceError(
            'Unexpected QR details. Contact support.',
          );
        }
        pending['id'] = order['id'];
        await _store.write(key: purchaseKey, value: jsonEncode(pending));
        if (!mounted) return;
        final finished = await Navigator.of(context).push<bool>(
          MaterialPageRoute(
            builder: (_) => CoinQrScreen(api: widget.api, order: order),
          ),
        );
        if (finished == true) await _store.delete(key: purchaseKey);
        await _load();
        await _clearFinished();
        if (mounted) setState(() => _busy = false);
        return;
      }
      if (!['test', 'live'].contains(walletMode) ||
          order['mode'] != walletMode ||
          !(order['keyId'] is String &&
              (order['keyId'] as String).startsWith('rzp_${walletMode}_')) ||
          order['currency'] != 'INR' ||
          order['amount'] != pack['rupees'] * 100 ||
          order['coins'] != pack['coins']) {
        throw const AccountServiceError(
          'Unexpected payment details. Contact support.',
        );
      }
      _order = order['id'];
      pending['id'] = _order;
      await _store.write(key: purchaseKey, value: jsonEncode(pending));
      final providerOrder = order['orderId'];
      if (providerOrder is! String ||
          !RegExp(r'^order_[A-Za-z0-9]+$').hasMatch(providerOrder)) {
        throw const AccountServiceError(
          'Invalid payment order. Please refresh.',
        );
      }
      _providerOrder = providerOrder;
      userJourney.event(
        'payment.checkout',
        metadata: {'feature': 'wallet', 'outcome': 'started'},
      );
      _razor.open({
        'key': order['keyId'],
        'order_id': providerOrder,
        'amount': order['amount'],
        'currency': 'INR',
        'name': 'Jyotara',
        'description': '${order['coins']} coins',
        'retry': {'enabled': false},
        'theme': {'color': '#B98A45'},
      });
      // Keep this order locked until checkout returns a result.
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _busy = false;
        });
      }
    }
  }

  Future<void> _paymentSuccess(PaymentSuccessResponse result) async {
    if (!mounted) return;
    try {
      if (_order == null ||
          result.orderId != _providerOrder ||
          result.paymentId == null ||
          result.signature == null) {
        throw const AccountServiceError(
          'Payment result incomplete. Refresh payment status before paying again.',
        );
      }
      await widget.api.post('/api/wallet/verify', {
        'id': _order,
        'paymentId': result.paymentId,
        'signature': result.signature,
      });
      await _load();
      await _clearFinished();
      final paid = ((_data?['orders'] as List?) ?? []).any(
        (order) => order['id'] == _order && order['status'] == 'paid',
      );
      userJourney.event(
        'payment.verify',
        metadata: {
          'feature': 'wallet',
          'outcome': paid ? 'success' : 'pending',
        },
      );
      coinWalletRevision.value++;
      if (mounted) {
        setState(
          () => _error = paid ? null : 'Payment is awaiting confirmation. Refresh before paying again.',
        );
        if (paid) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Payment verified. Coins added.')),
          );
        }
      }
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _paymentFailure(PaymentFailureResponse result) async {
    if (!mounted) return;
    userJourney.event(
      'payment.checkout',
      metadata: {'feature': 'wallet', 'outcome': 'failed', 'error': 'payment'},
    );
    setState(() {
      _busy = false;
      _error = 'Payment cancelled or unsuccessful. Refresh payment status before retrying.';
    });
    if (_order != null) await _refresh(_order!);
  }

  Future<void> _externalWallet(ExternalWalletResponse result) async {
    if (!mounted) return;
    setState(() {
      _busy = false;
      _error = 'Complete payment in your wallet, then refresh payment status.';
    });
    if (_order != null) await _refresh(_order!);
  }

  Future<void> _clearFinished() async {
    for (final key in [
      _key,
      '$_key.qr',
      for (final method in ['checkout', 'qr'])
        for (final pack in ['starter', 'regular', 'plus', 'premium', 'max'])
          '$_key.$method.$pack',
    ]) {
      final raw = await _store.read(key: key);
      if (raw == null) continue;
      final saved = jsonDecode(raw);
      final orders = (_data?['orders'] as List?) ?? [];
      if (orders.any(
        (o) =>
            o['id'] == saved['id'] &&
            ['paid', 'refunded', 'failed', 'expired'].contains(o['status']),
      )) {
        await _store.delete(key: key);
      }
    }
  }

  Future<void> _refresh(String id) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await widget.api.post('/api/wallet/refresh', {'id': id});
      await _load();
      await _clearFinished();
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    bottomNavigationBar: RouteNavigation(
      selected: widget.originTab,
      enabled: !_busy,
    ),
    appBar: AppBar(
      centerTitle: true,
      title: const Text(
        'Jyotara',
        style: TextStyle(fontFamily: 'JyotaraEditorial', fontSize: 25),
      ),
      actions: [
        IconButton(
          onPressed: _busy ? null : _load,
          icon: const Icon(Icons.refresh),
        ),
      ],
    ),
    body: ListView(
      padding: const EdgeInsets.all(20),
      children: [
        const Text(
          'Buy Coins',
          style: TextStyle(fontFamily: 'JyotaraEditorial', fontSize: 29),
        ),
        const SizedBox(height: 6),
        const Text(
          'Use coins for deeper insights, reports and guided chats.',
          style: TextStyle(color: BronzePalette.muted),
        ),
        const SizedBox(height: 18),
        Container(
          padding: const EdgeInsets.all(16),
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            border: Border.all(color: BronzePalette.border),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            children: [
              const Expanded(child: Text('Your balance')),
              const _HomeGoldCoin(),
              const SizedBox(width: 10),
              Text(
                '${_data?['balance'] ?? '…'} coins',
                style: const TextStyle(fontSize: 17),
              ),
            ],
          ),
        ),
        if (_error != null)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Text(_error!, style: const TextStyle(color: Colors.red)),
          ),
        const SizedBox(height: 18),
        for (final p in (_data?['packs'] as List? ?? []))
          EntranceReveal(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: PressFeedback(
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    backgroundColor: _packColors(p['id'])[0],
                    foregroundColor: BronzePalette.ink,
                    side: BorderSide(
                      color: _packColors(
                        p['id'],
                      )[1].withValues(alpha: p['id'] == 'regular' ? .8 : .28),
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 18,
                      vertical: 12,
                    ),
                  ),
                  onPressed: _busy
                      ? null
                      : () => _buy(Map<String, dynamic>.from(p)),
                  child: Row(
                    children: [
                      const SizedBox(
                        width: 27,
                        height: 27,
                        child: FittedBox(child: _HomeGoldCoin()),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${p['coins']} coins',
                              style: const TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            if (p['id'] == 'regular')
                              const Padding(
                                padding: EdgeInsets.only(top: 4),
                                child: Text(
                                  'Recommended',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: BronzePalette.gold,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                      Text(
                        '₹${p['rupees']}',
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Icon(Icons.chevron_right, size: 18),
                    ],
                  ),
                ),
              ),
            ),
          ),
        const SizedBox(height: 16),
        Text(
          walletMode == 'live'
              ? 'Secure payment via Razorpay · Prices in INR'
              : 'TEST MODE · No real money',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
        const Text(
          'One-time packs · No automatic renewal · Purchased coins do not expire',
        ),
        const SizedBox(height: 16),
        const Text(
          'How coins work',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        Text(
          "Chat: ${remoteConfig.cost('generalStandard', 10)} coins · Relationships: ${remoteConfig.cost('relationshipStandard', 15)} coins\nMatching: ${remoteConfig.cost('matching', 20)} coins per new result. Failed readings and saved answers cost nothing.",
        ),
        const SizedBox(height: 24),
        const Text(
          'Purchases',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        for (final o in (_data?['orders'] as List? ?? []))
          ListTile(
            title: Text('${o['coins']} coins · ${o['status']}'),
            subtitle: Text(
              '₹${(o['amount'] as num) / 100}${o['refund_review'] == 1 ? ' · Refund requires support review' : ''}',
            ),
            trailing: IconButton(
              tooltip: 'Refresh payment',
              onPressed: _busy ? null : () => _refresh(o['id']),
              icon: const Icon(Icons.refresh),
            ),
          ),
        const SizedBox(height: 16),
        const Text(
          'Coin activity',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        for (final u in (_data?['activity'] as List? ?? []))
          ListTile(
            title: Text('${u['category']} · ${u['depth']}'),
            subtitle: Text(
              '${u['status']}${u['trial'] == 1 ? ' · Introductory answer' : ''}',
            ),
            trailing: Text('${u['status'] == 'failed' ? 0 : u['cost']} coins'),
          ),
      ],
    ),
  );
}

class CoinQrScreen extends StatefulWidget {
  const CoinQrScreen({super.key, required this.api, required this.order});
  final AccountService api;
  final Map<String, dynamic> order;
  @override
  State<CoinQrScreen> createState() => _CoinQrScreenState();
}

class _CoinQrScreenState extends State<CoinQrScreen>
    with WidgetsBindingObserver {
  Timer? _timer;
  bool _checking = false, _paid = false, _active = true;
  String? _error;
  bool get _expired =>
      DateTime.now().millisecondsSinceEpoch >=
      (widget.order['expiresAt'] as num);
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _timer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (_active && !_paid) _check();
    });
    _check();
  }

  @override
  void dispose() {
    _timer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _active = state == AppLifecycleState.resumed;
    if (_active) _check();
  }

  Future<void> _check() async {
    if (_checking || _paid) return;
    setState(() => _checking = true);
    try {
      final r = await widget.api.post('/api/wallet/refresh', {
        'id': widget.order['id'],
      });
      if (r['mode'] != walletMode) {
        throw const AccountServiceError('Payment mode mismatch.');
      }
      if (mounted) {
        setState(() {
          _paid = r['status'] == 'paid';
          _error = r['status'] == 'refunded'
              ? 'This purchase has been refunded.'
              : null;
        });
      }
      if (_paid) {
        _timer?.cancel();
        coinWalletRevision.value++;
      }
    } catch (_) {
      if (mounted) {
        setState(
          () => _error = 'Could not check payment. If you paid, do not pay again. Tap Check payment.',
        );
      }
    } finally {
      if (mounted) setState(() => _checking = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final image = Uri.tryParse(widget.order['imageUrl'] as String? ?? '');
    final allowed =
        image != null &&
        image.scheme == 'https' &&
        ['rzp.io', 'rzp.in'].contains(image.host);
    return Scaffold(
      appBar: AppBar(title: const Text('Pay using another phone')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              '${widget.order['coins']} coins · ₹${(widget.order['amount'] as num) ~/ 100}',
              style: Theme.of(context).textTheme.headlineSmall,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            if (_paid) ...[
              const Icon(Icons.check_circle, size: 64, color: Colors.green),
              const Text(
                'Payment verified. Coins added.',
                textAlign: TextAlign.center,
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Done'),
              ),
            ] else ...[
              const Text(
                'Open Google Pay, PhonePe or another UPI app on your other phone and scan this QR.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              if (_expired)
                const Text(
                  'This QR has expired. If you already paid, check payment before trying again.',
                  textAlign: TextAlign.center,
                )
              else if (allowed)
                Container(
                  color: Colors.white,
                  padding: const EdgeInsets.all(12),
                  child: Image.network(
                    image.toString(),
                    height: 350,
                    width: double.infinity,
                    fit: BoxFit.contain,
                    errorBuilder: (_, e, st) => const Padding(
                      padding: EdgeInsets.all(24),
                      child: Text(
                        'QR could not load. Check your connection and reopen this purchase.',
                      ),
                    ),
                    loadingBuilder: (_, child, progress) => progress == null
                        ? child
                        : const SizedBox(
                            height: 240,
                            child: Center(child: CircularProgressIndicator()),
                          ),
                  ),
                )
              else
                const Text('QR unavailable. Contact support.'),
              const SizedBox(height: 16),
              const Text(
                'Pay only once. Coins are added after payment verification.',
                textAlign: TextAlign.center,
              ),
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Text(_error!, textAlign: TextAlign.center),
                ),
              FilledButton(
                onPressed: _checking ? null : _check,
                child: Text(_checking ? 'Checking payment…' : 'Check payment'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// INR coin emblem shared by compact navigation and wallet entry points.
class RupeeCoinIcon extends StatelessWidget {
  const RupeeCoinIcon({super.key, this.size = 24});
  final double size;
  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: const Color(0xFF805923), width: 1.2),
        gradient: const LinearGradient(
          colors: [Color(0xFFFFE9A4), Color(0xFFE5B958)],
        ),
      ),
      child: Text(
        '₹',
        style: TextStyle(
          fontFamily: 'JyotaraSans',
          color: const Color(0xFF69451C),
          fontSize: size * .65,
          height: 1,
          fontWeight: FontWeight.w600,
        ),
      ),
    ),
  );
}
