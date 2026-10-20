import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:ripple/data/models.dart';
import 'package:ripple/data/sources/markdown_source.dart';

void main() {
  group('jalaliToGregorian', () {
    test('known Nowruz anchors', () {
      expect(MarkdownSource.jalaliToGregorian(1403, 1, 1),
          DateTime(2024, 3, 20));
      expect(MarkdownSource.jalaliToGregorian(1404, 1, 1),
          DateTime(2025, 3, 21));
    });
    test('matches resolveDate for vault names', () {
      expect(MarkdownSource.jalaliToGregorian(1404, 7, 5),
          DateTime(2025, 9, 27));
      expect(MarkdownSource.resolveDate('1404-07-05.md'),
          MarkdownSource.jalaliToGregorian(1404, 7, 5));
      expect(MarkdownSource.resolveDate('1405-07-03.md'),
          MarkdownSource.jalaliToGregorian(1405, 7, 3));
    });
  });

  group('resolveDate', () {
    test('gregorian name', () {
      expect(MarkdownSource.resolveDate('2026-09-29.md'),
          DateTime(2026, 9, 29));
    });
    test('short year 405 means 1405', () {
      expect(MarkdownSource.resolveDate('405-07-02.md'),
          MarkdownSource.jalaliToGregorian(1405, 7, 2));
    });
    test('no date returns null (fallback handled by loader)', () {
      expect(MarkdownSource.resolveDate('shopping list.md'), isNull);
    });
    test('invalid month rejected', () {
      expect(MarkdownSource.resolveDate('1404-13-01.md'), isNull);
    });
  });

  group('parseLine', () {
    final day = DateTime(2026, 9, 27);

    test('bullet line with tag', () {
      final p = MarkdownSource.parseLine('- 45000 Lunch #food', day)!;
      expect(p.amount, 45000);
      expect(p.title, 'Lunch');
      expect(p.allTags, ['food']);
      expect(p.date, day);
    });

    test('plain persian line without bullet or tag', () {
      final p =
          MarkdownSource.parseLine('20 رفت و برگشت خوابگاه', day)!;
      expect(p.amount, 20);
      expect(p.title, 'رفت و برگشت خوابگاه');
      expect(p.allTags, isEmpty);
    });

    test('persian digits and slash decimal', () {
      final p =
          MarkdownSource.parseLine('276، ۲ نودل و خامه صبحانه', day)!;
      expect(p.amount, 276);
      final q =
          MarkdownSource.parseLine('475/5 تخم مرغ + روغن', day)!;
      expect(q.amount, 475.5);
    });

    test('separators and bare totals are skipped', () {
      expect(MarkdownSource.parseLine('___', day), isNull);
      expect(MarkdownSource.parseLine('550', day), isNull);
      expect(MarkdownSource.parseLine('993.5', day), isNull);
      expect(MarkdownSource.parseLine('', day), isNull);
    });
  });

  group('removeOne + hidden log + restore', () {
    Future<Directory> makeVault() async {
      final dir =
          await Directory.systemTemp.createTemp('ripple_remove');
      await File('${dir.path}/1405-07-05.md').writeAsString(
          '20 bus home\n45 soda lunch #food\n___\n550\n');
      return dir;
    }

    test('removes line and logs date tag amount removedAt', () async {
      final dir = await makeVault();
      try {
        final src = MarkdownSource(dir.path);
        final rec = await src.removeOne(
          date: DateTime(2026, 9, 27),
          amount: 45,
          title: 'soda lunch',
          tags: ['food'],
        );
        expect(rec, isNotNull);
        expect(rec!.amount, 45);
        expect(rec.title, 'soda lunch');
        expect(rec.tags, ['food']);
        expect(rec.date, DateTime(2026, 9, 27));
        expect(rec.file, '1405-07-05.md');
        // removedAt recorded (repairable later)
        expect(
            DateTime.now().difference(rec.removedAt).inMinutes.abs() < 5,
            isTrue);
        // Line gone, rest intact (bare total untouched too)
        final after = await src.load();
        expect(after.map((p) => p.title),
            containsAll(['bus home']));
        expect(after.map((p) => p.title),
            isNot(contains('soda lunch')));
        expect(after, hasLength(1));
        // Hidden log holds the record
        final log = await src.removedLog();
        expect(log, hasLength(1));
        expect(log.first.amount, 45);
        // Log file is hidden and not parsed as notes
        expect(
            await File('${dir.path}/.ripple_removed.json').exists(),
            isTrue);
      } finally {
        await dir.delete(recursive: true);
      }
    });

    test('restore re-appends line and clears log entry', () async {
      final dir = await makeVault();
      try {
        final src = MarkdownSource(dir.path);
        final rec = (await src.removeOne(
          date: DateTime(2026, 9, 27),
          amount: 20,
          title: 'bus home',
          tags: [],
        ))!;
        await src.restore(rec);
        final after = await src.load();
        expect(after, hasLength(2));
        expect(await src.removedLog(), isEmpty);
      } finally {
        await dir.delete(recursive: true);
      }
    });

    test('no match leaves files untouched', () async {
      final dir = await makeVault();
      try {
        final src = MarkdownSource(dir.path);
        final rec = await src.removeOne(
          date: DateTime(2026, 9, 27),
          amount: 999,
          title: 'nope',
          tags: [],
        );
        expect(rec, isNull);
        expect(await src.load(), hasLength(2));
        expect(await src.removedLog(), isEmpty);
      } finally {
        await dir.delete(recursive: true);
      }
    });

    test('restore re-inserts the ORIGINAL line text', () async {
      final dir = await makeVault();
      try {
        await File('${dir.path}/1405-07-05.md').writeAsString(
            '276، ۲ نودل و خامه صبحانه\n45 soda #food\n');
        final src = MarkdownSource(dir.path);
        final rec = (await src.removeOne(
          date: DateTime(2026, 9, 27),
          amount: 276,
          title: '۲ نودل و خامه صبحانه',
          tags: const [],
        ))!;
        expect(rec.raw, '276، ۲ نودل و خامه صبحانه');
        await src.restore(rec);
        final text =
            await File('${dir.path}/1405-07-05.md').readAsString();
        expect(text.contains('276، ۲ نودل و خامه صبحانه'), isTrue);
      } finally {
        await dir.delete(recursive: true);
      }
    });

    test('failed file write leaves line and log untouched', () async {
      final dir = await makeVault();
      try {
        final file = File('${dir.path}/1405-07-05.md');
        final chmod = await Process.run('chmod', ['444', file.path]);
        expect(chmod.exitCode, 0);
        final src = MarkdownSource(dir.path);
        Object? thrown;
        try {
          await src.removeOne(
            date: DateTime(2026, 9, 27),
            amount: 45,
            title: 'soda lunch',
            tags: ['food'],
          );
        } catch (e) {
          thrown = e;
        }
        expect(thrown, isA<VaultWriteException>());
        expect(await file.readAsString(), contains('soda lunch'));
        expect(await src.removedLog(), isEmpty);
      } finally {
        await Process.run('chmod', ['755', '${dir.path}/1405-07-05.md']);
        await dir.delete(recursive: true);
      }
    });
  });

  group('removedBetween range filter', () {
    RemovedPayment rec(int daysAgo) => RemovedPayment(
          date: DateTime(2026, 9, 27),
          title: 't$daysAgo',
          amount: daysAgo.toDouble(),
          tags: const [],
          file: 'f.md',
          removedAt: DateTime(2026, 10, 2)
              .subtract(Duration(days: daysAgo)),
        );

    test('m..n days ago window', () {
      final log = [rec(0), rec(2), rec(5), rec(9)];
      final got = MarkdownSource.removedBetween(log, 2, 5,
          now: DateTime(2026, 10, 2));
      expect(got.map((r) => r.amount), [2.0, 5.0]);
    });

    test('reversed bounds still work', () {
      final log = [rec(2)];
      final got = MarkdownSource.removedBetween(log, 5, 2,
          now: DateTime(2026, 10, 2));
      expect(got, hasLength(1));
    });
  });

  group('load', () {
    test('term3-style vault: no file lost, totals skipped', () async {
      final dir =
          await Directory.systemTemp.createTemp('ripple_vault');
      try {
        await File('${dir.path}/1404-07-05.md').writeAsString(
            '20 رفت و برگشت خوابگاه\n45 نوشابه ناهار\n___\n550\n');
        await File('${dir.path}/405-07-02.md').writeAsString(
            '120 اسپرسو\n- 75 مترو تا خوابگاه #transport\n___\n1362\n');
        await File('${dir.path}/random notes.md').writeAsString(
            '34 اینترنت\n');
        final payments = await MarkdownSource(dir.path).load();
        expect(payments, hasLength(5));
        final byTitle = {for (final p in payments) p.title: p};
        expect(byTitle['اسپرسو']!.date,
            MarkdownSource.jalaliToGregorian(1405, 7, 2));
        expect(byTitle['مترو تا خوابگاه']!.allTags, ['transport']);
        // File without any date falls back to mtime, still loaded.
        expect(byTitle['اینترنت'], isNotNull);
      } finally {
        await dir.delete(recursive: true);
      }
    });
  });
}
