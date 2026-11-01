import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:uuid/uuid.dart';
import '../cloud/api.dart';
import '../cloud/session.dart';
import '../features/expenses/domain/services/calculator_parser.dart';
import 'common.dart';

Future<void> openExpense(
  BuildContext context,
  CloudSession session, {
  Json? expense,
  DateTime? date,
}) async {
  final form = ExpenseForm(
    session: session,
    expense: expense,
    date: date,
    onClose: () => Navigator.pop(context),
  );
  if (MediaQuery.sizeOf(context).width < 600) {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      isDismissible: true,
      enableDrag: false,
      builder: (_) => form,
    );
  } else {
    await showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder:
          (_) => Dialog(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 460),
              child: form,
            ),
          ),
    );
  }
}

class ExpenseForm extends StatefulWidget {
  final CloudSession session;
  final Json? expense;
  final DateTime? date;
  final VoidCallback onClose;
  const ExpenseForm({
    required this.session,
    required this.onClose,
    this.expense,
    this.date,
    super.key,
  });
  @override
  State<ExpenseForm> createState() => ExpenseFormState();
}

class ExpenseFormState extends State<ExpenseForm> {
  final amount = TextEditingController(), memo = TextEditingController();
  late DateTime spentAt;
  late String categoryId, paymentMethod, id;
  final commandKey = const Uuid().v4();
  late String initial;
  bool busy = false, unknown = false, continuous = false;
  bool deleting = false;
  String? error;
  @override
  void initState() {
    super.initState();
    final e = widget.expense;
    final now = DateTime.now(), day = widget.date ?? now;
    spentAt =
        e == null
            ? DateTime(day.year, day.month, day.day, now.hour, now.minute)
            : DateTime.parse(e['spentAt'] as String).toLocal();
    categoryId = e?['categoryId'] as String? ?? 'cat_uncategorized';
    paymentMethod = e?['paymentMethod'] as String? ?? 'cash';
    id = e?['id'] as String? ?? const Uuid().v4();
    amount.text = e?['amount']?.toString() ?? '';
    memo.text = e?['memo'] as String? ?? '';
    initial = snapshot();
  }

  String snapshot() =>
      '$id|${amount.text}|${memo.text}|$categoryId|$paymentMethod|$spentAt';
  Future<bool> canDiscard() async {
    if (busy) return false;
    if (unknown) {
      message(context, '保存結果が不明です。同じ要求で再試行してください。');
      return false;
    }
    return snapshot() == initial || await confirm(context, '入力内容を破棄しますか？');
  }

  Future<void> close() async {
    if (await canDiscard()) widget.onClose();
  }

  Future<void> save() async {
    if (busy) return;
    if (deleting) {
      await delete();
      return;
    }
    final result = CalculatorParser.calculate(amount.text);
    final normalizedMemo = memo.text.trim().replaceAll(RegExp(r'[\r\n]+'), ' ');
    if (!unknown &&
        (!result.isValid ||
            normalizedMemo.characters.length > 100 ||
            spentAt.year < 1970 ||
            !widget.session.categories.any((c) => c['id'] == categoryId))) {
      setState(() => error = '金額は1〜99,999,999円、メモは100文字以内、有効なカテゴリを指定してください。');
      return;
    }
    setState(() => busy = true);
    try {
      final input = {
        'amount': result.amount,
        'categoryId': categoryId,
        'spentAt': spentAt.toUtc().toIso8601String(),
        'paymentMethod': paymentMethod,
        'memo': normalizedMemo.isEmpty ? null : normalizedMemo,
      };
      await widget.session.command(
        commandKey,
        widget.expense == null ? 'RecordExpense' : 'ModifyExpense',
        widget.expense == null
            ? {'id': id, ...input}
            : {
              'id': id,
              'expectedVersion': widget.expense!['version'],
              'changes': input,
            },
      );
      await widget.session.refreshVisible();
      if (!mounted) return;
      message(context, '支出を保存しました');
      if (continuous && widget.expense == null) {
        setState(() {
          id = const Uuid().v4();
          amount.clear();
          memo.clear();
          initial = snapshot();
          error = null;
          unknown = false;
        });
      } else {
        widget.onClose();
      }
    } on ApiFailure catch (e) {
      if (mounted) {
        setState(() {
          error = e.toString();
          unknown = e.unknownOutcome;
        });
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> delete() async {
    if (!deleting && !await confirm(context, 'この支出を削除しますか？')) return;
    deleting = true;
    setState(() => busy = true);
    try {
      await widget.session.command(commandKey, 'DeleteExpense', {
        'id': id,
        'expectedVersion': widget.expense!['version'],
        'kind': 'explicit',
      });
      await widget.session.refreshVisible();
      if (mounted) widget.onClose();
    } on ApiFailure catch (e) {
      if (mounted) {
        setState(() {
          error = e.toString();
          unknown = e.unknownOutcome;
          if (!unknown) deleting = false;
        });
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  void key(String value) {
    if (unknown || busy) return;
    var text = amount.text;
    if (value == 'C') {
      text = '';
    } else if (value == '⌫') {
      if (text.isNotEmpty) text = text.substring(0, text.length - 1);
    } else if (value == '=') {
      final r = CalculatorParser.calculate(text);
      if (r.isValid) {
        text = r.amount.toString();
      } else {
        error = '有効な計算式を入力してください。';
      }
    } else {
      if (RegExp(r'[+\-×÷]').hasMatch(value) &&
          text.isNotEmpty &&
          RegExp(r'[+\-×÷]$').hasMatch(text)) {
        text = text.substring(0, text.length - 1);
      }
      text += value;
    }
    setState(() => amount.text = text);
  }

  @override
  Widget build(BuildContext context) {
    final cats = widget.session.categories;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) close();
      },
      child: CallbackShortcuts(
        bindings: {const SingleActivator(LogicalKeyboardKey.escape): close},
        child: SafeArea(
          child: SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(
              20,
              16,
              20,
              20 + MediaQuery.viewInsetsOf(context).bottom,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        widget.expense == null ? '支出を追加' : '支出を編集',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                    ),
                    IconButton(
                      tooltip: '閉じる',
                      onPressed: busy ? null : close,
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
                if (error != null)
                  Text(error!, style: const TextStyle(color: Colors.red)),
                TextField(
                  controller: amount,
                  enabled: !busy && !unknown,
                  keyboardType: TextInputType.text,
                  decoration: const InputDecoration(
                    labelText: '金額・計算式',
                    prefixText: '¥ ',
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 4,
                  runSpacing: 4,
                  children:
                      [
                            '7',
                            '8',
                            '9',
                            '÷',
                            '4',
                            '5',
                            '6',
                            '×',
                            '1',
                            '2',
                            '3',
                            '-',
                            '0',
                            '00',
                            '⌫',
                            '+',
                            'C',
                            '=',
                          ]
                          .map(
                            (v) => SizedBox(
                              width: 58,
                              child: OutlinedButton(
                                onPressed:
                                    busy || unknown ? null : () => key(v),
                                child: Text(v),
                              ),
                            ),
                          )
                          .toList(),
                ),
                DropdownButtonFormField<String>(
                  initialValue:
                      cats.any((c) => c['id'] == categoryId)
                          ? categoryId
                          : null,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'カテゴリ'),
                  items:
                      cats
                          .map(
                            (c) => DropdownMenuItem(
                              value: c['id'] as String,
                              child: Text(c['name'] as String),
                            ),
                          )
                          .toList(),
                  onChanged:
                      busy || unknown
                          ? null
                          : (v) => setState(() => categoryId = v!),
                ),
                TextButton(
                  onPressed:
                      busy || unknown
                          ? null
                          : () async {
                            final d = await showDatePicker(
                              context: context,
                              initialDate: spentAt,
                              firstDate: DateTime(1970),
                              lastDate: DateTime(9999),
                            );
                            if (d == null || !context.mounted) return;
                            final t = await showTimePicker(
                              context: context,
                              initialTime: TimeOfDay.fromDateTime(spentAt),
                            );
                            if (t != null && mounted) {
                              setState(
                                () =>
                                    spentAt = DateTime(
                                      d.year,
                                      d.month,
                                      d.day,
                                      t.hour,
                                      t.minute,
                                    ),
                              );
                            }
                          },
                  child: Text('日時：${spentAt.toString().substring(0, 16)}'),
                ),
                DropdownButtonFormField<String>(
                  initialValue: paymentMethod,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: '支払い方法'),
                  items: const [
                    DropdownMenuItem(value: 'cash', child: Text('現金')),
                    DropdownMenuItem(
                      value: 'applePay',
                      child: Text('Apple Pay'),
                    ),
                    DropdownMenuItem(value: 'creditCard', child: Text('カード')),
                    DropdownMenuItem(value: 'eMoney', child: Text('電子マネー')),
                    DropdownMenuItem(value: 'other', child: Text('その他')),
                  ],
                  onChanged:
                      busy || unknown
                          ? null
                          : (v) => setState(() => paymentMethod = v!),
                ),
                TextField(
                  controller: memo,
                  enabled: !busy && !unknown,
                  maxLines: 2,
                  decoration: const InputDecoration(labelText: 'メモ（100文字以内）'),
                ),
                if (widget.expense == null)
                  CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('続けて登録'),
                    value: continuous,
                    onChanged:
                        busy || unknown
                            ? null
                            : (v) => setState(() => continuous = v!),
                  ),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: busy ? null : save,
                  child: Text(
                    busy
                        ? '保存中…'
                        : unknown
                        ? '同じ要求で再試行'
                        : '保存',
                  ),
                ),
                if (widget.expense != null)
                  TextButton(
                    onPressed: busy || unknown ? null : delete,
                    child: const Text(
                      '削除',
                      style: TextStyle(color: Colors.red),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    amount.dispose();
    memo.dispose();
    super.dispose();
  }
}
