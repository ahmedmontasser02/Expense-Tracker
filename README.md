# Expense Tracker

A privacy-first, offline expense tracking app built with **Flutter**. Track daily, monthly and yearly spending, set category budgets, save towards goals, automate recurring transactions, and get notified before your balance or savings run low.

All data stays **on your device** — no accounts, no cloud, no tracking.

<p align="center">
  <img src="assets/icon/app_icon.png" width="128" alt="Expense Tracker logo"/>
</p>

## Features

- **Transactions** — expenses, income and savings deposits/withdrawals with categories, notes and dates. Search, filter by period (today / 7 days / month / year / all) and category.
- **Reports** — daily, monthly and yearly views with spending-trend bar charts, a category donut chart with % slices, totals and "where the money went" ranking. Pick any date, month or year directly.
- **Budgets** — monthly spending limits per category with live progress bars and overspend highlighting.
- **Savings goals** — targets with optional deadlines, progress tracking, quick deposits/withdrawals.
- **Recurring transactions** — daily/weekly/monthly/yearly templates (rent, subscriptions, salary…) with intervals, end dates, pause/resume. Due entries are generated automatically on app start.
- **Smart alerts** — configurable notifications for low balance, low savings, goals behind schedule, category budget warnings and monthly spending caps. Deduplicated so you never get spammed.
- **Activity log** — every create/update/delete/auto-generation/alert is recorded and browsable.
- **Diagnostics** — one-tap export of a bug report (app info, captured errors, recent activity) from Settings → Diagnostics.
- **Country-based currency** — pick your country on first launch; 70+ currencies, changeable any time. Light / dark / system theme.

## Tech stack

| Layer | Choice |
|---|---|
| Framework | Flutter (Material 3, light + dark) |
| State management | flutter_riverpod |
| Database | Drift (SQLite), local-only, integer minor-unit money math |
| Charts | fl_chart |
| Notifications | flutter_local_notifications + timezone |
| Sharing/diagnostics | share_plus, package_info_plus |

## Project layout

```
lib/
├── core/          # theme, enums, money/date formatting, country catalog
├── data/          # Drift schema + repositories (transactions, budgets, goals…)
├── services/      # notification service, alert engine, recurring engine, diagnostics
├── providers/     # Riverpod providers
└── features/      # dashboard, transactions, reports, budgets, savings,
                   # recurring, categories, logs, settings, onboarding, shell
```

## Getting started

Prerequisites: **Flutter 3.38.9** (the dependency set is pinned against it), Android SDK / Xcode for mobile targets.

```bash
flutter pub get
flutter run                 # pick your device/emulator
```

Regenerate launcher icons after changing `assets/icon/`:

```bash
dart run flutter_launcher_icons
```

Regenerate the Drift schema code after editing `lib/data/database.dart`:

```bash
dart run build_runner build --delete-conflicting-outputs
```

## Tests

```bash
flutter test
```

Covers money/date math (including month-end clamping and DST-safe recurring steps), alert-rule evaluation, repository aggregations and a dashboard smoke test.

## CI/CD

GitHub Actions (`.github/workflows/ci.yml`) runs on every push/PR to `main`:

1. `flutter pub get`
2. `flutter analyze --fatal-infos`
3. `flutter test`
4. `flutter build apk --release` + `flutter build appbundle --release`
5. Uploads the APK and AAB as artifacts

CI builds are debug-signed; the release keystore is intentionally not committed.

## Release signing (local)

`android/key.properties` + `android/app/upload-keystore.jks` (both gitignored) hold the upload key. `android/app/build.gradle.kts` uses them when present and falls back to debug signing otherwise.

> **Back up `upload-keystore.jks` and its passwords** — losing them means you cannot update an already-published Play Store listing with the same signature.

Build release artifacts:

```bash
flutter build apk --release        # build/app/outputs/flutter-apk/app-release.apk
flutter build appbundle --release  # build/app/outputs/bundle/release/app-release.aab
```

## Roadmap ideas

- CSV export/import
- Multi-currency wallets with historical conversion
- Widgets and quick-actions
- Localization (Arabic + RTL)

## License

Personal project — all rights reserved by the author.
