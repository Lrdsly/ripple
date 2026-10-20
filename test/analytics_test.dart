import 'package:flutter_test/flutter_test.dart';
import 'package:ripple/data/models.dart';
import 'package:ripple/domain/analytics.dart';

void main() {
  group('forecastJalali', () {
    // Mehr 1405 = Sep 23 - Oct 22, 2026 (30 days).
    // Aban 1 1405 = Oct 23, 2026.
    final payments = [
      Payment(DateTime(2026, 9, 24), 100, 'a'),
      Payment(DateTime(2026, 10, 1), 200, 'b'),
      Payment(DateTime(2026, 10, 23), 300, 'c'),
    ];

    test('month boundaries follow solar month', () {
      final fc = Analytics(payments).forecastJalali(1405, 7, []);
      expect(fc.daysInMonth, 30);
      expect(fc.spentSoFar, 300); // 100 + 200, Oct 23 excluded
    });

    test('gregorian october splits the same data', () {
      final fc = Analytics(payments).forecast(2026, 10, []);
      expect(fc.spentSoFar, 500); // 200 + 300, Sep 24 excluded
    });

    test('fixed weekday cost counted over solar range', () {
      // Mondays of Mehr 1405: Sep 28, Oct 5, 12, 19 (4x).
      final fixed = [
        FixedExpense(
          id: '1',
          name: 'x',
          amount: 10,
          mode: FixedMode.weekdays,
          weekdays: [DateTime.monday],
        ),
      ];
      final fc = Analytics(payments).forecastJalali(1405, 7, fixed);
      expect(fc.fixed, 40);
    });

  });

  group('duplicateGroups', () {
    test('same tag and amount on one day warns', () {
      final a = Analytics([
        Payment(DateTime(2026, 9, 27), 20, 'bus', 'bus', ['bus']),
        Payment(DateTime(2026, 9, 27), 20, 'bus', 'bus', ['bus']),
        Payment(DateTime(2026, 9, 27), 45, 'soda', 'soda', ['soda']),
      ]);
      final dups = a.duplicateGroups(DateTime(2026, 9, 27));
      expect(dups, hasLength(1));
      expect(dups.first, hasLength(2));
    });

    test('different amounts do not warn', () {
      final a = Analytics([
        Payment(DateTime(2026, 9, 27), 20, 'bus', 'bus', ['bus']),
        Payment(DateTime(2026, 9, 27), 25, 'bus', 'bus', ['bus']),
      ]);
      expect(a.duplicateGroups(DateTime(2026, 9, 27)), isEmpty);
    });
  });

  group('fixed exclusions', () {
    test('skipped weekdays are not counted', () {
      final f = FixedExpense(
        id: '1',
        name: 'x',
        amount: 10,
        mode: FixedMode.weekdays,
        weekdays: [DateTime.monday],
        skipped: ['2026-9-28'], // a Monday
      );
      // Mehr 1405 Mondays: Sep 28, Oct 5, 12, 19 -> minus 1 skipped.
      final fc = Analytics([]).forecastJalali(1405, 7, [f]);
      expect(fc.fixed, 30);
    });

    test('old stored json without skipped still loads', () {
      final f = FixedExpense.fromJson({
        'id': '1',
        'name': 'x',
        'amount': 10.0,
        'mode': 'weekdays',
        'weekdays': [1],
        'times': 1,
      });
      expect(f.skipped, isEmpty);
      expect(f.costForRange(DateTime(2026, 9, 28), DateTime(2026, 9, 28)),
          10);
    });

    test('appliesOn respects weekdays and skipped days', () {
      final f = FixedExpense(
        id: '1',
        name: 'x',
        amount: 10,
        mode: FixedMode.weekdays,
        weekdays: [DateTime.monday],
        skipped: ['2026-9-28'],
      );
      expect(f.appliesOn(DateTime(2026, 9, 28)), isFalse); // skipped Mon
      expect(f.appliesOn(DateTime(2026, 10, 5)), isTrue); // Monday
      expect(f.appliesOn(DateTime(2026, 10, 6)), isFalse); // Tuesday
      const perMonth = FixedExpense(
        id: '2',
        name: 'y',
        amount: 50,
        mode: FixedMode.perMonth,
        timesPerMonth: 2,
      );
      expect(perMonth.appliesOn(DateTime(2026, 10, 6)), isTrue);
    });
  });
}
