# Changelog

## 1.4.1
- Fixed: Restore from backup now auto-discovers local backups — the private `ExpenseTrackerBackups` folder is invisible to the system file picker, so the app now lists `BackupService.listBackups()` with date/version/size and restores directly; `Browse files…` remains for external imports

## 1.4.0
- Visual redesign: Light = Fortress Finance (teal + paper, Hanken Grotesk / Inter / JetBrains Mono); Dark = Neon Tokyo (near-black with pink/cyan/yellow glows, Sora / Inter / Space Grotesk)
- Bundled variable fonts and per-mode theme (semantic income/spent/saved, balance gradient, bordered cards, mono caps labels, glows)
- Dashboard: gradient balance card with glow, centered stat cards, plan preview cards (budgets + goals), refined transaction tiles with neutral expense amounts
- Editor: big centered amount field with underline, caps section labels, outlined date field, polished receipt and tags, updated save action
- Activity: day-grouped transaction list with CapsHeader date groups and refined search
- Reports: semantic stat/charge colors, NET CASHFLOW card, preserved bar label and width fixes
- Settings: grouped cards with CapsHeader sections; alert thresholds moved to a dedicated Alerts & notifications screen
- New Alerts & notifications screen: master toggle, low balance (floor + %), goals & budgets (savings floor + budget warning slider), monthly cap (limit + warning slider), daily digest with delivery time

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
