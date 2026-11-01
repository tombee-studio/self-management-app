import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../cloud/api.dart';
import '../core/config/app_config.dart';
import '../cloud/session.dart';
import 'common.dart';

class BudgetScreen extends StatefulWidget {
  final CloudSession session;
  final VoidCallback onSaved;
  const BudgetScreen({required this.session, required this.onSaved, super.key});
  @override
  State<BudgetScreen> createState() => _BudgetScreenState();
}

class _BudgetScreenState extends State<BudgetScreen> {
  final amount = TextEditingController();
  final allocations = <String, TextEditingController>{};
  final commandKey = const Uuid().v4();
  int startDay = 1, version = 0;
  bool notifications = true,
      categoryBudget = false,
      busy = false,
      unknown = false;
  String? error;
  @override
  void initState() {
    super.initState();
    final p = widget.session.budget;
    amount.text = p?['monthlyAmount']?.toString() ?? '';
    version = p?['version'] as int? ?? 0;
    startDay = p?['startDay'] as int? ?? 1;
    notifications = p?['notificationEnabled'] as bool? ?? true;
    categoryBudget = p?['categoryBudgetEnabled'] as bool? ?? false;
    for (final c in widget.session.categories) {
      final a =
          (p?['allocations'] as List? ?? [])
              .where((a) => a['categoryId'] == c['id'])
              .firstOrNull;
      allocations[c['id'] as String] = TextEditingController(
        text: a?['allocatedAmount']?.toString() ?? '0',
      );
    }
  }

  Future<void> save() async {
    final n = int.tryParse(amount.text);
    if (!unknown &&
        (n == null ||
            n < 1 ||
            n > 99999999 ||
            allocations.values.any((x) {
              final v = int.tryParse(x.text);
              return v == null || v < 0 || v > 99999999;
            }))) {
      setState(() => error = '総予算は1〜99,999,999円、配分は0〜99,999,999円で入力してください。');
      return;
    }
    setState(() => busy = true);
    try {
      final saved = await widget.session.command(
        commandKey,
        'ConfigureBudgetPlan',
        {
          'expectedVersion': version,
          'monthlyAmount': n,
          'startDay': startDay,
          'notificationEnabled': notifications,
          'categoryBudgetEnabled': categoryBudget,
          'allocations':
              allocations.entries
                  .map(
                    (e) => {
                      'categoryId': e.key,
                      'allocatedAmount': int.tryParse(e.value.text),
                    },
                  )
                  .toList(),
        },
      );
      version = saved['value']['version'] as int;
      await widget.session.refreshVisible();
      if (mounted) {
        message(context, '予算設定を保存しました');
        widget.onSaved();
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

  @override
  Widget build(BuildContext context) {
    final allocationTotal = allocations.values.fold<int>(
      0,
      (n, c) => n + (int.tryParse(c.text) ?? 0),
    );
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        LoadNotice(widget.session.slot('budget'), widget.session.refreshCommon),
        Section('予算設定・管理', [
          if (error != null)
            Text(error!, style: const TextStyle(color: Colors.red)),
          TextField(
            controller: amount,
            enabled: !busy && !unknown,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: '月間総予算'),
            onChanged: (_) => setState(() {}),
          ),
          DropdownButtonFormField<int>(
            initialValue: startDay,
            decoration: const InputDecoration(labelText: '家計期間の開始日'),
            items: List.generate(
              28,
              (i) => DropdownMenuItem(value: i + 1, child: Text('${i + 1}日')),
            ),
            onChanged:
                busy || unknown ? null : (v) => setState(() => startDay = v!),
          ),
          SwitchListTile(
            title: const Text('カテゴリ別予算'),
            value: categoryBudget,
            onChanged:
                busy || unknown
                    ? null
                    : (v) => setState(() => categoryBudget = v),
          ),
          SwitchListTile(
            title: const Text('予算の80%・100%到達通知'),
            value: notifications,
            onChanged:
                busy || unknown
                    ? null
                    : (v) => setState(() => notifications = v),
          ),
          if (categoryBudget)
            for (final c in widget.session.categories)
              TextField(
                controller: allocations[c['id']],
                enabled: !busy && !unknown,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(labelText: '${c['name']}の配分'),
                onChanged: (_) => setState(() {}),
              ),
          if (allocationTotal > (int.tryParse(amount.text) ?? 0))
            Text(
              '配分が総予算を${yen(allocationTotal - (int.tryParse(amount.text) ?? 0))}超えています（保存可能）',
              style: const TextStyle(color: Colors.orange),
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
        ]),
      ],
    );
  }

  @override
  void dispose() {
    amount.dispose();
    for (final c in allocations.values) {
      c.dispose();
    }
    super.dispose();
  }
}

class CategoryScreen extends StatefulWidget {
  final CloudSession session;
  const CategoryScreen({required this.session, super.key});
  @override
  State<CategoryScreen> createState() => _CategoryScreenState();
}

class _CategoryScreenState extends State<CategoryScreen> {
  bool busy = false;
  PendingCommand? pending;
  String? error;
  Future<void> execute(PendingCommand command) async {
    setState(() => busy = true);
    try {
      await widget.session.api.submit(command);
      pending = null;
      await widget.session.refreshVisible();
    } on ApiFailure catch (e) {
      pending = e.unknownOutcome ? command : null;
      if (mounted) setState(() => error = e.toString());
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> edit([Json? category]) async {
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder:
          (_) => Dialog(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 460),
              child: CategoryEditor(
                session: widget.session,
                category: category,
              ),
            ),
          ),
    );
    if (mounted) setState(() {});
  }

  Future<void> retire(Json c) async {
    setState(() => busy = true);
    try {
      final f = {
        'month': null,
        'keyword': '',
        'categoryIds': [c['id']],
        'source': null,
        'timeZone': widget.session.timeZone,
      };
      final page =
          (await widget.session.api.query('QueryHistory', {
                'filter': f,
              }))['value']
              as Json;
      final totals =
          (await widget.session.api.query('GetHistoryTotals', {
                'filter': f,
                'snapshotId': page['snapshotId'],
              }))['value']
              as Json;
      if (!mounted) return;
      if (await confirm(
        context,
        '「${c['name']}」を削除し、${totals['count']}件の支出を未分類に変更します。予算配分も削除します。',
      )) {
        await execute(
          PendingCommand.create('RetireCategory', {
            'categoryId': c['id'],
            'expectedCatalogVersion': widget.session.catalog!['version'],
          }),
        );
      }
    } on ApiFailure catch (e) {
      if (mounted) message(context, e);
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final categories = widget.session.categories;
    return Column(
      children: [
        LoadNotice(
          widget.session.slot('catalog'),
          widget.session.refreshCommon,
        ),
        if (error != null) Text(error!),
        if (pending != null)
          TextButton(
            onPressed: busy ? null : () => execute(pending!),
            child: const Text('同じ要求で再試行'),
          ),
        Padding(
          padding: const EdgeInsets.all(16),
          child: FilledButton.icon(
            onPressed: busy || pending != null ? null : edit,
            icon: const Icon(Icons.add),
            label: const Text('カテゴリを追加'),
          ),
        ),
        Expanded(
          child: ReorderableListView.builder(
            itemCount: categories.length,
            onReorderItem: (oldIndex, newIndex) {
              if (busy || pending != null) return;
              final ids = categories.map((c) => c['id']).toList();
              ids.insert(newIndex, ids.removeAt(oldIndex));
              execute(
                PendingCommand.create('ReorderCatalog', {
                  'expectedCatalogVersion': widget.session.catalog!['version'],
                  'orderedIds': ids,
                }),
              );
            },
            itemBuilder: (context, i) {
              final c = categories[i], system = c['isSystem'] == true;
              return ListTile(
                key: ValueKey(c['id']),
                leading: Icon(iconMap[c['iconKey']], color: categoryColor(c)),
                title: Text(c['name'] as String),
                subtitle: system ? const Text('編集・削除できません') : null,
                onTap: system || busy || pending != null ? null : () => edit(c),
                trailing:
                    system
                        ? null
                        : IconButton(
                          tooltip: 'カテゴリを削除',
                          onPressed:
                              busy || pending != null ? null : () => retire(c),
                          icon: const Icon(Icons.delete_outline),
                        ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class CategoryEditor extends StatefulWidget {
  final CloudSession session;
  final Json? category;
  const CategoryEditor({required this.session, this.category, super.key});
  @override
  State<CategoryEditor> createState() => _CategoryEditorState();
}

class _CategoryEditorState extends State<CategoryEditor> {
  final name = TextEditingController();
  late String icon, color, id;
  late int version;
  bool busy = false, unknown = false;
  String? error;
  final commandKey = const Uuid().v4();
  @override
  void initState() {
    super.initState();
    name.text = widget.category?['name'] as String? ?? '';
    icon = widget.category?['iconKey'] as String? ?? 'folder';
    color = widget.category?['colorHex'] as String? ?? '#6366F1';
    id = widget.category?['id'] as String? ?? const Uuid().v4();
    version = widget.session.catalog!['version'] as int;
  }

  Future<void> save() async {
    setState(() => busy = true);
    try {
      await widget.session.command(commandKey, 'UpsertCategory', {
        'categoryId': id,
        'expectedCatalogVersion': version,
        'name': name.text.trim(),
        'iconKey': icon,
        'colorHex': color,
      });
      await widget.session.refreshVisible();
      if (mounted) Navigator.pop(context);
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

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !busy && !unknown,
    child: SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: name,
            enabled: !busy && !unknown,
            decoration: const InputDecoration(labelText: 'カテゴリ名（20文字以内）'),
          ),
          if (error != null) Text(error!),
          Wrap(
            children:
                iconMap.entries
                    .map(
                      (e) => IconButton(
                        onPressed:
                            busy || unknown
                                ? null
                                : () => setState(() => icon = e.key),
                        icon: Icon(
                          e.value,
                          color:
                              icon == e.key
                                  ? Theme.of(context).colorScheme.primary
                                  : null,
                        ),
                      ),
                    )
                    .toList(),
          ),
          Wrap(
            children:
                [
                      '#F97316',
                      '#14B8A6',
                      '#3B82F6',
                      '#EC4899',
                      '#EF4444',
                      '#8B5CF6',
                      '#6366F1',
                      '#94A3B8',
                    ]
                    .map(
                      (c) => IconButton(
                        onPressed:
                            busy || unknown
                                ? null
                                : () => setState(() => color = c),
                        icon: Icon(
                          c == color ? Icons.check_circle : Icons.circle,
                          color: categoryColor({'colorHex': c}),
                        ),
                      ),
                    )
                    .toList(),
          ),
          FilledButton(
            onPressed: busy ? null : save,
            child: Text(unknown ? '同じ要求で再試行' : '保存'),
          ),
          TextButton(
            onPressed: busy || unknown ? null : () => Navigator.pop(context),
            child: const Text('閉じる'),
          ),
        ],
      ),
    ),
  );
  @override
  void dispose() {
    name.dispose();
    super.dispose();
  }
}

class ConnectionScreen extends StatefulWidget {
  final CloudSession session;
  const ConnectionScreen({required this.session, super.key});
  @override
  State<ConnectionScreen> createState() => _ConnectionScreenState();
}

class _ConnectionScreenState extends State<ConnectionScreen> {
  final endpoint = TextEditingController();
  bool busy = false;
  String? result;
  @override
  void initState() {
    super.initState();
    endpoint.text = widget.session.endpoint;
  }

  Future<void> run(Future<void> Function() action) async {
    setState(() => busy = true);
    try {
      await action();
    } catch (e) {
      if (mounted) setState(() => result = e.toString());
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('クラウド接続設定')),
    body: ListView(
      padding: const EdgeInsets.all(20),
      children: [
        TextField(
          controller: endpoint,
          enabled: !busy,
          decoration: const InputDecoration(labelText: 'HTTPS接続先（空欄は内蔵接続先）'),
        ),
        FilledButton(
          onPressed:
              busy
                  ? null
                  : () => run(() async {
                    await widget.session.configureEndpoint(
                      endpoint.text.isEmpty
                          ? AppConfig.defaultCloudSyncEndpoint
                          : endpoint.text,
                    );
                    setState(() => result = '接続先を保存しました');
                  }),
          child: const Text('接続先を保存'),
        ),
        TextButton(
          onPressed:
              busy
                  ? null
                  : () => run(() async {
                    final ok = await widget.session.api.health();
                    setState(() => result = ok ? '接続成功（API版3）' : '接続失敗');
                  }),
          child: const Text('接続テスト'),
        ),
        TextButton(
          onPressed:
              busy
                  ? null
                  : () => run(() async {
                    await widget.session.refreshVisible();
                    setState(
                      () =>
                          result =
                              widget.session.hasReadError
                                  ? '取得に失敗した表示があります。未更新の表示から再試行してください。'
                                  : '表示を再取得しました',
                    );
                  }),
          child: const Text('今すぐ更新'),
        ),
        Text('接続先：${widget.session.endpoint}'),
        Text(
          '最終成功：${widget.session.lastSuccessfulAccess?.toLocal().toString() ?? '未取得'}',
        ),
        if (result != null) Text(result!),
        if (busy) const LinearProgressIndicator(),
      ],
    ),
  );
  @override
  void dispose() {
    endpoint.dispose();
    super.dispose();
  }
}
