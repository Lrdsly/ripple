# Ripple — Personal Payment Tracker

Flutter app that reads your Obsidian daily notes (or uses demo data) and shows:

- Weekly bar chart of daily spend
- Daily average + monthly forecast ("required money")
- Fixed recurring expenses (weekdays or times-per-month)

## Getting started

```bash
flutter pub get
flutter run -d linux        # desktop
flutter run -d android      # phone (after Android SDK setup)
```

## Data

**Demo mode** (default): random fake payments — works immediately.

**Your notes**: tap the folder icon in the app bar and pick your Obsidian vault.
Filenames: `2026-09-29.md` (Gregorian) or `1404-07-05.md` (Jalali, auto-converted;
short `405-07-02` also works). Files with no date use their modification date —
no `.md` file is ever skipped. Payment lines (bullet optional):

```
- 45000 Lunch #food
20 رفت و برگشت خوابگاه
276 نودل #غذا
475/5 تخم مرغ
```

Separators (`___`) and bare totals (`550`) are ignored.

**Managing notes**: tap the minus badge on any payment card to remove
that line from its `.md` file (with confirm + undo). Removals are
recorded in the hidden `.ripple_removed.json` log in the vault root
(date, title, amount, tags, removal time) so they can be restored later.

## Architecture

The code is organized for extension:

```
lib/
  main.dart              # app shell — thin entry point
  app_state.dart         # state: payments, fixed expenses, folder, week offset
  core/theme.dart        # dark theme, colors
  data/
    models.dart          # Payment, FixedExpense
    sources/
      payment_source.dart  # abstract interface — new backends go here
      demo_source.dart     # fake data
      markdown_source.dart # reads .md files
  domain/analytics.dart  # pure functions — weekly sums, forecast, averages
  ui/
    home_page.dart       # main screen
    fixed_page.dart      # add/edit/delete fixed expenses
    weekly_chart.dart    # 7-day animated bar chart
```

To add a new data source (REST API, SQLite, sync…): add a class in `data/sources/`
implementing `PaymentSource`, then drop it into `AppState._source`. Zero UI changes.

To add income, categories, tags, or charts: extend `Payment` / `Analytics` and
add a new UI widget. The separation keeps each concern isolated.

## Building for Android

```bash
flutter build apk
# outputs build/app/outputs/flutter-apk/app-release.apk
```

Requires Android SDK (see `flutter doctor`).
