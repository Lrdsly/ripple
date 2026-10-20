import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shamsi_date/shamsi_date.dart';
import '../app_state.dart';
import '../core/theme.dart';
import '../data/models.dart';

const _short = ['ش', 'ی', 'د', 'س', 'چ', 'پ', 'ج'];

/// Solar month range containing [ref], as Gregorian date-only bounds.
(DateTime, DateTime) _solarMonthRange(DateTime ref) {
  final j = Jalali.fromDateTime(ref);
  final gs = Jalali(j.year, j.month, 1).toGregorian();
  final ge = Jalali(j.year, j.month, Jalali(j.year, j.month).monthLength)
      .toGregorian();
  return (
    DateTime(gs.year, gs.month, gs.day),
    DateTime(ge.year, ge.month, ge.day)
  );
}

class FixedPage extends StatelessWidget {
  const FixedPage({super.key});
  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    final (ms, me) = _solarMonthRange(DateTime.now());
    return Scaffold(
      appBar: AppBar(title: const Text('هزینه‌های ثابت')),
      floatingActionButton: FloatingActionButton.extended(
        icon: const Icon(Icons.add),
        label: const Text('اضافه کردن'),
        onPressed: () => showModalBottomSheet(
            context: context,
            isScrollControlled: true,
            builder: (_) => const _EditSheet()),
      ),
      body: s.fixed.isEmpty
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.event_repeat_outlined,
                      size: 56,
                      color: Theme.of(context)
                          .colorScheme
                          .onSurfaceVariant),
                  const SizedBox(height: 12),
                  const Text('هنوز هزینه ثابت‌ای تعریف نشده'),
                ],
              ),
            )
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                for (final f in s.fixed)
                  Dismissible(
                    key: ValueKey(f.id),
                    onDismissed: (_) => s.removeFixed(f.id),
                    background:
                        Container(color: Colors.red.withValues(alpha: .4)),
                    child: Card(
                      child: ListTile(
                        title: Text(f.name),
                        subtitle: Text([
                          f.mode == FixedMode.perMonth
                              ? '${f.timesPerMonth}× در ماه'
                              : f.weekdays
                                  .map((d) => _short[d - 1])
                                  .join(' '),
                          if (f.skipped.isNotEmpty)
                            '${faDigits(f.skipped.length.toString())} روز مستثنا',
                        ].join(' · ')),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              moneyFa(f.costForRange(ms, me)),
                              style: const TextStyle(
                                  fontWeight: FontWeight.w700),
                            ),
                            IconButton(
                              icon: const Icon(Icons.edit_outlined),
                              tooltip: 'ویرایش',
                              onPressed: () => showModalBottomSheet(
                                  context: context,
                                  isScrollControlled: true,
                                  builder: (_) =>
                                      _EditSheet(existing: f)),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
            ),
    );
  }
}

class _EditSheet extends StatefulWidget {
  final FixedExpense? existing;
  const _EditSheet({this.existing});
  @override
  State<_EditSheet> createState() => _EditSheetState();
}

class _EditSheetState extends State<_EditSheet> {
  late final TextEditingController name;
  late final TextEditingController amount;
  late FixedMode mode;
  late Set<int> days;
  late int times;
  late List<String> skipped;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    name = TextEditingController(text: e?.name ?? '');
    amount = TextEditingController(
        text: e == null ? '' : e.amount.toStringAsFixed(0));
    mode = e?.mode ?? FixedMode.weekdays;
    days = {...(e?.weekdays ?? [])};
    times = e?.timesPerMonth ?? 1;
    skipped = [...(e?.skipped ?? [])];
  }

  @override
  void dispose() {
    name.dispose();
    amount.dispose();
    super.dispose();
  }

  Future<void> _pickSkipDay() async {
    final picked = await showDialog<DateTime>(
      context: context,
      builder: (_) => const _SolarDayPicker(),
    );
    if (picked == null) return;
    final key = FixedExpense.dayKey(picked);
    if (!skipped.contains(key)) setState(() => skipped.add(key));
  }

  @override
  Widget build(BuildContext context) => Padding(
        padding: EdgeInsets.fromLTRB(
            20, 20, 20, 20 + MediaQuery.of(context).viewInsets.bottom),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: name,
              decoration: const InputDecoration(labelText: 'نام'),
              textDirection: TextDirection.rtl,
            ),
            TextField(
              controller: amount,
              keyboardType: TextInputType.number,
              decoration:
                  const InputDecoration(labelText: 'مبلغ هر بار'),
              textDirection: TextDirection.rtl,
            ),
            const SizedBox(height: 16),
            SegmentedButton<FixedMode>(
              segments: const [
                ButtonSegment(
                    value: FixedMode.weekdays,
                    label: Text('روزهای کاری',
                        textDirection: TextDirection.rtl)),
                ButtonSegment(
                    value: FixedMode.perMonth,
                    label: Text('در ماه',
                        textDirection: TextDirection.rtl)),
              ],
              selected: {mode},
              onSelectionChanged: (v) =>
                  setState(() => mode = v.first),
            ),
            const SizedBox(height: 12),
            if (mode == FixedMode.weekdays)
              Wrap(
                  spacing: 6,
                  children: [
                    for (var d = 1; d <= 7; d++)
                      FilterChip(
                        label: Text(_short[d - 1]),
                        selected: days.contains(d),
                        onSelected: (v) => setState(() {
                          if (v) {
                            days.add(d);
                          } else {
                            days.remove(d);
                          }
                        }),
                      ),
                  ])
            else
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconButton(
                    icon: const Icon(Icons.add),
                    onPressed: () =>
                        setState(() => times = (times + 1).clamp(1, 31)),
                  ),
                  Text('${faDigits(times.toString())} روز در ماه',
                      style: const TextStyle(fontSize: 16)),
                  IconButton(
                    icon: const Icon(Icons.remove),
                    onPressed: () =>
                        setState(() => times = (times - 1).clamp(1, 31)),
                  ),
                ],
              ),
            const SizedBox(height: 12),
            Row(
              children: [
                const Text('روزهای مستثنا'),
                const Spacer(),
                TextButton.icon(
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('افزودن روز'),
                  onPressed: _pickSkipDay,
                ),
              ],
            ),
            if (skipped.isEmpty)
              const Align(
                alignment: Alignment.centerRight,
                child: Text('همه روزها حساب می‌شوند',
                    style: TextStyle(fontSize: 12)),
              )
            else
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final k in skipped)
                    () {
                      final parts = k.split('-').map(int.parse).toList();
                      final d = DateTime(parts[0], parts[1], parts[2]);
                      return InputChip(
                        label: Text(solarMd(d)),
                        onDeleted: () =>
                            setState(() => skipped.remove(k)),
                      );
                    }(),
                ],
              ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: () {
                final amt = double.tryParse(
                    amount.text.replaceAll(',', ''));
                if (name.text.isEmpty || amt == null) return;
                final st = context.read<AppState>();
                if (widget.existing == null) {
                  st.addFixed(FixedExpense(
                    id: DateTime.now()
                        .microsecondsSinceEpoch
                        .toString(),
                    name: name.text,
                    amount: amt,
                    mode: mode,
                    weekdays: days.toList()..sort(),
                    timesPerMonth: times,
                    skipped: skipped,
                  ));
                } else {
                  st.updateFixed(widget.existing!.copyWith(
                    name: name.text,
                    amount: amt,
                    mode: mode,
                    weekdays: days.toList()..sort(),
                    timesPerMonth: times,
                    skipped: skipped,
                  ));
                }
                Navigator.pop(context);
              },
              child:
                  Text(widget.existing == null ? 'ذخیره' : 'به‌روزرسانی'),
            ),
          ],
        ),
      );
}

/// Solar (Jalali) day picker returning a Gregorian date-only value.
/// Everything the user sees — year, month name, day — is solar.
class _SolarDayPicker extends StatefulWidget {
  const _SolarDayPicker();
  @override
  State<_SolarDayPicker> createState() => _SolarDayPickerState();
}

class _SolarDayPickerState extends State<_SolarDayPicker> {
  static List<String> get _monthNames =>
      List.generate(12, (i) => Jalali(1400, i + 1).formatter.mN);
  late int jy;
  late int jm;
  late int jd;

  @override
  void initState() {
    super.initState();
    final now = Jalali.now();
    jy = now.year;
    jm = now.month;
    jd = now.day;
  }

  @override
  Widget build(BuildContext context) {
    final maxDay = Jalali(jy, jm).monthLength;
    if (jd > maxDay) jd = maxDay;
    return AlertDialog(
      title: const Text('انتخاب روز مستثنا'),
      content: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          DropdownButton<int>(
            value: jd,
            items: [
              for (var d = 1; d <= maxDay; d++)
                DropdownMenuItem(
                  value: d,
                  child: Text(faDigits(d.toString())),
                ),
            ],
            onChanged: (v) => setState(() => jd = v!),
          ),
          DropdownButton<int>(
            value: jm,
            items: [
              for (var m = 1; m <= 12; m++)
                DropdownMenuItem(
                  value: m,
                  child: Text(_monthNames[m - 1]),
                ),
            ],
            onChanged: (v) => setState(() => jm = v!),
          ),
          DropdownButton<int>(
            value: jy,
            items: [
              for (var y = jy - 5; y <= jy + 2; y++)
                DropdownMenuItem(
                  value: y,
                  child: Text(faDigits(y.toString())),
                ),
            ],
            onChanged: (v) => setState(() {
              jy = v!;
              jd = jd.clamp(1, Jalali(jy, jm).monthLength);
            }),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('لغو'),
        ),
        FilledButton(
          onPressed: () {
            final g = Jalali(jy, jm, jd).toGregorian();
            Navigator.pop(
                context, DateTime(g.year, g.month, g.day));
          },
          child: const Text('تأیید'),
        ),
      ],
    );
  }
}
