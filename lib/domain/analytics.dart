import '../core/theme.dart';
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
    final avg = avgDaily();
    return Forecast(
      avg,
      avg * days,
      fixed.fold(0.0, (s, f) => s + f.monthlyCost(year, month)),
      _sum(DateTime(year, month, 1), DateTime(year, month, days)),
      days,
    );
  }
}
