import 'package:flutter/material.dart';
import '../core/theme.dart';
import '../domain/analytics.dart';

// DateTime.weekday: Mon=1..Sun=7
const _names = {
  1: 'دوشنبه',
  2: 'سه‌شنبه',
  3: 'چهارشنبه',
  4: 'پنج‌شنبه',
  5: 'جمعه',
  6: 'شنبه',
  7: 'یکشنبه',
};

class WeeklyChart extends StatelessWidget {
  final List<DayTotal> days;
  final DateTime? selected;
  final ValueChanged<DateTime>? onSelect;
  const WeeklyChart({super.key, required this.days, this.selected, this.onSelect});

  @override
  Widget build(BuildContext context) {
    final max = days.fold(0.0, (m, d) => d.total > m ? d.total : m);
    final today = dateOnly(DateTime.now());
    const barArea = 150.0;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        for (var i = 0; i < days.length; i++)
          Expanded(
            child: _Bar(
              date: days[i].date,
              ratio: max == 0 ? 0 : days[i].total / max,
              total: days[i].total,
              isToday: days[i].date == today,
              isSelected: selected != null &&
                  dateOnly(selected!) == days[i].date,
              // Staggered entrance: later bars take slightly longer,
              // feels like a wave instead of one solid block.
              duration: Duration(milliseconds: 550 + i * 70),
              barArea: barArea,
              onTap: onSelect == null ? null : () => onSelect!(days[i].date),
            ),
          ),
      ],
    );
  }
}

class _Bar extends StatelessWidget {
  final DateTime date;
  final double ratio;
  final double total;
  final bool isToday;
  final bool isSelected;
  final Duration duration;
  final double barArea;
  final VoidCallback? onTap;
  const _Bar({
    required this.date,
    required this.ratio,
    required this.total,
    required this.isToday,
    required this.isSelected,
    required this.duration,
    required this.barArea,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        SizedBox(
          height: barArea,
          child: Align(
            alignment: Alignment.bottomCenter,
            // Keyed by date only (not total) so week/data changes
            // tween smoothly instead of restarting from zero.
            child: TweenAnimationBuilder<double>(
              key: ValueKey(date),
              tween: Tween(begin: 0, end: ratio),
              duration: duration,
              curve: Curves.easeOutCubic,
              builder: (context, v, child) => AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                curve: Curves.easeOut,
                width: isSelected ? 28 : 22,
                height: 6 + (barArea - 6) * v,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(7),
                  color: isSelected
                      ? cs.secondary
                      : isToday
                          ? cs.secondary.withValues(alpha: 0.85)
                          : cs.primary.withValues(alpha: 0.55),
                  border: isSelected
                      ? Border.all(
                          color:
                              cs.onSurface.withValues(alpha: 0.4),
                          width: 1.5,
                        )
                      : null,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          _names[date.weekday]!,
          style: TextStyle(
            fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
            color: isToday ? cs.secondary : null,
          ),
        ),
        const SizedBox(height: 2),
        FittedBox(
          child: Text(
            total == 0 ? '–' : moneyFa(total),
            style: TextStyle(
              fontSize: 11,
              color: cs.onSurfaceVariant,
            ),
          ),
        ),
      ]),
    );
  }
}
