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
Daily notes must be named `YYYY-MM-DD.md`. Payment lines:

```
- 45000 Lunch #food
- 120000 Rent #fixed
* 35000 Taxi
- [ ] 50000 Groceries
```

The app reads recursively, parsing any `.md` file with a date in the filename.

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
