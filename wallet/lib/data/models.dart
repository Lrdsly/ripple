class Payment {
  final DateTime date; // date only
  final double amount;
  final String title;
  final String? category;
  const Payment(this.date, this.amount, this.title, [this.category]);
}

enum FixedMode { weekdays, perMonth }

/// A recurring amount: either on chosen weekdays, or N times per month.
class FixedExpense {
  final String id, name;
  final double amount;
  final FixedMode mode;
  final List<int> weekdays; // DateTime.monday..sunday
  final int timesPerMonth;
  const FixedExpense({
    required this.id,
    required this.name,
    required this.amount,
    required this.mode,
    this.weekdays = const [],
    this.timesPerMonth = 1,
  });

  int occurrences(int year, int month) {
    if (mode == FixedMode.perMonth) return timesPerMonth;
    final days = DateTime(year, month + 1, 0).day;
    return List.generate(days, (i) => DateTime(year, month, i + 1).weekday)
        .where(weekdays.contains)
        .length;
  }

  double monthlyCost(int y, int m) => amount * occurrences(y, m);

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'amount': amount,
        'mode': mode.name,
        'weekdays': weekdays,
        'times': timesPerMonth,
      };

  factory FixedExpense.fromJson(Map<String, dynamic> j) => FixedExpense(
        id: j['id'],
        name: j['name'],
        amount: (j['amount'] as num).toDouble(),
        mode: FixedMode.values.byName(j['mode']),
        weekdays: List<int>.from(j['weekdays']),
        timesPerMonth: j['times'],
      );
}
