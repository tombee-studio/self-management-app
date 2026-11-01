import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../cloud/api.dart';
import '../cloud/session.dart';

String yen(dynamic n) => NumberFormat.currency(
  locale: 'ja_JP',
  symbol: '¥',
  decimalDigits: 0,
).format(n ?? 0);
const iconMap = <String, IconData>{
  'restaurant': Icons.restaurant,
  'shopping_bag': Icons.shopping_bag,
  'train': Icons.train,
  'local_cafe': Icons.local_cafe,
  'checkroom': Icons.checkroom,
  'medical_services': Icons.medical_services,
  'sports_esports': Icons.sports_esports,
  'home': Icons.home,
  'folder': Icons.folder,
};
Color categoryColor(Json c) =>
    Color(int.parse('FF${(c['colorHex'] as String).substring(1)}', radix: 16));
void message(BuildContext context, Object text) => ScaffoldMessenger.of(
  context,
).showSnackBar(SnackBar(content: Text(text.toString())));
Future<bool> confirm(BuildContext context, String text) async =>
    await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('確認'),
            content: Text(text),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('キャンセル'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('続ける'),
              ),
            ],
          ),
    ) ??
    false;

class LoadNotice extends StatelessWidget {
  final Projection projection;
  final VoidCallback retry;
  const LoadNotice(this.projection, this.retry, {super.key});
  @override
  Widget build(BuildContext context) => Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      if (projection.loading) const LinearProgressIndicator(),
      if (projection.error != null)
        MaterialBanner(
          content: Text(
            '${projection.value != null ? '未更新：' : ''}${projection.error}',
          ),
          actions: [TextButton(onPressed: retry, child: const Text('再試行'))],
        ),
    ],
  );
}

class Section extends StatelessWidget {
  final String title;
  final List<Widget> children;
  const Section(this.title, this.children, {super.key});
  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 12),
          ...children,
        ],
      ),
    ),
  );
}
