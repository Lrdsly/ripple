import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shamsi_date/shamsi_date.dart';
import '../app_state.dart';
import '../core/theme.dart';
import '../data/models.dart';
import '../data/sources/markdown_source.dart';
import '../domain/analytics.dart';
import 'fixed_page.dart';
import 'weekly_chart.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    final a = s.analytics;
    final now = DateTime.now();
    final start = a.weekStart(now).add(Duration(days: 7 * s.weekOffset));
    final week = a.week(start);
    final jnow = Jalali.fromDateTime(now);
    final fc = a.forecastJalali(jnow.year, jnow.month, s.fixed);

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: const Text('مالی',
            style: TextStyle(fontWeight: FontWeight.w700)),
        actions: [
          IconButton(
            tooltip: 'پوسته',
            icon: const Icon(Icons.palette_outlined),
            onPressed: () => showModalBottomSheet(
                context: context,
                builder: (_) => const _ThemeSheet()),
          ),
          IconButton(
            tooltip: s.folder == null
                ? 'داده‌های نمونه — پوشه Obsidian را انتخاب کنید'
                : 'پوشه Obsidian',
            icon:
                Icon(s.folder == null ? Icons.folder_open : Icons.folder),
            onPressed: () async {
              final p = await FilePicker.platform.getDirectoryPath();
              if (p != null) s.setFolder(p);
            },
          ),
          IconButton(
              icon: const Icon(Icons.refresh), onPressed: s.reload),
        ],
      ),
      body: s.loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding:
                  const EdgeInsets.fromLTRB(16, 4, 16, 32),
              children: [
                if (s.error != null)
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Text(s.error!),
                    ),
                  ),
                _Hero(fc: fc, month: solarMonthName(now)),
                const SizedBox(height: 16),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(children: [
                      Row(children: [
                        Text('این هفته',
                            style: Theme.of(context).textTheme.titleMedium),
                        const Spacer(),
                        IconButton(
                          icon: const Icon(Icons.chevron_right),
                          onPressed: () => s.shiftWeek(-1),
                        ),
                        IconButton(
                          icon: const Icon(Icons.chevron_left),
                          onPressed: s.weekOffset < 0
                              ? () => s.shiftWeek(1)
                              : null,
                        ),
                      ]),
                      Align(
                        alignment: Alignment.centerRight,
                        child: Text(
                          'تومان ${moneyFa(week.fold(0.0, (t, d) => t + d.total))}',
                          style: Theme.of(context)
                              .textTheme
                              .headlineSmall
                              ?.copyWith(fontWeight: FontWeight.w700),
                        ),
                      ),
                      const SizedBox(height: 20),
                      _WeekSection(
                        key: ValueKey(start),
                        days: week,
                        analytics: a,
                        fixed: s.fixed,
                      ),
                    ]),
                  ),
                ),
                const SizedBox(height: 16),
                Row(children: [
                  Expanded(
                    child: _Stat(
                      'میانگین روزانه',
                      moneyFa(fc.avgDaily),
                      Icons.auto_graph,
                      Theme.of(context).colorScheme.primary,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _Stat(
                      'هزینه این ماه',
                      moneyFa(fc.spentSoFar),
                      Icons.receipt_long_outlined,
                      Theme.of(context).colorScheme.tertiary,
                    ),
                  ),
                ]),
                const SizedBox(height: 16),
                Card(
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 8),
                    leading: const Icon(Icons.event_repeat),
                    title: const Text('هزینه‌های ثابت'),
                    subtitle: Text(
                        '${s.fixed.length} تعریف شده · تومان ${moneyFa(fc.fixed)} این ماه'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () =>
                        Navigator.push(context, MaterialPageRoute(
                            builder: (_) => const FixedPage())),
                  ),
                ),
              ],
            ),
    );
  }
}

class _WeekSection extends StatefulWidget {
  final List<DayTotal> days;
  final Analytics analytics;
  final List<FixedExpense> fixed;
  const _WeekSection(
      {super.key,
      required this.days,
      required this.analytics,
      required this.fixed});

  @override
  State<_WeekSection> createState() => _WeekSectionState();
}

class _WeekSectionState extends State<_WeekSection> {
  late DateTime selected;

  @override
  void initState() {
    super.initState();
    final today = dateOnly(DateTime.now());
    selected = widget.days.any((d) => d.date == today)
        ? today
        : widget.days.last.date;
  }

  Future<void> _removePayment(Payment p) async {
    final st = context.read<AppState>();
    final folder = st.folder;
    if (folder == null) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('حذف پرداخت'),
        content: Text('${moneyFa(p.amount)} ${p.title}\nاز فایل حذف شود؟'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: const Text('لغو'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(c, true),
            child: const Text('حذف'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    RemovedPayment? rec;
    try {
      rec = await MarkdownSource(folder).removeOne(
        date: p.date,
        amount: p.amount,
        title: p.title,
        tags: p.allTags,
      );
    } on VaultWriteException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message)),
      );
      return;
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('خطا: $e')),
      );
      return;
    }
    if (!mounted) return;
    if (rec == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('خط در فایل پیدا نشد')),
      );
      return;
    }
    await st.reload();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('حذف شد'),
        action: SnackBarAction(
          label: 'بازگردانی',
          onPressed: () async {
            try {
              await MarkdownSource(folder).restore(rec!);
              await st.reload();
            } catch (e) {
              if (!mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('بازیابی ناموفق: $e')),
              );
            }
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final payments = widget.analytics.dayPayments(selected);
    final dups = widget.analytics.duplicateGroups(selected);
    // Fixed costs due this day, shown in another color so a .md line
    // duplicating a fixed cost is visible side by side.
    final due =
        widget.fixed.where((f) => f.appliesOn(selected)).toList();
    // Removable only with a real vault folder (demo data has no files).
    final folder = context.read<AppState>().folder;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        WeeklyChart(
          days: widget.days,
          selected: selected,
          onSelect: (d) => setState(() => selected = dateOnly(d)),
        ),
        if (dups.isNotEmpty) ...[
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(
                horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.amber.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: Colors.amber.withValues(alpha: 0.4),
              ),
            ),
            child: Row(
              children: [
                const Icon(Icons.warning_amber_outlined,
                    size: 18, color: Colors.amber),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'تکرار مشکوک: ${dups.map((g) {
                      final tag = g.first.allTags.isEmpty
                          ? g.first.title
                          : '#${g.first.allTags.first}';
                      return '$tag ${faDigits(g.length.toString())}× ${moneyFa(g.first.amount)}';
                    }).join('، ')} — شمرده شدند، بررسی کنید',
                    style: const TextStyle(fontSize: 12),
                  ),
                ),
              ],
            ),
          ),
        ],
        const SizedBox(height: 12),
        Row(
          children: [
            Text(
              'پرداخت‌های ${_dayLabel(selected)}',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
            ),
            const SizedBox(width: 8),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: cs.secondary.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                faDigits(payments.length.toString()),
                style: TextStyle(fontSize: 12, color: cs.secondary),
              ),
            ),
            if (due.isNotEmpty) ...[
              const SizedBox(width: 6),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: cs.tertiary.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.event_repeat,
                        size: 12, color: cs.tertiary),
                    const SizedBox(width: 4),
                    Text(
                      faDigits(due.length.toString()),
                      style:
                          TextStyle(fontSize: 12, color: cs.tertiary),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 8),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 350),
          switchInCurve: Curves.easeOutCubic,
          switchOutCurve: Curves.easeIn,
          transitionBuilder: (child, anim) => FadeTransition(
            opacity: anim,
            child: SlideTransition(
              position: Tween(
                begin: const Offset(0, 0.15),
                end: Offset.zero,
              ).animate(anim),
              child: child,
            ),
          ),
          child: payments.isEmpty && due.isEmpty
              ? Align(
                  key: ValueKey('empty-$selected'),
                  alignment: Alignment.centerRight,
                  child: Text(
                    'پرداختی ثبت نشده',
                    style: TextStyle(
                        fontSize: 12, color: cs.onSurfaceVariant),
                  ),
                )
              : SizedBox(
                  key: ValueKey('list-$selected'),
                  height: 108,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: payments.length + due.length,
                    separatorBuilder: (context, index) =>
                        const SizedBox(width: 8),
                    itemBuilder: (context, i) => i <
                            payments.length
                        ? _TagCard(
                            payment: payments[i],
                            index: i,
                            onRemove: folder == null
                                ? null
                                : () =>
                                    _removePayment(payments[i]),
                          )
                        : _FixedCard(
                            fixed: due[i - payments.length],
                            index: i,
                            selected: selected,
                          ),
                  ),
                ),
        ),
      ],
    );
  }
}

class _TagCard extends StatelessWidget {
  final Payment payment;
  final int index;
  final VoidCallback? onRemove;
  const _TagCard({required this.payment, required this.index, this.onRemove});

  void _sheet(BuildContext context) {
    final tag = payment.allTags.isEmpty
        ? 'بدون برچسب'
        : '#${payment.allTags.first}';
    showModalBottomSheet(
      context: context,
      builder: (c) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(tag,
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 4),
            Text(
                '${moneyFa(payment.amount)} ${payment.title}'),
            const SizedBox(height: 12),
            ListTile(
              leading:
                  const Icon(Icons.remove_circle_outline),
              title: const Text('حذف پرداخت'),
              subtitle:
                  const Text('از فایل حذف می‌شود'),
              onTap: () {
                Navigator.pop(c);
                onRemove?.call();
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tag = payment.allTags.isEmpty
        ? 'بدون برچسب'
        : '#${payment.allTags.first}';
    final dots = cs.onSurface.withValues(alpha: 0.55);
    // Staggered fade+slide so the strip flows in instead of popping.
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: 300 + index * 60),
      curve: Curves.easeOutCubic,
      builder: (context, v, child) => Opacity(
        opacity: v,
        child: Transform.translate(
          offset: Offset(12 * (1 - v), 0),
          child: child,
        ),
      ),
      child: GestureDetector(
        onTap:
            onRemove == null ? null : () => _sheet(context),
        child: Container(
          width: 150,
          padding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: cs.secondary.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: cs.secondary.withValues(alpha: 0.25),
            ),
          ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              tag,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: cs.secondary,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              payment.title.isEmpty ? '—' : payment.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 12),
            ),
            Text(
              moneyFa(payment.amount),
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: cs.onSurfaceVariant,
              ),
            ),
            if (onRemove != null)
              InkWell(
                onTap: () => _sheet(context),
                borderRadius: BorderRadius.circular(10),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 1),
                  child: Icon(Icons.more_horiz,
                      size: 16, color: dots),
                ),
              ),
          ],
        ),
        ),
      ),
    );
  }
}

class _FixedCard extends StatelessWidget {
  final FixedExpense fixed;
  final int index;
  final DateTime selected;
  const _FixedCard(
      {required this.fixed, required this.index, required this.selected});

  Future<void> _skipDay(BuildContext context) async {
    final st = context.read<AppState>();
    final messenger = ScaffoldMessenger.of(context);
    final key = FixedExpense.dayKey(selected);
    await st.updateFixed(fixed.copyWith(
        skipped: [...fixed.skipped, key]));
    messenger.showSnackBar(
      SnackBar(
        content: Text('این هزینه از ${solarMd(selected)} مستثنا شد'),
        action: SnackBarAction(
          label: 'لغو',
          onPressed: () async {
            final cur = st.fixed
                .where((e) => e.id == fixed.id)
                .toList();
            if (cur.isEmpty) return;
            await st.updateFixed(cur.first.copyWith(
                skipped: cur.first.skipped
                    .where((k) => k != key)
                    .toList()));
          },
        ),
      ),
    );
  }

  void _sheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (c) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(fixed.name,
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 4),
            Text(
                '${moneyFa(fixed.amount)} · ${solarMd(selected)}'),
            const SizedBox(height: 12),
            ListTile(
              leading: const Icon(Icons.block_outlined),
              title: const Text('این روز حساب نشود'),
              subtitle:
                  const Text('بدون وارد کردن تاریخ'),
              onTap: () {
                Navigator.pop(c);
                _skipDay(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.settings_outlined),
              title: const Text('مدیریت هزینه‌ها'),
              onTap: () {
                Navigator.pop(c);
                Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => const FixedPage()));
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final caption = fixed.mode == FixedMode.perMonth
        ? '×${faDigits(fixed.timesPerMonth.toString())} ماهانه'
        : 'ثابت';
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: 300 + index * 60),
      curve: Curves.easeOutCubic,
      builder: (context, v, child) => Opacity(
        opacity: v,
        child: Transform.translate(
          offset: Offset(12 * (1 - v), 0),
          child: child,
        ),
      ),
      child: GestureDetector(
        onTap: () => _sheet(context),
        child: Container(
          width: 150,
          padding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: cs.tertiary.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: cs.tertiary.withValues(alpha: 0.35),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Text(
                    caption,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: cs.tertiary,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Icon(Icons.event_repeat,
                      size: 13, color: cs.tertiary),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                fixed.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 12),
              ),
              const SizedBox(height: 2),
              Text(
                moneyFa(fixed.amount),
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: cs.onSurfaceVariant,
                ),
              ),
              InkWell(
                onTap: () => _sheet(context),
                borderRadius: BorderRadius.circular(10),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 1),
                  child: Icon(
                    Icons.more_horiz,
                    size: 16,
                    color: cs.onSurface.withValues(alpha: 0.55),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

String _dayLabel(DateTime d) {  const names = {
    1: 'دوشنبه',
    2: 'سه‌شنبه',
    3: 'چهارشنبه',
    4: 'پنج‌شنبه',
    5: 'جمعه',
    6: 'شنبه',
    7: 'یکشنبه',
  };
  return '${names[d.weekday]} ${solarMd(d)}';
}

class _ThemeSheet extends StatelessWidget {
  const _ThemeSheet();
  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    const options = [
      ('system', 'سیستم', Icons.settings_suggest_outlined),
      ('sand', 'روشن شنی', Icons.wb_sunny_outlined),
      ('ice', 'روشن یخی', Icons.ac_unit_outlined),
      ('night', 'تیره', Icons.dark_mode_outlined),
    ];
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 24),
      child: RadioGroup<String>(
        groupValue: s.themeChoice,
        onChanged: (v) {
          if (v != null) s.setThemeChoice(v);
          Navigator.pop(context);
        },
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final (value, label, icon) in options)
              RadioListTile<String>(
                value: value,
                title: Text(label),
                secondary: Icon(icon),
              ),
          ],
        ),
      ),
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
    final onHero = cs.onPrimary;
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: cs.primary,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            'برآورد برای $month',
            style: TextStyle(color: onHero.withValues(alpha: 0.75)),
          ),
          const SizedBox(height: 6),
          Text(
            'تومان ${moneyFa(fc.total)}',
            style: TextStyle(
              fontSize: 36,
              fontWeight: FontWeight.w800,
              color: onHero,
            ),
          ),
          const SizedBox(height: 14),
          Row(children: [
            _pill(context, 'متغیر ${moneyFa(fc.variable)}'),
            const SizedBox(width: 8),
            _pill(context, 'ثابت ${moneyFa(fc.fixed)}'),
          ]),
        ],
      ),
    );
  }

  Widget _pill(BuildContext context, String t) {
    final cs = Theme.of(context).colorScheme;
    return Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: cs.onPrimary.withValues(alpha: 0.18),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          t,
          style: TextStyle(
            color: cs.onPrimary,
            fontSize: 12,
          ),
        ),
      );
  }
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
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Icon(icon, color: color),
              const SizedBox(height: 12),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                ),
              ),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      );
}
