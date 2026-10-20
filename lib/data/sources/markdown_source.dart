import 'dart:convert';
import 'dart:io';
import 'package:shamsi_date/shamsi_date.dart';
import '../models.dart';
import 'payment_source.dart';

/// Reads a folder (recursively) of daily notes.
///
/// Filenames — tried in order, never skipped:
/// Gregorian `2026-09-29.md`, Jalali `1404-07-05.md` (years 1300-1600 are
/// converted to Gregorian), short year `405-07-02.md` (= 1405),
/// `YYYY_MM_DD`, `YYYYMMDD`, `DD-MM-YYYY`. Files with no recognizable date
/// fall back to the file's modification date.
///
/// Lines — bullet optional, tags optional:
/// `- 45000 Lunch #food`, `20 رفت و برگشت خوابگاه`, `276 نودل #غذا`.
/// Persian/Arabic digits, `٬`/`،`/`,` separators and `/` decimals
/// (`475/5` = 475.5) are supported. Separators (`___`) and bare totals
/// (`550` with no title) are skipped, but the file itself never is.
class MarkdownSource implements PaymentSource {
  final String folder;
  MarkdownSource(this.folder);

  static final _tag = RegExp(r'#([^\s#]+)');
  static final _dirMarks = RegExp('[\u200E\u200F\u202A-\u202E\u2066-\u2069]');
  static final _sepOnly = RegExp(r'^[\s\-_*#>`~|/\\]+$');
  static final _bareDate = RegExp(r'^\d{2,4}[-_./]\d{1,2}[-_./]\d{1,2}$');
  static final _delimited =
      RegExp(r'(\d{2,4})[-_.](\d{1,2})[-_.](\d{1,2})');
  static final _amountLine = RegExp(
      r'^([0-9\u06F0-\u06F9\u0660-\u0669][0-9\u06F0-\u06F9\u0660-\u0669,٬،\s./٫]*?)\s+(.+)$');

  @override
  Future<List<Payment>> load() async {
    final out = <Payment>[];
    final dir = Directory(folder);
    if (!await dir.exists()) return out;
    await for (final e in dir.list(recursive: true, followLinks: false)) {
      if (e is! File || !e.path.toLowerCase().endsWith('.md')) continue;
      try {
        final date = await _dateForFile(e);
        late final List<String> lines;
        try {
          lines = await e.readAsLines();
        } catch (_) {
          continue; // unreadable file: keep going, never crash the load
        }
        for (final l in lines) {
          final p = parseLine(l, date);
          if (p != null) out.add(p);
        }
      } catch (_) {
        // One bad file must never break the whole load.
      }
    }
    return out;
  }

  // -- removal + hidden restore log ----------------------------------------

  /// Name of the hidden restore log in the vault root.
  static const removedLogName = '.ripple_removed.json';

  /// Removes the first line matching [date]/[amount]/[title]/[tags] from
  /// its daily file and records it in the hidden log (with removal time)
  /// so it can be repaired later. Returns the record, or null if nothing
  /// matched (files untouched).
  Future<RemovedPayment?> removeOne({
    required DateTime date,
    required double amount,
    required String title,
    required List<String> tags,
  }) async {
    final target = DateTime(date.year, date.month, date.day);
    final dir = Directory(folder);
    if (!await dir.exists()) return null;
    await for (final e in dir.list(recursive: true, followLinks: false)) {
      if (e is! File ||
          !e.path.toLowerCase().endsWith('.md') ||
          _isHidden(e)) {
        continue;
      }
      late final DateTime fd;
      late final String content;
      try {
        fd = await _dateForFile(e);
        if (fd != target) continue;
        content = await e.readAsString();
      } catch (_) {
        continue;
      }
      final lines = content.split('\n');
      for (var i = 0; i < lines.length; i++) {
        final p = parseLine(lines[i], fd);
        if (p == null ||
            p.amount != amount ||
            p.title != title ||
            !_sameTags(p.allTags, tags)) {
          continue;
        }
        final rec = RemovedPayment(
          date: target,
          title: title,
          amount: amount,
          tags: tags,
          file: e.uri.pathSegments.last,
          removedAt: DateTime.now(),
          raw: lines[i],
        );
        // Log first: if the file write fails, the log entry is rolled
        // back, so the line is never lost without a restore record.
        await _appendRemoved(rec);
        try {
          lines.removeAt(i);
          final out = lines.join('\n');
          await e.writeAsString(
              content.endsWith('\n') ? '$out\n' : out);
        } catch (err) {
          await _dropRemoved(rec);
          throw VaultWriteException(
              'نوشتن در فایل ممکن نشد: ${err.toString()}');
        }
        return rec;
      }
    }
    return null;
  }

  /// Repairs a previous removal: re-appends the line to its source file
  /// (or recreates it) and drops the record from the hidden log.
  /// The original line text is reused verbatim when available.
  Future<void> restore(RemovedPayment rec) async {
    final f = File('$folder/${rec.file}');
    final line = rec.raw.isNotEmpty
        ? rec.raw
        : _rebuildLine(rec);
    try {
      if (await f.exists()) {
        final content = await f.readAsString();
        await f.writeAsString(content.endsWith('\n')
            ? '$content$line\n'
            : '$content\n$line\n');
      } else {
        await f.writeAsString('$line\n');
      }
    } catch (err) {
      throw VaultWriteException(
          'بازیابی ممکن نشد: ${err.toString()}');
    }
    final log = await _readRemoved();
    log.removeWhere((r) =>
        r.file == rec.file &&
        r.title == rec.title &&
        r.amount == rec.amount &&
        r.removedAt.toIso8601String() ==
            rec.removedAt.toIso8601String());
    await _writeRemoved(log);
  }

  static String _rebuildLine(RemovedPayment rec) {
    final amt = rec.amount == rec.amount.roundToDouble()
        ? rec.amount.toInt().toString()
        : rec.amount.toString();
    final tagSuffix =
        rec.tags.isEmpty ? '' : ' ${rec.tags.map((t) => '#$t').join(' ')}';
    return '- $amt ${rec.title}$tagSuffix';
  }

  /// All records currently in the hidden log (for future repair UI).
  Future<List<RemovedPayment>> removedLog() => _readRemoved();

  /// Records removed between [mDaysAgo] and [nDaysAgo] days ago
  /// (order-independent). Powers the "restore m..n days ago" screen.
  static List<RemovedPayment> removedBetween(
    List<RemovedPayment> log,
    int mDaysAgo,
    int nDaysAgo, {
    DateTime? now,
  }) {
    var m = mDaysAgo;
    var n = nDaysAgo;
    if (m > n) {
      final t = m;
      m = n;
      n = t;
    }
    final ref = now ?? DateTime.now();
    final today = DateTime(ref.year, ref.month, ref.day);
    final from = today.subtract(Duration(days: n));
    final to = today.subtract(Duration(days: m));
    return log.where((r) {
      final d = DateTime(
          r.removedAt.year, r.removedAt.month, r.removedAt.day);
      return !d.isBefore(from) && !d.isAfter(to);
    }).toList();
  }

  static bool _sameTags(List<String> a, List<String> b) {
    if (a.length != b.length) return false;
    final sa = {...a};
    return sa.length == a.length && sa.containsAll(b);
  }

  static bool _isHidden(FileSystemEntity e) =>
      e.uri.pathSegments.any((s) => s.startsWith('.'));

  File get _logFile => File('$folder/$removedLogName');

  Future<List<RemovedPayment>> _readRemoved() async {
    try {
      final f = _logFile;
      if (!await f.exists()) return [];
      final raw = await f.readAsString();
      if (raw.trim().isEmpty) return [];
      final decoded = jsonDecode(raw);
      if (decoded is! List) return [];
      return decoded
          .whereType<Map<String, dynamic>>()
          .map(RemovedPayment.fromJson)
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> _writeRemoved(List<RemovedPayment> log) async {
    await _logFile.writeAsString(
        jsonEncode(log.map((r) => r.toJson()).toList()));
  }

  Future<void> _appendRemoved(RemovedPayment rec) async {
    final log = await _readRemoved();
    log.add(rec);
    await _writeRemoved(log);
  }

  /// Removes a log entry again (rollback when the file write failed).
  Future<void> _dropRemoved(RemovedPayment rec) async {
    try {
      final log = await _readRemoved();
      log.removeWhere((r) =>
          r.removedAt.toIso8601String() ==
          rec.removedAt.toIso8601String());
      await _writeRemoved(log);
    } catch (_) {
      // Nothing else to do: the original file is still intact.
    }
  }

  // -- dates ---------------------------------------------------------------

  static Future<DateTime> _dateForFile(File f) async {
    final name = f.uri.pathSegments.last;
    var d = resolveDate(name);
    if (d != null) return d;
    // Sniff the first lines for a date (e.g. a `# 1404-07-05` heading).
    try {
      final lines = await f.readAsLines();
      for (final l in lines.take(5)) {
        d = resolveDate(l);
        if (d != null) return d;
      }
    } catch (_) {}
    // Last resort: file modification date. The file is still kept.
    try {
      final s = await f.stat();
      return DateTime(s.modified.year, s.modified.month, s.modified.day);
    } catch (_) {
      final now = DateTime.now();
      return DateTime(now.year, now.month, now.day);
    }
  }

  /// Returns the calendar day for a filename (or any string containing a
  /// date), or null when nothing recognizable is found.
  static DateTime? resolveDate(String input, {DateTime? fallback}) {
    var m = _delimited.firstMatch(input);
    if (m != null) {
      final aRaw = m[1]!, bRaw = m[2]!, cRaw = m[3]!;
      final a = int.parse(_enDigits(aRaw));
      final b = int.parse(_enDigits(bRaw));
      final c = int.parse(_enDigits(cRaw));
      // Year-first: `YYYY-MM-DD` (also short `405-07-02`, `05-07-03`).
      if (aRaw.length >= 2 && _isYearLike(aRaw.length, a)) {
        final d = _toGregorian(_normYear(aRaw.length, a), b, c);
        if (d != null) return d;
      }
      // Day-first: `DD-MM-YYYY`.
      if (_isYearLike(cRaw.length, c)) {
        final d = _toGregorian(_normYear(cRaw.length, c), b, a);
        if (d != null) return d;
      }
    }
    // Compact `YYYYMMDD`.
    final digits = _enDigits(input.split('.').first).replaceAll(RegExp(r'\D'), '');
    if (digits.length == 8) {
      final d = _toGregorian(
        int.parse(digits.substring(0, 4)),
        int.parse(digits.substring(4, 6)),
        int.parse(digits.substring(6, 8)),
      );
      if (d != null) return d;
    }
    return fallback;
  }

  static bool _isYearLike(int len, int v) {
    if (len == 4) return (v >= 1200 && v <= 1600) || (v >= 1800 && v <= 2200);
    return true; // 2-3 digit years are normalized (assumed Jalali)
  }

  static int _normYear(int len, int v) {
    if (len == 4) return v;
    if (len == 3) return v + 1000; // 405 -> 1405
    return v <= 60 ? 1400 + v : 1300 + v; // 05 -> 1405
  }

  static DateTime? _toGregorian(int year, int month, int day) {
    if (month < 1 || month > 12 || day < 1) return null;
    if (year >= 1300 && year <= 1600) {
      try {
        final g = Jalali(year, month, day).toGregorian();
        return DateTime(g.year, g.month, g.day);
      } on DateException {
        return null; // e.g. Esfand 30 in a non-leap year
      }
    }
    if (year >= 1800 && year <= 2200) {
      if (day > DateTime(year, month + 1, 0).day) return null;
      return DateTime(year, month, day);
    }
    return null;
  }

  // -- lines ---------------------------------------------------------------

  /// Parses one payment line, or null when the line carries no payment
  /// (blank, separator, heading, bare total). Never throws.
  static Payment? parseLine(String raw, DateTime date) {
    try {
      var line = raw.replaceAll(_dirMarks, '').trim();
      if (line.isEmpty || _sepOnly.hasMatch(line)) return null;
      line = line.replaceFirst(RegExp(r'^[>\s]+'), '');
      line = line.replaceFirst(RegExp(r'^[-*+•]\s*'), '');
      line = line.replaceFirst(RegExp(r'^\[.\]\s*'), '');
      line = line.trim();
      if (line.isEmpty || _sepOnly.hasMatch(line)) return null;
      if (_bareDate.hasMatch(line)) return null;
      final m = _amountLine.firstMatch(line);
      if (m == null) return null;
      final amount = _parseAmount(m[1]!);
      if (amount == null) return null;
      var rest = m[2]!.trim();
      final tags = _tag.allMatches(rest).map((t) => t[1]!).toList();
      var title = rest
          .replaceAll(_tag, '')
          .replaceAll(RegExp(r'\s+'), ' ')
          .trim()
          .replaceFirst(RegExp(r'^[,\u066B\u066C\u060C:;\-–—]+\s*'), '')
          .trim();
      if (title.isEmpty) return null; // bare total like `550`
      return Payment(
          DateTime(date.year, date.month, date.day),
          amount,
          title,
          tags.isEmpty ? null : tags.first,
          tags);
    } catch (_) {
      return null;
    }
  }

  static double? _parseAmount(String raw) {
    var s = _enDigits(raw).replaceAll(RegExp(r'[,٬،\s]'), '');
    s = s.replaceAll('٫', '.');
    final slash = RegExp(r'^(\d+)/(\d+)$').firstMatch(s);
    if (slash != null) s = '${slash[1]}.${slash[2]}'; // 475/5 -> 475.5
    if (s.isEmpty) return null;
    return double.tryParse(s);
  }

  static String _enDigits(String s) {
    const fa = '۰۱۲۳۴۵۶۷۸۹';
    const ar = '٠١٢٣٤٥٦٧٨٩';
    final b = StringBuffer();
    for (final r in s.runes) {
      final ch = String.fromCharCode(r);
      final f = fa.indexOf(ch);
      if (f >= 0) {
        b.write(f);
        continue;
      }
      final a = ar.indexOf(ch);
      if (a >= 0) {
        b.write(a);
        continue;
      }
      b.write(ch);
    }
    return b.toString();
  }

  /// Converts a Jalali date to Gregorian (date part only).
  static DateTime jalaliToGregorian(int jy, int jm, int jd) {
    final g = Jalali(jy, jm, jd).toGregorian();
    return DateTime(g.year, g.month, g.day);
  }
}
