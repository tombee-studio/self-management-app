import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'cloud/api.dart';
import 'cloud/session.dart';
import 'core/services/notification_service.dart';
import 'core/theme/app_theme.dart';
import 'presentation/common.dart';
import 'presentation/expense_form.dart';
import 'presentation/ledger.dart';
import 'presentation/settings.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const ProviderScope(child: IrisExpenseApp()));
}

class IrisExpenseApp extends StatelessWidget {
  const IrisExpenseApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'iris 支出管理',
    theme: AppTheme.lightTheme,
    locale: const Locale('ja'),
    supportedLocales: const [Locale('ja')],
    localizationsDelegates: GlobalMaterialLocalizations.delegates,
    home: const AppShell(),
  );
}

class AppShell extends ConsumerStatefulWidget {
  const AppShell({super.key});
  @override
  ConsumerState<AppShell> createState() => _AppShellState();
}

class _AppShellState extends ConsumerState<AppShell>
    with WidgetsBindingObserver {
  final contentKey = GlobalKey();
  int tab = 0;
  DateTime date = DateTime.now();
  int refreshRevision = 0;
  StreamSubscription<dynamic>? links;
  late final notifications = ref.read(notificationGatewayProvider);
  final delivered = <String>{};
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await ref.read(sessionProvider).start();
      if (!mounted) return;
      notifications.onSelect = (id) async {
        try {
          final session = ref.read(sessionProvider);
          final e = await session.getExpense(id);
          if (mounted) await openExpense(context, session, expense: e);
        } catch (e) {
          if (mounted) {
            setState(() => tab = 0);
            message(context, e);
          }
        }
      };
      await notifications.initialize();
      try {
        final initial = await const MethodChannel(
          'com.iris.app/deep_link',
        ).invokeMethod<String>('getInitialUrl');
        if (initial != null) unawaited(handleLink(initial));
        links = const EventChannel(
          'com.iris.app/deep_link_events',
        ).receiveBroadcastStream().listen((value) {
          if (value is String) handleLink(value);
        }, onError: (_) {});
      } on MissingPluginException {
        /* Not available in widget tests. */
      } on PlatformException {
        /* Native channel unavailable; manual entry remains available. */
      }
      unawaited(checkThresholds());
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) refresh();
  }

  Future<void> refresh() async {
    final session = ref.read(sessionProvider);
    await session.refreshVisible();
    if (mounted) setState(() => refreshRevision++);
    await checkThresholds();
  }

  Future<void> checkThresholds() async {
    final s = ref.read(sessionProvider);
    if (s.budget == null) return;
    try {
      final r = await s.command('thresholds', 'EvaluateBudgetThresholds', {
        'asOfDate': dateText(DateTime.now()),
        'timeZone': s.timeZone,
      });
      for (final decision in r['value'] as List) {
        final id = decision['notificationId'] as String;
        if (decision['shouldNotify'] == true && delivered.add(id)) {
          await notifications.show(
            id.hashCode & 0x7fffffff,
            '予算の${decision['threshold']}%に到達しました',
            '予算期間の支出を確認してください',
          );
        }
      }
    } on ApiFailure {
      /* No success notification on an unconfirmed command. */
    }
  }

  Future<void> handleLink(String value) async {
    final uri = Uri.tryParse(value);
    if (uri == null || uri.scheme != 'iris' || uri.host != 'add-expense') {
      return;
    }
    final s = ref.read(sessionProvider);
    final input = <String, dynamic>{};
    const names = {
      'amount': 'amount',
      'merchant': 'merchant',
      'merchant_name': 'merchant',
      'spent_at': 'spent_at',
      'date': 'spent_at',
      'source': 'source',
      'external_tx_id': 'external_tx_id',
      'currency': 'currency',
      'requestId': 'requestId',
    };
    for (final e in uri.queryParameters.entries) {
      if (names.containsKey(e.key)) input[names[e.key]!] = e.value;
    }
    final pending = PendingCommand.payment(input);
    Future<void> submit() async {
      try {
        final r = await s.api.submit(pending);
        await refresh();
        if (!mounted) return;
        if (r['status'] == 'created' &&
            delivered.add('payment:${r['expense_id']}')) {
          final shown = await notifications.show(
            (r['expense_id'] as String).hashCode & 0x7fffffff,
            '支出を記録しました',
            'タップして内容を確認',
            payload: r['expense_id'] as String,
          );
          if (!shown && mounted) message(context, '支出を記録しました');
        } else {
          message(context, '登録済みの決済です');
        }
      } on ApiFailure catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(e.toString()),
              action:
                  e.unknownOutcome
                      ? SnackBarAction(label: '同じ要求で再試行', onPressed: submit)
                      : null,
            ),
          );
        }
      }
    }

    await submit();
  }

  Future<void> add() async {
    await openExpense(context, ref.read(sessionProvider), date: date);
    await refresh();
  }

  void moveDay(int delta) {
    if (FocusManager.instance.primaryFocus?.context
            ?.findAncestorWidgetOfExactType<EditableText>() !=
        null) {
      return;
    }
    setState(() => date = DateTime(date.year, date.month, date.day + delta));
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<int>(sessionProvider.select((s) => s.mutationRevision), (
      _,
      next,
    ) {
      unawaited(checkThresholds());
    });
    final session = ref.watch(sessionProvider),
        width = MediaQuery.sizeOf(context).width;
    const labels = ['今日', '履歴', '予算', 'カテゴリ'];
    const icons = [
      Icons.today,
      Icons.history,
      Icons.savings_outlined,
      Icons.category_outlined,
    ];
    void select(int i) {
      FocusManager.instance.primaryFocus?.unfocus();
      setState(() => tab = i);
    }

    final body =
        !session.ready
            ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (session.startupError == null)
                      const CircularProgressIndicator()
                    else ...[
                      Text(session.startupError!),
                      const SizedBox(height: 16),
                      FilledButton(
                        onPressed: session.start,
                        child: const Text('再試行'),
                      ),
                    ],
                  ],
                ),
              ),
            )
            : IndexedStack(
              index: tab,
              children: [
                DailyScreen(
                  session: session,
                  date: date,
                  onDate: (d) => setState(() => date = d),
                  onBudget: () => select(2),
                ),
                HistoryScreen(
                  refreshRevision: refreshRevision,
                  session: session,
                ),
                BudgetScreen(
                  key: const ValueKey('budget'),
                  session: session,
                  onSaved: () {
                    select(0);
                    refresh();
                  },
                ),
                CategoryScreen(session: session),
              ],
            );
    final content = KeyedSubtree(key: contentKey, child: body);
    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.keyN, meta: true): add,
        const SingleActivator(LogicalKeyboardKey.arrowLeft, meta: true):
            () => moveDay(-1),
        const SingleActivator(LogicalKeyboardKey.arrowRight, meta: true):
            () => moveDay(1),
      },
      child: GestureDetector(
        onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
        child: Scaffold(
          appBar: AppBar(
            title: Text(labels[tab]),
            leading:
                tab == 2
                    ? IconButton(
                      tooltip: '今日へ戻る',
                      onPressed: () => select(0),
                      icon: const Icon(Icons.arrow_back),
                    )
                    : null,
            actions: [
              IconButton(
                tooltip: '決済連携設定',
                onPressed:
                    () => Navigator.push(
                      context,
                      MaterialPageRoute<void>(
                        builder: (_) => PaymentGuide(session: session),
                      ),
                    ),
                icon: const Icon(Icons.link),
              ),
              IconButton(
                tooltip: 'クラウド接続設定',
                onPressed:
                    () => Navigator.push(
                      context,
                      MaterialPageRoute<void>(
                        builder: (_) => ConnectionScreen(session: session),
                      ),
                    ),
                icon: const Icon(Icons.cloud_outlined),
              ),
              IconButton(
                tooltip: '更新',
                onPressed: refresh,
                icon: const Icon(Icons.refresh),
              ),
            ],
          ),
          body: SafeArea(
            child:
                width >= 600
                    ? Row(
                      children: [
                        NavigationRail(
                          extended: width >= 840,
                          selectedIndex: tab,
                          onDestinationSelected: select,
                          destinations: List.generate(
                            4,
                            (i) => NavigationRailDestination(
                              icon: Icon(icons[i]),
                              label: Text(labels[i]),
                            ),
                          ),
                        ),
                        const VerticalDivider(width: 1),
                        Expanded(child: content),
                      ],
                    )
                    : content,
          ),
          bottomNavigationBar:
              width < 600
                  ? NavigationBar(
                    selectedIndex: tab,
                    onDestinationSelected: select,
                    destinations: List.generate(
                      4,
                      (i) => NavigationDestination(
                        icon: Icon(icons[i]),
                        label: labels[i],
                      ),
                    ),
                  )
                  : null,
          floatingActionButton:
              session.ready && tab < 2
                  ? FloatingActionButton(
                    tooltip: '支出を追加',
                    onPressed: add,
                    child: const Icon(Icons.add),
                  )
                  : null,
        ),
      ),
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    links?.cancel();
    super.dispose();
  }
}

class PaymentGuide extends StatefulWidget {
  final CloudSession session;
  const PaymentGuide({required this.session, super.key});
  @override
  State<PaymentGuide> createState() => _PaymentGuideState();
}

class _PaymentGuideState extends State<PaymentGuide> {
  String? result;
  bool busy = false;
  PendingCommand? pending;
  Future<void> test() async {
    setState(() => busy = true);
    pending ??= PendingCommand.payment({'amount': 1, 'merchant': '連携テスト（1円）'});
    try {
      final r = await widget.session.api.submit(pending!);
      pending = null;
      await widget.session.refreshVisible();
      if (mounted) {
        setState(
          () =>
              result =
                  r['status'] == 'created'
                      ? '1円のテスト支出を記録しました。不要なら履歴から削除してください。'
                      : '登録済みです',
        );
      }
    } on ApiFailure catch (e) {
      if (!e.unknownOutcome) pending = null;
      if (mounted) setState(() => result = e.toString());
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('決済連携設定')),
    body: ListView(
      padding: const EdgeInsets.all(20),
      children: [
        const Text('Apple Payショートカット', style: TextStyle(fontSize: 22)),
        const SizedBox(height: 16),
        const Text(
          'ショートカットの決済オートメーションで「URLの内容を取得」を追加し、以下へPOSTします。ロック中の記録にはこのAPI経路を使います。',
        ),
        SelectableText('${widget.session.endpoint}/payment'),
        const SelectableText(
          'JSON本文：requestId（毎回新しいUUID）、user_id、amount、merchant、spent_at（任意）、source: apple_pay、external_tx_id（任意）',
        ),
        const Text(
          '通信エラー時は同じrequestIdと入力で再試行します。背景経路の完了・失敗通知はショートカット側で表示します。アプリURLは iris://add-expense?amount=1280&merchant=店舗名 です。',
        ),
        TextButton(
          onPressed:
              busy
                  ? null
                  : () async {
                    final ok = await widget.session.api.health();
                    if (mounted) setState(() => result = ok ? '接続成功' : '接続失敗');
                  },
          child: const Text('接続テスト'),
        ),
        FilledButton(
          onPressed:
              busy
                  ? null
                  : () async {
                    if (pending != null ||
                        await confirm(context, '1円の支出を実際に登録して接続を確認しますか？')) {
                      test();
                    }
                  },
          child: Text(pending == null ? '1円のテスト送信' : '同じ要求で再試行'),
        ),
        if (result != null) Text(result!),
        if (busy) const LinearProgressIndicator(),
      ],
    ),
  );
}
