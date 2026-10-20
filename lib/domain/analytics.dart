import '../core/theme.dart';
import 'package:shamsi_date/shamsi_date.dart';
import '../data/models.dart';

class DayTotal {
  final DateTime date;
  final double total;
  const DayTotal(this.date, this.total);
}

class Forecast {
  final double avgDaily, variable, fixed, spentSoFar;
  final int daysInMonth;
  const Forecast(this.avgDaily, this.variable, this.fixed, this.spentSoFar,
      this.daysInMonth);
  double get total => variable + fixed;
}

DateTime dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

/// Pure functions over a payment list: easy to test, reuse on desktop/API.
class Analytics {
  final List<Payment> payments;
  Analytics(this.payments);

  double _sum(DateTime from, DateTime to) => payments
      .where((p) => !p.date.isBefore(from) && !p.date.isAfter(to))
      .fold(0.0, (s, p) => s + p.amount);

  DateTime weekStart(DateTime ref) {
    final d = dateOnly(ref);
    return d.subtract(Duration(days: (d.weekday - kWeekStart + 7) % 7));
  }

  List<DayTotal> week(DateTime start) => List.generate(7, (i) {
        final d = DateTime(start.year, start.month, start.day + i);
        return DayTotal(d, _sum(d, d));
      });

  /// All payments on one calendar day (date part only).
  List<Payment> dayPayments(DateTime day) {
    final d = dateOnly(day);
    return payments.where((p) => dateOnly(p.date) == d).toList()
      ..sort((a, b) => b.amount.compareTo(a.amount));
  }

  /// Payments on [day] that look like double entries: same amount plus
  /// same tag (or same title when untagged), written more than once.
  /// Only groups of 2+ are returned. Data is still fully counted —
  /// callers should warn, not drop.
  List<List<Payment>> duplicateGroups(DateTime day) {
    final groups = <String, List<Payment>>{};
    for (final p in dayPayments(day)) {
      final key = p.allTags.isEmpty
          ? '${p.amount}|${p.title}'
          : '${p.amount}|#${p.allTags.first}';
      (groups[key] ??= []).add(p);
    }
    return groups.values.where((g) => g.length > 1).toList()
      ..sort((a, b) => b.length.compareTo(a.length));
  }

  /// Tag -> total for one day. Untagged payments go under ''.
  Map<String, double> dayTagTotals(DateTime day) {
    final totals = <String, double>{};
    for (final p in dayPayments(day)) {
      final tags = p.allTags;
      if (tags.isEmpty) {
        totals[''] = (totals[''] ?? 0) + p.amount;
      } else {
        for (final t in tags) {
          totals[t] = (totals[t] ?? 0) + p.amount;
        }
      }
    }
    return totals;
  }

  /// Average spend per calendar day over the last [window] days
  /// (shorter if your history is shorter).
  double avgDaily({int window = 90, DateTime? now}) {
    if (payments.isEmpty) return 0;
    final today = dateOnly(now ?? DateTime.now());
    final first =
        payments.map((p) => p.date).reduce((a, b) => a.isBefore(b) ? a : b);
    var from = today.subtract(Duration(days: window - 1));
    if (first.isAfter(from)) from = first;
    final days = today.difference(from).inDays + 1;
    return _sum(from, today) / days;
  }

  Forecast forecast(int year, int month, List<FixedExpense> fixed) {
    final days = DateTime(year, month + 1, 0).day;
    return forecastRange(
        DateTime(year, month, 1), DateTime(year, month, days), fixed);
  }

  /// Solar-month forecast: [jy]/[jm] is a Jalali month (e.g. Mehr 1405).
  /// Month length and spent-so-far follow the solar calendar, so a month
  /// of daily notes is never split across two Gregorian months.
  Forecast forecastJalali(int jy, int jm, List<FixedExpense> fixed) {
    final days = Jalali(jy, jm).monthLength;
    final gs = Jalali(jy, jm, 1).toGregorian();
    final ge = Jalali(jy, jm, days).toGregorian();
    return forecastRange(
        DateTime(gs.year, gs.month, gs.day),
        DateTime(ge.year, ge.month, ge.day),
        fixed);
  }

  Forecast forecastRange(
      DateTime from, DateTime to, List<FixedExpense> fixed) {
    final days = dateOnly(to).difference(dateOnly(from)).inDays + 1;
    final avg = avgDaily();
    return Forecast(
      avg,
      avg * days,
      fixed.fold(0.0, (s, f) => s + f.costForRange(from, to)),
      _sum(dateOnly(from), dateOnly(to)),
      days,
    );
  }
}
