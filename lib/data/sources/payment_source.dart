import '../models.dart';

/// Swap implementations (Markdown, demo, REST API, SQLite...) without
/// touching analytics or UI. A future sync API is just another source.
abstract class PaymentSource {
  Future<List<Payment>> load();
}
