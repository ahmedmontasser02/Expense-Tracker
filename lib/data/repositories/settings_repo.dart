import '../database.dart';
import '../../core/countries.dart';

/// Typed, reactive key-value settings with sensible defaults.
class SettingsRepo {
  SettingsRepo(this._db);

  final AppDatabase _db;

  static const currencySymbol = 'currency.symbol';
  static const currencyCode = 'currency.code';
  static const countryCode = 'country.code';
  static const appearanceMode = 'appearance.mode'; // system|light|dark
  static const lastBackupKey = 'backup.lastAt';
  static const autoBackupKey = 'backup.autoEnabled';
  static const whatsNewSeenVersion = 'whatsnew.seenVersion';
  static const updateLastCheckedAt = 'update.lastCheckedAt';
  static const updateSkippedVersion = 'update.skippedVersion';
  static const savedFilters = 'filters.saved'; // JSON array of named filters
  static const lowBalancePct = 'alerts.lowBalancePct'; // % of month income
  static const lowBalanceFloorMinor = 'alerts.lowBalanceFloorMinor';
  static const savingsFloorMinor = 'alerts.savingsFloorMinor';
  static const budgetWarnPct = 'alerts.budgetWarnPct';
  static const monthCapWarnPct = 'alerts.monthCapWarnPct';
  static const monthlyCapMinor = 'alerts.monthlyCapMinor';
  static const notificationsEnabled = 'alerts.notificationsEnabled';
  static const dailySummaryEnabled = 'alerts.dailySummaryEnabled';
  static const dailySummaryHour = 'alerts.dailySummaryHour';

  static const defaults = {
    currencySymbol: r'$',
    currencyCode: '',
    countryCode: '',
    appearanceMode: 'system',
    lastBackupKey: '',
    autoBackupKey: 'false',
    lowBalancePct: '20',
    lowBalanceFloorMinor: '5000',
    savingsFloorMinor: '10000',
    budgetWarnPct: '80',
    monthCapWarnPct: '90',
    monthlyCapMinor: '0', // 0 disables the cap rule
    notificationsEnabled: 'true',
    dailySummaryEnabled: 'false',
    dailySummaryHour: '20',
  };

  Stream<Map<String, String>> watchAll() {
    return (_db.select(_db.settingsEntries)).watch().map((rows) => {
          for (final k in defaults.keys) k: defaults[k]!,
          for (final row in rows) row.key: row.value,
        });
  }

  Future<String> _get(String key) async {
    final row = await (_db.select(_db.settingsEntries)
          ..where((s) => s.key.equals(key)))
        .getSingleOrNull();
    return row?.value ?? defaults[key] ?? '';
  }

  Future<void> set(String key, String value) =>
      _db.into(_db.settingsEntries).insertOnConflictUpdate(
            SettingsEntriesCompanion.insert(key: key, value: value),
          );

  Future<String> getString(String key) => _get(key);

  /// Persists a country selection and derives the display currency.
  Future<void> applyCountry(CountryCurrency country) async {
    await set(countryCode, country.code);
    await set(currencyCode, country.currencyCode);
    await set(currencySymbol, country.symbol);
  }

  /// True once the user completed first-run country selection.
  Future<bool> isConfigured() async =>
      (await _get(countryCode)).isNotEmpty;

  Future<int> getInt(String key) async => int.tryParse(await _get(key)) ?? 0;

  Future<double> getDouble(String key) async =>
      double.tryParse(await _get(key)) ?? 0;

  Future<bool> getBool(String key) async => (await _get(key)) == 'true';

  /// Alert dedup registry. Returns true if [scope] has not yet fired for
  /// [periodToken]; otherwise records the token as fired and returns false.
  /// Use a date string ('2026-08-24') for daily dedup or a month key
  /// ('2026-08') for monthly dedup.
  Future<bool> shouldFire(String scope, String periodToken) async {
    final key = 'alertfired.$scope';
    final last = await _get(key);
    if (last == periodToken) return false;
    await set(key, periodToken);
    return true;
  }
}
