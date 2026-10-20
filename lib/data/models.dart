class Payment {
  final DateTime date; // date only
  final double amount;
  final String title;
  final String? category;
  final List<String> tags;
  const Payment(this.date, this.amount, this.title,
      [this.category, this.tags = const []]);

  /// All tags: prefers [tags], falls back to [category] for old data.
  List<String> get allTags =>
      tags.isNotEmpty ? tags : (category != null ? [category!] : []);
}

/// One payment removed through the app, kept in the vault's hidden log
/// (`.ripple_removed.json`) so it can be repaired (restored) later.
class RemovedPayment {
  final DateTime date;
  final String title;
  final double amount;
  final List<String> tags;
  final String file; // vault-relative source file name
  final DateTime removedAt;
  /// The original line exactly as it was in the file, so a restore
  /// reproduces it byte-for-byte instead of a reconstructed variant.
  final String raw;
  const RemovedPayment({
    required this.date,
    required this.title,
    required this.amount,
    required this.tags,
    required this.file,
    required this.removedAt,
    this.raw = '',
  });

  Map<String, dynamic> toJson() => {
        'date': '${date.year}-${date.month}-${date.day}',
        'title': title,
        'amount': amount,
        'tags': tags,
        'file': file,
        'removedAt': removedAt.toIso8601String(),
        'raw': raw,
      };

  factory RemovedPayment.fromJson(Map<String, dynamic> j) {
    final dp = (j['date'] as String).split('-').map(int.parse).toList();
    return RemovedPayment(
      date: DateTime(dp[0], dp[1], dp[2]),
      title: j['title'] as String,
      amount: (j['amount'] as num).toDouble(),
      tags: ((j['tags'] as List?) ?? []).map((e) => e.toString()).toList(),
      file: j['file'] as String,
      removedAt: DateTime.parse(j['removedAt'] as String),
      raw: (j['raw'] as String?) ?? '',
    );
  }
}

/// Thrown when the vault could not be modified (permissions, read-only
/// file, disk error). The vault is left untouched in that case.
class VaultWriteException implements Exception {
  final String message;
  const VaultWriteException(this.message);
  @override
  String toString() => message;
}

enum FixedMode { weekdays, perMonth }

/// A recurring amount: either on chosen weekdays, or N times per month.
class FixedExpense {
  final String id, name;
  final double amount;
  final FixedMode mode;
  final List<int> weekdays; // DateTime.monday..sunday
  final int timesPerMonth;
  /// Excluded calendar days as `yyyy-m-d` (Gregorian date part).
  /// A fixed cost that didn't happen on those days is not counted.
  final List<String> skipped;
  const FixedExpense({
    required this.id,
    required this.name,
    required this.amount,
    required this.mode,
    this.weekdays = const [],
    this.timesPerMonth = 1,
    this.skipped = const [],
  });

  static String dayKey(DateTime d) => '${d.year}-${d.month}-${d.day}';
  bool isSkipped(DateTime d) => skipped.contains(dayKey(d));

  /// Whether this fixed cost applies on [day] (shown in the day strip).
  /// Weekday-mode: matching weekday and not skipped. Per-month mode has
  /// no fixed days, so it shows every day with a monthly badge.
  bool appliesOn(DateTime day) {
    final d = DateTime(day.year, day.month, day.day);
    if (isSkipped(d)) return false;
    if (mode == FixedMode.perMonth) return true;
    return weekdays.contains(d.weekday);
  }

  FixedExpense copyWith({
    String? name,
    double? amount,
    FixedMode? mode,
    List<int>? weekdays,
    int? timesPerMonth,
    List<String>? skipped,
  }) =>
      FixedExpense(
        id: id,
        name: name ?? this.name,
        amount: amount ?? this.amount,
        mode: mode ?? this.mode,
        weekdays: weekdays ?? this.weekdays,
        timesPerMonth: timesPerMonth ?? this.timesPerMonth,
        skipped: skipped ?? this.skipped,
      );

  int occurrences(int year, int month) {
    if (mode == FixedMode.perMonth) return timesPerMonth;
    final days = DateTime(year, month + 1, 0).day;
    return List.generate(days, (i) => DateTime(year, month, i + 1).weekday)
        .where(weekdays.contains)
        .length;
  }

  double monthlyCost(int y, int m) => costForRange(
      DateTime(y, m, 1), DateTime(y, m, DateTime(y, m + 1, 0).day));

  /// Fixed cost over an explicit date range (used for Jalali months).
  /// Days listed in [skipped] are not counted.
  double costForRange(DateTime from, DateTime to) {
    final end = DateTime(to.year, to.month, to.day);
    if (mode == FixedMode.perMonth) {
      var n = timesPerMonth;
      var d = DateTime(from.year, from.month, from.day);
      while (!d.isAfter(end)) {
        if (isSkipped(d)) n--;
        d = d.add(const Duration(days: 1));
      }
      return amount * (n < 0 ? 0 : n);
    }
    var n = 0;
    var d = DateTime(from.year, from.month, from.day);
    while (!d.isAfter(end)) {
      if (weekdays.contains(d.weekday) && !isSkipped(d)) n++;
      d = d.add(const Duration(days: 1));
    }
    return amount * n;
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'amount': amount,
        'mode': mode.name,
        'weekdays': weekdays,
        'times': timesPerMonth,
        'skipped': skipped,
      };

  factory FixedExpense.fromJson(Map<String, dynamic> j) => FixedExpense(
        id: j['id'],
        name: j['name'],
        amount: (j['amount'] as num).toDouble(),
        mode: FixedMode.values.byName(j['mode']),
        weekdays: List<int>.from(j['weekdays']),
        timesPerMonth: j['times'],
        skipped: ((j['skipped'] as List?) ?? [])
            .map((e) => e.toString())
            .toList(),
      );
}
