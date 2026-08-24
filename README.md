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

GitHub Actions workflows:

| Workflow | Trigger | What it does |
|---|---|---|
| **CI** (`.github/workflows/ci.yml`) | push / PR to `main` | pub get → analyze → tests → release APK + AAB builds → artifacts |
| **Release** (`.github/workflows/release.yml`) | tag `v*` | analyze → tests → universal release APK → **GitHub Release with downloadable APK** |

## Install on your devices (sideloading)

No Play Store needed — the app is distributed as a signed APK:

1. Go to the repo's **Releases** page and download `expense-tracker-vX.Y.Z-<tag>.apk`
   (or grab the APK artifact from any CI run on `main`).
2. Copy it to your Android device, tap it, and allow *Install unknown apps*
   for whichever app you open it with (browser/file manager). You may need to
   confirm once per device.
3. Done — updates install the same way; Android updates the app in place as
   long as the new APK is signed with the same key (it always is, see below).

> **Keep the signing key consistent:** `android/app/upload-keystore.jks` signs
> every release build. Android refuses to *update* an installed app with an
> APK signed by a different key (you'd have to uninstall first, losing local
> data). Back up the keystore and its passwords.

## Release a new version

```bash
# bump `version:` in pubspec.yaml, commit, then:
git tag v1.0.1
git push origin main v1.0.1
```

The Release workflow builds and attaches the APK to a GitHub Release
automatically.

## Release signing (local)

`android/key.properties` + `android/app/upload-keystore.jks` (both gitignored) hold the upload key. `android/app/build.gradle.kts` uses them when present and falls back to debug signing otherwise (CI builds).

Build release artifacts locally:

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
