import 'dart:io';
import '../models.dart';
import 'payment_source.dart';

/// Reads a folder (recursively) of daily notes named like `2026-09-29.md`.
/// Each payment line:  `- 45000 Lunch #food`   (also `* ` / `- [ ] `)
class MarkdownSource implements PaymentSource {
  final String folder;
  MarkdownSource(this.folder);

  static final _name = RegExp(r'(\d{4})-(\d{2})-(\d{2})');
  static final _line =
      RegExp(r'^\s*[-*+]\s+(?:\[.\]\s*)?(\d[\d,]*(?:\.\d+)?)\s+(.+)$');
  static final _tag = RegExp(r'#([\w\-/]+)');

  @override
  Future<List<Payment>> load() async {
    final out = <Payment>[];
    await for (final e in Directory(folder).list(recursive: true)) {
      if (e is! File || !e.path.endsWith('.md')) continue;
      final m = _name.firstMatch(e.uri.pathSegments.last);
      if (m == null) continue;
      final date = DateTime(
          int.parse(m[1]!), int.parse(m[2]!), int.parse(m[3]!));
      for (final l in await e.readAsLines()) {
        final p = _line.firstMatch(l);
        if (p == null) continue;
        final amount = double.parse(p[1]!.replaceAll(',', ''));
        final rest = p[2]!;
        final cat = _tag.firstMatch(rest)?[1];
        out.add(Payment(date, amount, rest.replaceAll(_tag, '').trim(), cat));
      }
    }
    return out;
  }
}
