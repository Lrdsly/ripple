import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../app_state.dart';
import '../core/theme.dart';
import '../data/models.dart';

const _short = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];

class FixedPage extends StatelessWidget {
  const FixedPage({super.key});
  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    final now = DateTime.now();
    return Scaffold(
      appBar: AppBar(title: const Text('Fixed expenses')),
      floatingActionButton: FloatingActionButton.extended(
        icon: const Icon(Icons.add),
        label: const Text('Add'),
        onPressed: () => showModalBottomSheet(
            context: context, isScrollControlled: true, builder: (_) => const _AddSheet()),
      ),
      body: s.fixed.isEmpty
          ? const Center(child: Text('No fixed expenses yet'))
          : ListView(padding: const EdgeInsets.all(16), children: [
              for (final f in s.fixed)
                Dismissible(
                  key: ValueKey(f.id),
                  onDismissed: (_) => s.removeFixed(f.id),
                  background: Container(color: Colors.red.withValues(alpha: .4)),
                  child: Card(
                    child: ListTile(
                      title: Text(f.name),
                      subtitle: Text(f.mode == FixedMode.perMonth
                          ? '${f.timesPerMonth}× per month'
                          : f.weekdays.map((d) => _short[d - 1]).join(' ')),
                      trailing: Text('$kCurrency ${money(f.monthlyCost(now.year, now.month))}',
                          style: const TextStyle(fontWeight: FontWeight.w700)),
                    ),
                  ),
                ),
            ]),
    );
  }
}

class _AddSheet extends StatefulWidget {
  const _AddSheet();
  @override
  State<_AddSheet> createState() => _AddSheetState();
}

class _AddSheetState extends State<_AddSheet> {
  final name = TextEditingController(), amount = TextEditingController();
  FixedMode mode = FixedMode.weekdays;
  final days = <int>{};
  int times = 1;

  @override
  Widget build(BuildContext context) => Padding(
        padding: EdgeInsets.fromLTRB(20, 20, 20, 20 + MediaQuery.of(context).viewInsets.bottom),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(controller: name, decoration: const InputDecoration(labelText: 'Name')),
          TextField(
              controller: amount,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Amount each time')),
          const SizedBox(height: 16),
          SegmentedButton<FixedMode>(
            segments: const [
              ButtonSegment(value: FixedMode.weekdays, label: Text('Weekdays')),
              ButtonSegment(value: FixedMode.perMonth, label: Text('Per month')),
            ],
            selected: {mode},
            onSelectionChanged: (v) => setState(() => mode = v.first),
          ),
          const SizedBox(height: 12),
          if (mode == FixedMode.weekdays)
            Wrap(spacing: 6, children: [
              for (var d = 1; d <= 7; d++)
                FilterChip(
                  label: Text(_short[d - 1]),
                  selected: days.contains(d),
                  onSelected: (v) => setState(() => v ? days.add(d) : days.remove(d)),
                ),
            ])
          else
            Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              IconButton(icon: const Icon(Icons.remove), onPressed: () => setState(() => times = (times - 1).clamp(1, 31))),
              Text('$times days / month', style: const TextStyle(fontSize: 16)),
              IconButton(icon: const Icon(Icons.add), onPressed: () => setState(() => times = (times + 1).clamp(1, 31))),
            ]),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: () {
              final amt = double.tryParse(amount.text.replaceAll(',', ''));
              if (name.text.isEmpty || amt == null) return;
              context.read<AppState>().addFixed(FixedExpense(
                    id: DateTime.now().microsecondsSinceEpoch.toString(),
                    name: name.text,
                    amount: amt,
                    mode: mode,
                    weekdays: days.toList()..sort(),
                    timesPerMonth: times,
                  ));
              Navigator.pop(context);
            },
            child: const Text('Save'),
          ),
        ]),
      );
}
