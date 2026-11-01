import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iris_app/cloud/api.dart';
import 'package:iris_app/cloud/session.dart';
import 'package:iris_app/main.dart';
import 'package:iris_app/presentation/expense_form.dart';
import 'package:iris_app/core/services/notification_service.dart';

class FakeNotifications extends LocalNotificationGateway {
  @override
  Future<bool> initialize() async => false;
  @override
  Future<bool> show(
    int id,
    String title,
    String body, {
    String? payload,
  }) async => false;
}

class FakeRemote implements RemotePort {
  final fixtures =
      (jsonDecode(File('test/fixtures/api-v3.json').readAsStringSync()) as List)
          .cast<Json>();
  bool offline = false;
  final List<Json> submitted = [];
  @override
  Future<bool> health() async => !offline;
  @override
  Future<Json> query(String op, Json input) async {
    if (offline) throw const ApiFailure('TransportFailure');
    final f = fixtures.firstWhere((x) => x['request']['operation'] == op);
    final r = Map<String, dynamic>.from(f['response'] as Json);
    if (op == 'WatchDailySummary') {
      r['value'] = {...r['value'] as Json, 'date': input['date']};
    }
    return r;
  }

  @override
  Future<Json> submit(PendingCommand p) async {
    if (offline) {
      throw const ApiFailure('TransportFailure', unknownOutcome: true);
    }
    final input = jsonDecode(p.body);
    submitted.add(input as Json);
    final f = fixtures.firstWhere(
      (x) => x['request']['operation'] == input['operation'],
    );
    return {...f['response'] as Json, 'requestId': p.requestId};
  }
}

class DelayedRefreshRemote extends FakeRemote {
  bool holdDaily = false;
  final release = Completer<void>();
  @override
  Future<Json> query(String operation, Json input) async {
    final result = await super.query(operation, input);
    if (holdDaily && operation == 'WatchDailySummary') await release.future;
    return result;
  }
}

void main() {
  for (final width in [320.0, 599.0, 600.0, 839.0, 840.0, 900.0]) {
    testWidgets('shared UI at width $width preserves selected day on resize', (
      tester,
    ) async {
      tester.view.physicalSize = Size(width, 1100);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final session = CloudSession(api: FakeRemote(), loadSettings: false);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            notificationGatewayProvider.overrideWithValue(FakeNotifications()),
            sessionProvider.overrideWith((ref) => session),
          ],
          child: const IrisExpenseApp(),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(
        find.byType(width < 600 ? NavigationBar : NavigationRail),
        findsOneWidget,
      );
      await tester.tap(find.byTooltip('翌日'));
      await tester.pumpAndSettle();
      final selected = dateText(DateTime.now().add(const Duration(days: 1)));
      expect(find.text(selected), findsOneWidget);
      tester.view.physicalSize = const Size(900, 1100);
      await tester.pumpAndSettle();
      expect(find.text(selected), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
    });
  }
  testWidgets('failed save retains form and retry sends same command', (
    tester,
  ) async {
    final remote = FakeRemote(),
        session = CloudSession(api: FakeRemote(), loadSettings: false);
    session.api = remote;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          notificationGatewayProvider.overrideWithValue(FakeNotifications()),
          sessionProvider.overrideWith((ref) => session),
        ],
        child: const IrisExpenseApp(),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('支出を追加'));
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextField, '金額・計算式'), '1280');
    remote.offline = true;
    await tester.ensureVisible(find.widgetWithText(FilledButton, '保存'));
    await tester.tap(find.widgetWithText(FilledButton, '保存'));
    await tester.pumpAndSettle();
    expect(find.text('同じ要求で再試行'), findsOneWidget);
    expect(find.text('1280'), findsOneWidget);
    remote.offline = false;
    await tester.tap(find.widgetWithText(FilledButton, '同じ要求で再試行'));
    await tester.pumpAndSettle();
    expect(find.text('支出を保存しました'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
  });
  testWidgets(
    'budget rejects zero, preserves failed input, and returns to today after commit',
    (tester) async {
      final remote = FakeRemote(),
          session = CloudSession(api: FakeRemote(), loadSettings: false);
      session.api = remote;
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            notificationGatewayProvider.overrideWithValue(FakeNotifications()),
            sessionProvider.overrideWith((ref) => session),
          ],
          child: const IrisExpenseApp(),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.savings_outlined));
      await tester.pumpAndSettle();
      final field = find.widgetWithText(TextField, '月間総予算');
      await tester.enterText(field, '0');
      await tester.tap(find.widgetWithText(FilledButton, '保存'));
      await tester.pumpAndSettle();
      expect(
        remote.submitted.where((x) => x['operation'] == 'ConfigureBudgetPlan'),
        isEmpty,
      );
      await tester.enterText(field, '200000');
      remote.offline = true;
      await tester.tap(find.widgetWithText(FilledButton, '保存'));
      await tester.pumpAndSettle();
      expect(find.text('200000'), findsOneWidget);
      expect(find.text('同じ要求で再試行'), findsOneWidget);
      remote.offline = false;
      await tester.tap(find.widgetWithText(FilledButton, '同じ要求で再試行'));
      await tester.pumpAndSettle();
      expect(find.text('予算設定を保存しました'), findsOneWidget);
      expect(
        remote.submitted.lastWhere(
          (x) => x['operation'] == 'ConfigureBudgetPlan',
        )['input']['monthlyAmount'],
        200000,
      );
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
    },
  );
  testWidgets(
    'modal resize preserves amount and dirty close requires discard confirmation',
    (tester) async {
      tester.view.physicalSize = const Size(320, 1100);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final session = CloudSession(api: FakeRemote(), loadSettings: false);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            notificationGatewayProvider.overrideWithValue(FakeNotifications()),
            sessionProvider.overrideWith((ref) => session),
          ],
          child: const IrisExpenseApp(),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('支出を追加'));
      await tester.pumpAndSettle();
      await tester.enterText(find.widgetWithText(TextField, '金額・計算式'), '456');
      tester.view.physicalSize = const Size(900, 1100);
      await tester.pumpAndSettle();
      expect(find.text('456'), findsOneWidget);
      await tester.tap(find.byTooltip('閉じる'));
      await tester.pumpAndSettle();
      expect(find.text('入力内容を破棄しますか？'), findsOneWidget);
      await tester.tap(find.text('キャンセル'));
      await tester.pumpAndSettle();
      expect(find.text('456'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
    },
  );
  testWidgets(
    'Undo starts at commit response and expires while projection refresh is pending',
    (tester) async {
      final remote = DelayedRefreshRemote();
      final session = CloudSession(api: remote, loadSettings: false);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            notificationGatewayProvider.overrideWithValue(FakeNotifications()),
            sessionProvider.overrideWith((ref) => session),
          ],
          child: const IrisExpenseApp(),
        ),
      );
      await tester.pumpAndSettle();
      final row = find.byType(Dismissible).first;
      await tester.ensureVisible(row);
      remote.holdDaily = true;
      await tester.drag(row, const Offset(-700, 0));
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.text('元に戻す'), findsOneWidget);
      expect(session.slot('daily:${dateText(DateTime.now())}').loading, isTrue);
      await tester.pump(const Duration(seconds: 5));
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.text('元に戻す'), findsNothing);
      remote.release.complete();
      await tester.pumpAndSettle();
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
    },
  );
  testWidgets('continuous entry clears amount and memo, keeps selections, and uses fresh IDs', (tester) async {
    final remote=FakeRemote();final session=CloudSession(api:remote,loadSettings:false);
    await tester.pumpWidget(ProviderScope(overrides:[notificationGatewayProvider.overrideWithValue(FakeNotifications()),sessionProvider.overrideWith((ref)=>session)],child:const IrisExpenseApp()));await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('支出を追加'));await tester.pumpAndSettle();
    await tester.tap(find.text('未分類').last);await tester.pumpAndSettle();await tester.tap(find.text('食費').last);await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('現金'));await tester.tap(find.text('現金'));await tester.pumpAndSettle();await tester.tap(find.text('カード').last);await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('続けて登録'));await tester.tap(find.text('続けて登録'));await tester.pumpAndSettle();
    final amount=find.widgetWithText(TextField,'金額・計算式'),memo=find.widgetWithText(TextField,'メモ（100文字以内）');
    await tester.enterText(amount,'1280');await tester.enterText(memo,'連続1件目');
    final save=find.widgetWithText(FilledButton,'保存');await tester.ensureVisible(save);await tester.pumpAndSettle();await tester.tap(save);await tester.pumpAndSettle();
    expect(tester.widget<TextField>(amount).controller!.text,isEmpty);expect(tester.widget<TextField>(memo).controller!.text,isEmpty);
    expect(find.descendant(of:find.byType(ExpenseForm),matching:find.text('食費')),findsOneWidget);expect(find.text('カード'),findsOneWidget);
    await tester.enterText(amount,'2000');await tester.ensureVisible(save);await tester.pumpAndSettle();await tester.tap(save);await tester.pumpAndSettle();
    final records=remote.submitted.where((r)=>r['operation']=='RecordExpense').toList();expect(records.length,2);
    expect(records[0]['requestId'],isNot(records[1]['requestId']));expect(records[0]['input']['id'],isNot(records[1]['input']['id']));
    for(final field in ['categoryId','paymentMethod','spentAt']){expect(records[0]['input'][field],records[1]['input'][field]);}
    expect(records[1]['input']['memo'],isNull);
    await tester.pumpWidget(const SizedBox());await tester.pumpAndSettle();
  });

}
