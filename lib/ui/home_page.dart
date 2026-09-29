import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../app_state.dart';
import '../core/theme.dart';
import '../domain/analytics.dart';
import 'fixed_page.dart';
import 'weekly_chart.dart';

const _months = ['January','February','March','April','May','June','July',
  'August','September','October','November','December'];

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    final a = s.analytics;
    final now = DateTime.now();
    final start = a.weekStart(now).add(Duration(days: 7 * s.weekOffset));
    final week = a.week(start);
    final fc = a.forecast(now.year, now.month, s.fixed);
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: const Text('Wallet', style: TextStyle(fontWeight: FontWeight.w700)),
        actions: [
          IconButton(
            tooltip: s.folder ?? 'Demo data — pick Obsidian folder',
            icon: Icon(s.folder == null ? Icons.folder_open : Icons.folder),
            onPressed: () async {
              final p = await FilePicker.platform.getDirectoryPath();
              if (p != null) s.setFolder(p);
            },
          ),
          IconButton(icon: const Icon(Icons.refresh), onPressed: s.reload),
        ],
      ),
      body: s.loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(padding: const EdgeInsets.fromLTRB(16, 4, 16, 32), children: [
              if (s.error != null)
                Card(child: Padding(padding: const EdgeInsets.all(16), child: Text(s.error!))),
              _Hero(fc: fc, month: _months[now.month - 1]),
              const SizedBox(height: 16),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(children: [
                    Row(children: [
                      Text('This week', style: Theme.of(context).textTheme.titleMedium),
                      const Spacer(),
                      IconButton(icon: const Icon(Icons.chevron_left), onPressed: () => s.shiftWeek(-1)),
                      IconButton(
                          icon: const Icon(Icons.chevron_right),
                          onPressed: s.weekOffset < 0 ? () => s.shiftWeek(1) : null),
                    ]),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text('$kCurrency ${money(week.fold(0.0, (t, d) => t + d.total))}',
                          style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700)),
                    ),
                    const SizedBox(height: 20),
                    WeeklyChart(days: week),
                  ]),
                ),
              ),
              const SizedBox(height: 16),
              Row(children: [
                Expanded(child: _Stat('Daily average', money(fc.avgDaily), Icons.show_chart, cs.primary)),
                const SizedBox(width: 12),
                Expanded(child: _Stat('Spent this month', money(fc.spentSoFar), Icons.payments_outlined, cs.tertiary)),
              ]),
              const SizedBox(height: 16),
              Card(
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                  leading: const Icon(Icons.event_repeat),
                  title: const Text('Fixed expenses'),
                  subtitle: Text('${s.fixed.length} defined · $kCurrency ${money(fc.fixed)} this month'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const FixedPage())),
                ),
              ),
            ]),
    );
  }
}

class _Hero extends StatelessWidget {
  final Forecast fc;
  final String month;
  const _Hero({required this.fc, required this.month});
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: LinearGradient(colors: [cs.primary, cs.tertiary.withOpacity(.85)],
            begin: Alignment.topLeft, end: Alignment.bottomRight),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Required for $month', style: const TextStyle(color: Colors.white70)),
        const SizedBox(height: 6),
        Text('$kCurrency ${money(fc.total)}',
            style: const TextStyle(fontSize: 36, fontWeight: FontWeight.w800, color: Colors.white)),
        const SizedBox(height: 14),
        Row(children: [
          _pill('Variable ${money(fc.variable)}'),
          const SizedBox(width: 8),
          _pill('Fixed ${money(fc.fixed)}'),
        ]),
      ]),
    );
  }

  Widget _pill(String t) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(20)),
        child: Text(t, style: const TextStyle(color: Colors.white, fontSize: 12)),
      );
}

class _Stat extends StatelessWidget {
  final String label, value;
  final IconData icon;
  final Color color;
  const _Stat(this.label, this.value, this.icon, this.color);
  @override
  Widget build(BuildContext context) => Card(
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Icon(icon, color: color),
            const SizedBox(height: 12),
            Text(value, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
            Text(label, style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurfaceVariant)),
          ]),
        ),
      );
}
