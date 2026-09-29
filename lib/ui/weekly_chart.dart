import 'package:flutter/material.dart';
import '../core/theme.dart';
import '../domain/analytics.dart';

const _names = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

class WeeklyChart extends StatelessWidget {
  final List<DayTotal> days;
  const WeeklyChart({super.key, required this.days});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final max = days.fold(0.0, (m, d) => d.total > m ? d.total : m);
    final today = dateOnly(DateTime.now());
    const barArea = 150.0;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        for (final d in days)
          Expanded(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              SizedBox(
                height: barArea,
                child: Align(
                  alignment: Alignment.bottomCenter,
                  child: TweenAnimationBuilder<double>(
                    key: ValueKey('${d.date}-${d.total}'),
                    tween: Tween(begin: 0, end: max == 0 ? 0 : d.total / max),
                    duration: const Duration(milliseconds: 650),
                    curve: Curves.easeOutCubic,
                    builder: (context, v, child) => Container(
                      width: 22,
                      height: 6 + (barArea - 6) * v,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        gradient: LinearGradient(
                          begin: Alignment.bottomCenter,
                          end: Alignment.topCenter,
                          colors: d.date == today
                              ? [cs.primary, cs.tertiary]
                              : [cs.primary.withValues(alpha: .35), cs.primary.withValues(alpha: .75)],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Text(_names[d.date.weekday - 1],
                  style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: d.date == today ? cs.primary : null)),
              const SizedBox(height: 2),
              FittedBox(
                child: Text(d.total == 0 ? '–' : money(d.total),
                    style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant)),
              ),
            ]),
          ),
      ],
    );
  }
}
