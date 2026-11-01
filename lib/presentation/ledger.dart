import 'dart:async';
import 'package:flutter/material.dart';
import '../cloud/api.dart';
import '../cloud/session.dart';
import 'common.dart';
import 'expense_form.dart';

class ExpenseList extends StatefulWidget {
  final CloudSession session;
  final List<Json> items;
  final VoidCallback refresh;
  final ValueChanged<Json> edit;
  const ExpenseList({
    required this.session,
    required this.items,
    required this.refresh,
    required this.edit,
    super.key,
  });
  @override
  State<ExpenseList> createState() => _ExpenseListState();
}

class _ExpenseListState extends State<ExpenseList> {
  final pending = <String, PendingCommand>{};
  final busy = <String>{};
  Future<bool> remove(Json e) async {
    final id = e['id'] as String;
    if (busy.contains(id)) return false;
    busy.add(id);
    final p = pending.putIfAbsent(
      id,
      () => PendingCommand.create('DeleteExpense', {
        'id': id,
        'expectedVersion': e['version'],
        'kind': 'swipe',
      }),
    );
    try {
      final result = await widget.session.api.submit(p);
      pending.remove(id);
      if (!mounted) return false;
      final grant = (result['value'] as Json)['undoGrant'] as String?;
      if (grant != null) {
        final expiry = DateTime.now().add(const Duration(seconds: 5));
        final restore = PendingCommand.create('RestoreExpense', {
          'grant': grant,
        });
        final messenger = ScaffoldMessenger.of(context);
        messenger.clearSnackBars();
        messenger.removeCurrentSnackBar();
        final undoNotice = messenger.showSnackBar(
          SnackBar(
            duration: const Duration(seconds: 5),
            content: const Text('支出を削除しました'),
            action: SnackBarAction(
              label: '元に戻す',
              onPressed: () async {
                if (!DateTime.now().isBefore(expiry)) return;
                Future<void> undo() async {
                  try {
                    await widget.session.api.submit(restore);
                    await widget.session.refreshVisible();
                    widget.refresh();
                  } on ApiFailure catch (err) {
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(err.toString()),
                          action:
                              err.unknownOutcome
                                  ? SnackBarAction(
                                    label: '再試行',
                                    onPressed: undo,
                                  )
                                  : null,
                        ),
                      );
                    }
                  }
                }

                await undo();
              },
            ),
          ),
        );
        final timeout = Timer(const Duration(seconds: 5), () {
          if (mounted) undoNotice.close();
        });
        unawaited(undoNotice.closed.then((_) => timeout.cancel()));
      }
      await widget.session.refreshVisible();
      widget.refresh();
      return false; // API refresh removes the row after commit; no optimistic dismissal.
    } on ApiFailure catch (err) {
      if (!err.unknownOutcome) pending.remove(id);
      if (mounted) message(context, err);
      return false;
    } finally {
      busy.remove(id);
    }
  }

  @override
  Widget build(BuildContext context) => Column(
    children:
        widget.items.map((e) {
          final c =
              widget.session.categories
                  .where((c) => c['id'] == e['categoryId'])
                  .firstOrNull;
          return Dismissible(
            key: ValueKey(e['id']),
            direction: DismissDirection.endToStart,
            confirmDismiss: (_) => remove(e),
            background: Container(
              color: Colors.red,
              alignment: Alignment.centerRight,
              padding: const EdgeInsets.all(16),
              child: const Icon(Icons.delete, color: Colors.white),
            ),
            child: ListTile(
              leading: CircleAvatar(
                backgroundColor:
                    c == null ? null : categoryColor(c).withValues(alpha: .15),
                child: Icon(iconMap[c?['iconKey']] ?? Icons.folder),
              ),
              title: Text(yen(e['amount'])),
              subtitle: Text(
                '${c?['name'] ?? '未分類'} · ${e['memo'] ?? ''}\n${DateTime.parse(e['spentAt'] as String).toLocal().toString().substring(0, 16)} · ${e['source'] == 'apple_pay' ? 'Apple Pay連携' : '手動'}',
              ),
              trailing:
                  pending.containsKey(e['id'])
                      ? IconButton(
                        tooltip: '同じ削除要求で再試行',
                        onPressed: () => remove(e),
                        icon: const Icon(Icons.refresh),
                      )
                      : null,
              onTap: () => widget.edit(e),
            ),
          );
        }).toList(),
  );
}

class DailyScreen extends StatefulWidget {
  final CloudSession session;
  final DateTime date;
  final ValueChanged<DateTime> onDate;
  final VoidCallback onBudget;
  const DailyScreen({
    required this.session,
    required this.date,
    required this.onDate,
    required this.onBudget,
    super.key,
  });
  @override
  State<DailyScreen> createState() => _DailyScreenState();
}

class _DailyScreenState extends State<DailyScreen> {
  Json? editing;
  var editorKey = GlobalKey<ExpenseFormState>();
  @override
  void initState() {
    super.initState();
    scheduleMicrotask(refresh);
  }

  @override
  void didUpdateWidget(covariant DailyScreen old) {
    super.didUpdateWidget(old);
    if (dateText(old.date) != dateText(widget.date)) scheduleMicrotask(refresh);
  }

  Future<void> refresh() => widget.session.daily(dateText(widget.date));
  void edit(Json e) async {
    if (editing?['id'] == e['id']) return;
    if (editing != null &&
        !(await editorKey.currentState?.canDiscard() ?? true)) {
      return;
    }
    if (!mounted) return;
    if (MediaQuery.sizeOf(context).width >= 840) {
      setState(() {
        editing = e;
        editorKey = GlobalKey<ExpenseFormState>();
      });
    } else {
      openExpense(context, widget.session, expense: e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.session.slot('daily:${dateText(widget.date)}'),
        data = p.value as Json?;
    final hint = data?['budgetHint'] as Json?;
    final summary = Section('日次支出', [
      Wrap(
        alignment: WrapAlignment.center,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          IconButton(
            tooltip: '前日',
            onPressed:
                () => widget.onDate(
                  DateTime(
                    widget.date.year,
                    widget.date.month,
                    widget.date.day - 1,
                  ),
                ),
            icon: const Icon(Icons.chevron_left),
          ),
          TextButton(
            onPressed: () async {
              final d = await showDatePicker(
                context: context,
                initialDate: widget.date,
                firstDate: DateTime(1970),
                lastDate: DateTime(9999),
              );
              if (d != null) widget.onDate(d);
            },
            child: Text(dateText(widget.date)),
          ),
          IconButton(
            tooltip: '翌日',
            onPressed:
                () => widget.onDate(
                  DateTime(
                    widget.date.year,
                    widget.date.month,
                    widget.date.day + 1,
                  ),
                ),
            icon: const Icon(Icons.chevron_right),
          ),
          TextButton(
            onPressed: () => widget.onDate(DateTime.now()),
            child: const Text('今日'),
          ),
        ],
      ),
      Text(
        data == null ? '—' : yen(data['total']),
        style: Theme.of(context).textTheme.headlineLarge,
      ),
      const SizedBox(height: 16),
      TextButton(onPressed: widget.onBudget, child: const Text('予算設定')),
      if (hint != null) ...[
        Text('予算期間の実績 ${yen(hint['totalSpent'])}'),
        Text('残予算 ${yen(hint['remainingBudget'])}'),
        Text('日次目安 ${yen(hint['dailyRecommended'])}'),
        Text('予測総額 ${yen(hint['projectedTotalExpense'])}'),
        if (hint['isProjectedToOverspend'] == true)
          const Text(
            'このペースでは予算を超過する見込みです',
            style: TextStyle(color: Colors.red),
          ),
      ],
    ]);
    final breakdown = Section('カテゴリ内訳', [
      for (final b in (data?['categoryBreakdown'] as List? ?? []))
        Builder(
          builder: (context) {
            final c =
                widget.session.categories
                    .where((c) => c['id'] == b['categoryId'])
                    .firstOrNull;
            final total = data?['total'] as int? ?? 0;
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text('${c?['name'] ?? '未分類'}  ${yen(b['amount'])}'),
                  LinearProgressIndicator(
                    value: total == 0 ? 0 : (b['amount'] as int) / total,
                    color: c == null ? null : categoryColor(c),
                  ),
                ],
              ),
            );
          },
        ),
      if (data != null && (data['items'] as List).isEmpty)
        const Text('この日の支出はありません。＋から追加できます。'),
    ]);
    final list = Section('明細', [
      ExpenseList(
        session: widget.session,
        items: (data?['items'] as List? ?? []).cast<Json>(),
        refresh: refresh,
        edit: edit,
      ),
    ]);
    final width = MediaQuery.sizeOf(context).width;
    return RefreshIndicator(
      onRefresh: refresh,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          LoadNotice(p, refresh),
          if (width >= 840)
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: (width * .4).clamp(0, 380),
                  child: Column(
                    children: [summary, const SizedBox(height: 16), breakdown],
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    children: [
                      list,
                      if (editing != null)
                        ExpenseForm(
                          key: editorKey,
                          session: widget.session,
                          expense: editing,
                          onClose: () => setState(() => editing = null),
                        ),
                    ],
                  ),
                ),
              ],
            )
          else ...[
            if (width >= 600)
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: summary),
                  const SizedBox(width: 16),
                  Expanded(child: breakdown),
                ],
              )
            else ...[
              summary,
              const SizedBox(height: 16),
              breakdown,
            ],
            const SizedBox(height: 16),
            list,
            if (editing != null)
              ExpenseForm(
                key: editorKey,
                session: widget.session,
                expense: editing,
                onClose: () => setState(() => editing = null),
              ),
          ],
        ],
      ),
    );
  }
}

class HistoryScreen extends StatefulWidget {
  final CloudSession session;
  final int refreshRevision;
  const HistoryScreen({
    required this.session,
    this.refreshRevision = 0,
    super.key,
  });
  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  DateTime month = DateTime.now();
  String? source, selectedDay;
  bool all = false, calendar = false, loading = false;
  final keyword = TextEditingController();
  final categoryIds = <String>{};
  List<Json> items = [];
  Json? totals, calendarTotals;
  String? cursor;
  ApiFailure? error;
  int revision = 0;
  Timer? debounce;
  Json get filter => {
    'month': all ? null : monthText(month),
    'keyword': keyword.text,
    'categoryIds': categoryIds.toList()..sort(),
    'source': source,
    'timeZone': widget.session.timeZone,
    'date': selectedDay,
  };
  @override
  void initState() {
    super.initState();
    scheduleMicrotask(refresh);
  }

  @override
  void didUpdateWidget(covariant HistoryScreen old) {
    super.didUpdateWidget(old);
    if (old.refreshRevision != widget.refreshRevision) {
      scheduleMicrotask(refresh);
    }
  }

  Future<void> refresh({bool more = false}) async {
    final generation = ++revision;
    final f = filter;
    setState(() => loading = true);
    try {
      final pageResponse = await widget.session.api.query('QueryHistory', {
        'filter': f,
        if (more) 'cursor': cursor,
      });
      final page = pageResponse['value'] as Json;
      final t =
          (await widget.session.api.query('GetHistoryTotals', {
                'filter': f,
                'snapshotId': page['snapshotId'],
              }))['value']
              as Json;
      Json calendarData = t;
      if (calendar && selectedDay != null) {
        final monthFilter = {...f, 'date': null};
        final monthPage = await widget.session.api.query('QueryHistory', {
          'filter': monthFilter,
        });
        if (monthPage['readGeneration'] != pageResponse['readGeneration']) {
          throw const ApiFailure('CursorInvalidated');
        }
        calendarData =
            (await widget.session.api.query('GetHistoryTotals', {
                  'filter': monthFilter,
                  'snapshotId': monthPage['value']['snapshotId'],
                }))['value']
                as Json;
      }
      if (mounted && revision == generation) {
        setState(() {
          items =
              more
                  ? [...items, ...(page['items'] as List).cast<Json>()]
                  : (page['items'] as List).cast<Json>();
          totals = t;
          calendarTotals = calendarData;
          cursor = page['nextCursor'] as String?;
          error = null;
        });
      }
    } on ApiFailure catch (e) {
      if (mounted && revision == generation) setState(() => error = e);
    } finally {
      if (mounted && revision == generation) setState(() => loading = false);
    }
  }

  void changeMonth(int delta) {
    setState(() {
      month = DateTime(month.year, month.month + delta);
      selectedDay = null;
    });
    refresh();
  }

  @override
  Widget build(BuildContext context) {
    final days = DateTime(month.year, month.month + 1, 0).day;
    return RefreshIndicator(
      onRefresh: refresh,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              IconButton(
                onPressed: all ? null : () => changeMonth(-1),
                icon: const Icon(Icons.chevron_left),
              ),
              Text(all ? '全期間' : monthText(month)),
              IconButton(
                onPressed: all ? null : () => changeMonth(1),
                icon: const Icon(Icons.chevron_right),
              ),
              FilterChip(
                label: const Text('全期間'),
                selected: all,
                onSelected: (v) {
                  setState(() {
                    all = v;
                    selectedDay = null;
                    if (v) calendar = false;
                  });
                  refresh();
                },
              ),
              FilterChip(
                label: const Text('カレンダー'),
                selected: calendar,
                onSelected:
                    all
                        ? null
                        : (v) {
                          setState(() {
                            calendar = v;
                            selectedDay = null;
                          });
                          refresh();
                        },
              ),
            ],
          ),
          TextField(
            controller: keyword,
            decoration: const InputDecoration(
              labelText: 'メモを検索',
              prefixIcon: Icon(Icons.search),
            ),
            onChanged: (_) {
              debounce?.cancel();
              revision++;
              debounce = Timer(
                const Duration(milliseconds: 200),
                () => refresh(),
              );
            },
          ),
          Wrap(
            spacing: 6,
            children: [
              for (final c in widget.session.categories)
                FilterChip(
                  label: Text(c['name'] as String),
                  selected: categoryIds.contains(c['id']),
                  onSelected: (v) {
                    setState(() {
                      v
                          ? categoryIds.add(c['id'] as String)
                          : categoryIds.remove(c['id']);
                    });
                    refresh();
                  },
                ),
            ],
          ),
          DropdownButton<String?>(
            value: source,
            isExpanded: true,
            items: const [
              DropdownMenuItem(value: null, child: Text('すべての記録元')),
              DropdownMenuItem(value: 'manual', child: Text('手動')),
              DropdownMenuItem(value: 'apple_pay', child: Text('Apple Pay連携')),
            ],
            onChanged: (v) {
              setState(() => source = v);
              refresh();
            },
          ),
          if (loading) const LinearProgressIndicator(),
          if (error != null)
            MaterialBanner(
              content: Text('未更新：$error'),
              actions: [
                TextButton(
                  onPressed: () => refresh(),
                  child: const Text('先頭から再試行'),
                ),
              ],
            ),
          if (totals != null)
            Section('集計', [
              if (totals!['monthTotal'] != null)
                Text('月間合計 ${yen(totals!['monthTotal'])}'),
              Text('検索結果 ${totals!['count']}件  ${yen(totals!['total'])}'),
            ]),
          if (calendar)
            Wrap(
              children: [
                for (var day = 1; day <= days; day++)
                  Builder(
                    builder: (context) {
                      final d = dateText(
                        DateTime(month.year, month.month, day),
                      );
                      final sum =
                          (calendarTotals?['dayTotals'] as List? ?? [])
                              .where((x) => x['date'] == d)
                              .firstOrNull?['total'];
                      return SizedBox(
                        width: 95,
                        child: TextButton(
                          onPressed: () {
                            setState(
                              () => selectedDay = selectedDay == d ? null : d,
                            );
                            refresh();
                          },
                          child: Text(
                            '$day\n${yen(sum)}',
                            style: TextStyle(
                              fontWeight:
                                  selectedDay == d
                                      ? FontWeight.bold
                                      : FontWeight.normal,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
              ],
            ),
          if (!loading && error == null && items.isEmpty) ...[
            const Text('条件に合う支出がありません。'),
            TextButton(
              onPressed: () {
                setState(() {
                  keyword.clear();
                  categoryIds.clear();
                  source = null;
                  selectedDay = null;
                });
                refresh();
              },
              child: const Text('条件をクリア'),
            ),
          ],
          for (final day
              in items
                  .map(
                    (e) => dateText(
                      DateTime.parse(e['spentAt'] as String).toLocal(),
                    ),
                  )
                  .toSet()) ...[
            Padding(
              padding: const EdgeInsets.only(top: 16),
              child: Text(
                '$day  ${yen((totals?['dayTotals'] as List? ?? []).where((d) => d['date'] == day).firstOrNull?['total'])}',
              ),
            ),
            ExpenseList(
              key: ValueKey(day),
              session: widget.session,
              items:
                  items
                      .where(
                        (e) =>
                            dateText(
                              DateTime.parse(e['spentAt'] as String).toLocal(),
                            ) ==
                            day,
                      )
                      .toList(),
              refresh: refresh,
              edit: (e) async {
                await openExpense(context, widget.session, expense: e);
                refresh();
              },
            ),
          ],
          if (cursor != null)
            TextButton(
              onPressed: loading ? null : () => refresh(more: true),
              child: const Text('さらに50件を表示'),
            ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    debounce?.cancel();
    keyword.dispose();
    super.dispose();
  }
}
