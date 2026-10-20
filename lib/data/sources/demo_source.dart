import 'dart:math';
import '../models.dart';
import 'payment_source.dart';

class DemoSource implements PaymentSource {
  @override
  Future<List<Payment>> load() async {
    final r = Random(7);
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    const items = [
      ('Lunch', 'food'),
      ('Taxi', 'transport'),
      ('Coffee', 'cafe'),
      ('Groceries', 'groceries'),
      ('Snack', 'food'),
    ];
    final out = <Payment>[];
    for (var i = 0; i < 75; i++) {
      final d = today.subtract(Duration(days: i));
      for (var k = 0; k < r.nextInt(4); k++) {
        final item = items[r.nextInt(items.length)];
        out.add(Payment(d, (50 + r.nextInt(450)) * 1000.0, item.$1,
            item.$2, [item.$2]));
      }
    }
    return out;
  }
}
