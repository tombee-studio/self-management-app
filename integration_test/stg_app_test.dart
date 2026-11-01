import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:http/http.dart' as http;
import 'package:iris_app/cloud/api.dart';
import 'package:iris_app/cloud/session.dart';
import 'package:iris_app/core/config/app_config.dart';
import 'package:iris_app/main.dart';
import 'package:iris_app/core/services/notification_service.dart';

class ControlledTransport extends http.BaseClient {
  final http.Client delegate = http.Client();
  bool offline = false;
  bool loseNextCommandResponse = false;
  final sent = <String>[];
  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    if (offline) throw http.ClientException('stg test: transport disconnected');
    if (request.url.path == '/commands' && request is http.Request) {
      sent.add(request.body);
    }
    final response = await delegate.send(request);
    if (loseNextCommandResponse && request.url.path == '/commands') {
      loseNextCommandResponse = false;
      await response.stream.drain<void>();
      throw http.ClientException(
        'stg test: committed response deliberately dropped',
      );
    }
    return response;
  }

  @override
  void close() {
    delegate.close();
    super.close();
  }
}

class ObservedNativeNotifications extends LocalNotificationGateway {
  final deliveredPayloads=<String>[];
  @override Future<bool> show(int id,String title,String body,{String? payload}) async {
    final shown=await super.show(id,title,body,payload:payload);
    if(shown && payload!=null) deliveredPayloads.add(payload);
    return shown;
  }
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  const run = String.fromEnvironment('IRIS_STG_RUN', defaultValue: 'manual');
  const nativeNotificationTest=bool.fromEnvironment('IRIS_STG_NATIVE_NOTIFICATION');
  final nativeNotifications=ObservedNativeNotifications();
  testWidgets(
    'iOS Simulator -> stg: CRUD, Undo, budget, category, replay, native URL',
    (tester) async {
      expect(AppConfig.defaultCloudSyncEndpoint, isNot(contains('tidcbcu3f9')));
      final transport = ControlledTransport();
      final port = HttpRemotePort(client: transport);
      final timeZone = await const MethodChannel(
        'com.iris.app/device',
      ).invokeMethod<String>('timeZone');
      expect(timeZone, isNotEmpty);
      final session = CloudSession(
        api: port,
        loadSettings: false,
        timeZone: timeZone!,
      );
      Future<void> until(
        bool Function() condition, {
        String reason = 'condition',
        int seconds = 60,
      }) async {
        final limit = DateTime.now().add(Duration(seconds: seconds));
        while (!condition() && DateTime.now().isBefore(limit)) {
          await tester.pump(const Duration(milliseconds: 200));
        }
        expect(condition(), isTrue, reason: reason);
      }

      Future<void> visibleTap(Finder finder) async {
        await tester.ensureVisible(finder);
        await tester.pump(const Duration(milliseconds: 350));
        await tester.tap(finder);
        await tester.pump(const Duration(milliseconds: 200));
      }

      Finder field(String label) => find.byWidgetPredicate(
        (w) => w is TextField && w.decoration?.labelText == label,
      );
      Future<void> save() async {
        FocusManager.instance.primaryFocus?.unfocus();
        await tester.pump(const Duration(milliseconds: 300));
        await visibleTap(find.widgetWithText(FilledButton, '保存'));
      }

      Future<Json> item(String memo) async {
        final day =
            (await port.query('WatchDailySummary', {
                  'date': dateText(DateTime.now()),
                  'timeZone': timeZone,
                }))['value']
                as Json;
        return (day['items'] as List).cast<Json>().singleWhere(
          (e) => e['memo'] == memo,
        );
      }

      await tester.pumpWidget(
        ProviderScope(
          overrides: [sessionProvider.overrideWith((ref) => session),if(nativeNotificationTest)notificationGatewayProvider.overrideWithValue(nativeNotifications)],
          child: const IrisExpenseApp(),
        ),
      );
      await until(
        () =>
            session.ready &&
            session.slot('daily:${dateText(DateTime.now())}').value != null,
        reason: 'stg application startup',
      );
      debugPrint('STG_UI_STARTUP_PASS zone=$timeZone');

      final memo = 'iOS stg $run';
      await visibleTap(find.byTooltip('支出を追加'));
      await until(() => field('金額・計算式').evaluate().isNotEmpty);
      await tester.enterText(field('金額・計算式'), '1280');
      await tester.enterText(field('メモ（100文字以内）'), memo);
      await save();
      await until(
        () => find.text('支出を保存しました').evaluate().isNotEmpty,
        reason: 'record commit acknowledged',
      );
      await until(
        () => field('金額・計算式').evaluate().isEmpty,
        reason: 'record modal closed',
      );
      await tester.pump(const Duration(milliseconds: 500));
      final created = await item(memo);
      expect(created['amount'], 1280);
      debugPrint('STG_UI_CREATE_PASS id=${created['id']}');

      await visibleTap(
        find
            .ancestor(
              of: find.textContaining(memo),
              matching: find.byType(ListTile),
            )
            .first,
      );
      await until(() => field('金額・計算式').evaluate().isNotEmpty);
      await tester.enterText(field('金額・計算式'), '2345');
      await save();
      await until(
        () => field('金額・計算式').evaluate().isEmpty,
        reason: 'edit form closed after server commit',
      );
      final edited = await item(memo);
      expect(edited['id'], created['id']);
      expect(edited['amount'], 2345);
      expect(edited['version'], 2);
      debugPrint('STG_UI_EDIT_PASS');

      await visibleTap(
        find
            .ancestor(
              of: find.textContaining(memo),
              matching: find.byType(ListTile),
            )
            .first,
      );
      await until(() => field('金額・計算式').evaluate().isNotEmpty);
      await visibleTap(find.widgetWithText(TextButton, '削除'));
      await until(() => find.text('この支出を削除しますか？').evaluate().isNotEmpty);
      await visibleTap(find.text('キャンセル'));
      expect(
        (await port.query('GetExpense', {
          'id': created['id'],
        }))['value']['amount'],
        2345,
      );
      await visibleTap(find.byTooltip('閉じる'));
      await until(() => field('金額・計算式').evaluate().isEmpty);
      await tester.ensureVisible(
        find
            .ancestor(
              of: find.textContaining(memo),
              matching: find.byType(ListTile),
            )
            .first,
      );
      await tester.pump(const Duration(milliseconds:500));
      await tester.ensureVisible(find.ancestor(of:find.textContaining(memo),matching:find.byType(ListTile)).first);
      await tester.pump(const Duration(milliseconds:350));
      await tester.drag(
        find
            .ancestor(
              of: find.textContaining(memo),
              matching: find.byType(ListTile),
            )
            .first,
        const Offset(-350, 0),
      );
      await until(
        () => find.text('元に戻す').evaluate().isNotEmpty,
        reason: 'swipe commit and Undo',
      );
      await visibleTap(find.widgetWithText(TextButton, '元に戻す'));
      final restoreLimit = DateTime.now().add(const Duration(seconds: 30));
      Json? confirmedRestore;
      while (DateTime.now().isBefore(restoreLimit)) {
        try {
          final response = await port.query('GetExpense', {
            'id': created['id'],
          });
          final value = response['value'] as Json;
          if (value['version'] == 4) {
            confirmedRestore = value;
            break;
          }
        } on ApiFailure catch (e) {
          if (e.code != 'NotFound') rethrow;
        }
        await tester.pump(const Duration(milliseconds: 200));
      }
      expect(
        confirmedRestore,
        isNotNull,
        reason: 'restore command committed to stg',
      );
      await until(
        () =>
            find
                .ancestor(
                  of: find.textContaining(memo),
                  matching: find.byType(ListTile),
                )
                .first
                .evaluate()
                .isNotEmpty &&
            !session.slot('daily:${dateText(DateTime.now())}').loading,
        reason: 'restored display',
      );
      final restored = await item(memo);
      expect(restored['id'], created['id']);
      expect(restored['version'], 4);
      debugPrint('STG_UI_DELETE_CANCEL_UNDO_PASS');

      await visibleTap(find.byIcon(Icons.savings_outlined));
      await until(() => field('月間総予算').evaluate().isNotEmpty);
      await tester.enterText(field('月間総予算'), '75000');
      await save();
      await until(() => find.text('予算設定を保存しました').evaluate().isNotEmpty);
      expect(
        (await port.query('GetBudgetPlan', {}))['value']['monthlyAmount'],
        75000,
      );
      debugPrint('STG_UI_BUDGET_PASS');

      await visibleTap(find.byIcon(Icons.category_outlined));
      await visibleTap(find.text('カテゴリを追加'));
      await until(() => field('カテゴリ名（20文字以内）').evaluate().isNotEmpty);
      final categoryName = 'stg-ui-$run';
      await tester.enterText(field('カテゴリ名（20文字以内）'), categoryName);
      await save();
      await until(
        () => field('カテゴリ名（20文字以内）').evaluate().isEmpty,
        reason: 'category editor closed after commit',
      );
      await tester.scrollUntilVisible(
        find.text(categoryName),
        200,
        scrollable:
            find
                .descendant(
                  of: find.byType(ReorderableListView),
                  matching: find.byType(Scrollable),
                )
                .first,
      );
      expect(find.text(categoryName).hitTestable(), findsOneWidget);
      final catalog = (await port.query('GetCatalog', {}))['value'] as Json;
      expect(
        (catalog['categories'] as List)
            .where((c) => c['name'] == categoryName)
            .length,
        1,
      );
      debugPrint('STG_UI_CATEGORY_PASS');

      await visibleTap(find.byIcon(Icons.today));
      await visibleTap(find.byTooltip('支出を追加'));
      await until(() => field('金額・計算式').evaluate().isNotEmpty);
      await tester.enterText(field('金額・計算式'), '3456');
      final retryMemo = 'iOS retry $run';
      await tester.enterText(field('メモ（100文字以内）'), retryMemo);
      transport.loseNextCommandResponse = true;
      await save();
      await until(
        () => find.text('同じ要求で再試行').evaluate().isNotEmpty,
        reason: 'unknown outcome retains input',
      );
      expect(find.text('3456'), findsOneWidget);
      final originalCommand = transport.sent.last;
      await visibleTap(find.widgetWithText(FilledButton, '同じ要求で再試行'));
      await until(() => field('金額・計算式').evaluate().isEmpty);
      expect(transport.sent, contains(originalCommand));
      expect(transport.sent.where((body) => body == originalCommand).length, 2);
      expect((await item(retryMemo))['amount'], 3456);
      debugPrint('STG_UI_UNKNOWN_OUTCOME_REPLAY_PASS');

      final previous = session.slot('daily:${dateText(DateTime.now())}').value;
      transport.offline = true;
      await session.daily(dateText(DateTime.now()));
      await tester.pump();
      expect(
        session.slot('daily:${dateText(DateTime.now())}').value,
        same(previous),
      );
      tester
          .state<ScrollableState>(find.byType(Scrollable).first)
          .position
          .jumpTo(0);
      await tester.pump(const Duration(milliseconds: 300));
      await until(
        () => find.textContaining('未更新：').evaluate().isNotEmpty,
        reason: 'stale banner visible at top',
      );
      transport.offline = false;
      await session.daily(dateText(DateTime.now()));
      await tester.pump();
      expect(session.slot('daily:${dateText(DateTime.now())}').error, isNull);
      debugPrint('STG_UI_STALE_DISPLAY_RETRY_PASS');

      await visibleTap(find.byIcon(Icons.history));
      await until(() => field('メモを検索').evaluate().isNotEmpty);
      await tester.enterText(field('メモを検索'), memo);
      FocusManager.instance.primaryFocus?.unfocus();
      await until(
        () => find.textContaining('検索結果 1件').evaluate().isNotEmpty,
        reason: 'server-backed history search',
      );
      await visibleTap(find.widgetWithText(FilterChip, 'カレンダー'));
      final dayButton = find.byWidgetPredicate(
        (w) =>
            w is Text &&
            (w.data?.startsWith('${DateTime.now().day}\n') ?? false),
      );
      await visibleTap(dayButton);
      await tester.pump(const Duration(seconds: 1));
      expect(tester.widget<Text>(dayButton).style?.fontWeight, FontWeight.bold);
      debugPrint('STG_UI_HISTORY_SEARCH_CALENDAR_PASS');
      await visibleTap(find.byIcon(Icons.today));

      final nativeMemo = 'Native Link STG $run';
      if(nativeNotificationTest) {
        debugPrint('IRIS_READY_FOR_NATIVE_LINK');
        await until(()=>nativeNotifications.deliveredPayloads.isNotEmpty && field('金額・計算式').evaluate().isNotEmpty,reason:'native permission, notification delivery and tap-to-edit',seconds:180);
        expect(tester.widget<TextField>(field('金額・計算式')).controller?.text,'567');
        await visibleTap(find.byTooltip('閉じる'));
        debugPrint('STG_NATIVE_PERMISSION_NOTIFICATION_TAP_PASS');
      } else {
        await port.submit(PendingCommand.payment({'amount':567,'merchant':nativeMemo,'external_tx_id':'native-$run'}));
        debugPrint('IRIS_READY_FOR_NATIVE_LINK');
        await until(()=>find.text('登録済みの決済です').evaluate().isNotEmpty,reason:'native URL event -> real stg duplicate response',seconds:180);
      }
      final nativeExpense = await item(nativeMemo);
      expect(nativeExpense['amount'], 567);
      expect(nativeExpense['source'], 'apple_pay');
      debugPrint('STG_NATIVE_URL_PASS id=${nativeExpense['id']}');
      debugPrint('IRIS_CAPTURE_STG_SCREENSHOT');
      await tester.pump(const Duration(seconds: 3));
      expect(tester.takeException(), isNull);
      debugPrint('STG_IOS_ALL_PASS');
    },
    timeout: const Timeout(Duration(minutes: 12)),
  );
}
