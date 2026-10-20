import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../app_state.dart';
import '../core/theme.dart';
import '../data/models.dart';
import '../data/sources/markdown_source.dart';

/// Repair screen: restore payments removed between m and n days ago.
/// Source of truth is the vault's hidden `.ripple_removed.json` log.
class RemovedPage extends StatefulWidget {
  final String folder;
  const RemovedPage({super.key, required this.folder});
  @override
  State<RemovedPage> createState() => _RemovedPageState();
}

class _RemovedPageState extends State<RemovedPage> {
  int m = 0;
  int n = 7;
  List<RemovedPayment> log = [];
  bool loading = true;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    final l = await MarkdownSource(widget.folder).removedLog();
    if (!mounted) return;
    setState(() {
      log = l;
      loading = false;
    });
  }

  List<RemovedPayment> get filtered =>
      MarkdownSource.removedBetween(log, m, n);

  Future<void> _restoreOne(RemovedPayment rec) async {
    final st = context.read<AppState>();
    try {
      await MarkdownSource(widget.folder).restore(rec);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('بازیابی ناموفق: $e')),
      );
      return;
    }
    await st.reload();
    await _refresh();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('بازیابی شد')),
    );
  }

  Future<void> _restoreAll() async {
    final st = context.read<AppState>();
    final src = MarkdownSource(widget.folder);
    for (final rec in filtered) {
      await src.restore(rec);
    }
    await st.reload();
    await _refresh();
  }

  Widget _stepper(String label, int value, ValueChanged<int> set) =>
      Row(
        children: [
          Text(label),
          const Spacer(),
          IconButton(
            icon: const Icon(Icons.remove),
            onPressed: value > 0 ? () => set(value - 1) : null,
          ),
          Text(faDigits(value.toString()),
              style: const TextStyle(fontSize: 16)),
          IconButton(
            icon: const Icon(Icons.add),
            onPressed:
                value < 365 ? () => set(value + 1) : null,
          ),
        ],
      );

  @override
  Widget build(BuildContext context) {
    final items = filtered;
    return Scaffold(
      appBar: AppBar(
        title: const Text('حذف‌شده‌ها'),
        actions: [
          if (items.isNotEmpty)
            TextButton(
              onPressed: _restoreAll,
              child: const Text('بازگردانی همه'),
            ),
        ],
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Card(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 8),
                    child: Column(
                      children: [
                        _stepper('از', m, (v) => setState(() => m = v)),
                        _stepper('تا', n, (v) => setState(() => n = v)),
                        Text(
                          'بازه ${faDigits(m.toString())} تا ${faDigits(n.toString())} روز پیش',
                          style: TextStyle(
                            fontSize: 12,
                            color: Theme.of(context)
                                .colorScheme
                                .onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                if (log.isEmpty)
                  Center(
                      child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.delete_outline,
                          size: 56,
                          color: Theme.of(context)
                              .colorScheme
                              .onSurfaceVariant),
                      const SizedBox(height: 12),
                      const Text('چیزی حذف نشده است'),
                    ],
                  ))
                else if (items.isEmpty)
                  const Center(
                      child:
                          Text('در این بازه چیزی حذف نشده است'))
                else
                  for (final rec in items)
                    Card(
                      child: ListTile(
                        title: Text(rec.title),
                        subtitle: Text(
                            '${moneyFa(rec.amount)} · ${solarMd(rec.date)} · ${faDigits(_ago(rec.removedAt).toString())} روز پیش'),
                        trailing: IconButton(
                          icon:
                              const Icon(Icons.restore_outlined),
                          tooltip: 'بازیابی',
                          onPressed: () => _restoreOne(rec),
                        ),
                      ),
                    ),
              ],
            ),
    );
  }

  static int _ago(DateTime dt) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final d = DateTime(dt.year, dt.month, dt.day);
    return today.difference(d).inDays;
  }
}
