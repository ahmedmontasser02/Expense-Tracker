# Changelog

## 1.3.1
- Fixed: update checker and downloads failed in installed (release) builds —
  the app was missing the INTERNET permission
- Fixed: operations in Settings (update check, backups, theme, thresholds)
  bounced back to the Home tab; they now stay in place and report their
  result — including "canceled" — as a toast
- Fixed: Spending trend chart — readable day labels (every 5th day), wider
  bars, and correct day count for past months

## 1.3.0
- Tags: label transactions your way and manage them under Organize → Tags
- Category splits: split one expense across categories (reports and
  budgets follow the splits)
- Receipts: attach a photo from camera or gallery to any transaction
- Auto-categorization rules: teach the app that "netflix" means
  Subscriptions, plus smart suggestions learned from your history
- Saved filters: bookmark frequently used transaction filters with one tap

## 1.2.0
- In-app updates: get notified when a new version is released and install
  it directly from the app
- Share-to-log: share text like "Paid 250 for lunch" from any app to log
  a transaction instantly
- 'Add expense' quick action on notifications
- What's new dialog and dev/prod build flavors
- Reports polish: no more layout overflow on the totals row

## 1.1.0
- Encrypted database (SQLCipher) — data at rest is now protected with a per-device key
- Automatic daily backups (last 7 kept) + manual backup & restore in Settings
- Exit confirmation when pressing back on the home screen
- Balance formula corrected: income − spent (savings moves no longer double-count)
- Security hardening around SQL statements + regression tests

## 1.0.0
- Initial release: transactions, categories, budgets, savings goals,
  recurring transactions, daily/monthly/yearly reports, smart alerts,
  activity log, country-based currency, light/dark theme
