import 'package:flutter/material.dart' show ThemeMode;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/countries.dart';
import '../core/enums.dart';
import '../core/format.dart';
import '../data/database.dart';
import '../data/repositories/budgets_repo.dart';
import '../data/repositories/categories_repo.dart';
import '../data/repositories/goals_repo.dart';
import '../data/repositories/logs_repo.dart';
import '../data/repositories/recurring_repo.dart';
import '../data/repositories/settings_repo.dart';
import '../data/repositories/transactions_repo.dart';
import '../services/alert_service.dart';
import '../services/backup_service.dart';

// ---------- Repositories ----------

final databaseProvider =
    Provider<AppDatabase>((ref) => throw UnimplementedError('override in main'));

final encryptionKeyProvider = Provider<String>(
    (ref) => throw UnimplementedError('override in main'));

final backupServiceProvider = Provider((ref) => BackupService(
    ref.watch(databaseProvider),
    ref.watch(settingsRepoProvider),
    ref.watch(encryptionKeyProvider)));

final logsRepoProvider =
    Provider((ref) => LogsRepo(ref.watch(databaseProvider)));

final transactionsRepoProvider = Provider((ref) =>
    TransactionsRepo(ref.watch(databaseProvider), ref.watch(logsRepoProvider)));

final categoriesRepoProvider = Provider((ref) =>
    CategoriesRepo(ref.watch(databaseProvider), ref.watch(logsRepoProvider)));

final budgetsRepoProvider = Provider(
    (ref) => BudgetsRepo(ref.watch(databaseProvider), ref.watch(logsRepoProvider)));

final goalsRepoProvider = Provider(
    (ref) => GoalsRepo(ref.watch(databaseProvider), ref.watch(logsRepoProvider)));

final recurringRepoProvider = Provider((ref) => RecurringRepo(
    ref.watch(databaseProvider),
    ref.watch(logsRepoProvider),
    ref.watch(transactionsRepoProvider)));

final settingsRepoProvider =
    Provider((ref) => SettingsRepo(ref.watch(databaseProvider)));

final alertServiceProvider = Provider(
  (ref) => AlertService(
    transactions: ref.watch(transactionsRepoProvider),
    budgets: ref.watch(budgetsRepoProvider),
    goals: ref.watch(goalsRepoProvider),
    settings: ref.watch(settingsRepoProvider),
    logs: ref.watch(logsRepoProvider),
  ),
);

// ---------- Settings ----------

final settingsMapProvider = StreamProvider<Map<String, String>>(
    (ref) => ref.watch(settingsRepoProvider).watchAll());

final currencySymbolProvider = Provider<String>((ref) {
  final map = ref.watch(settingsMapProvider).value;
  return map?[SettingsRepo.currencySymbol] ??
      SettingsRepo.defaults[SettingsRepo.currencySymbol]!;
});

/// True once first-run country selection is complete. Emits only after
/// settings load, so the UI can hold a splash instead of flashing onboarding.
final countryConfiguredProvider = StreamProvider<bool>((ref) async* {
  final settings = ref.watch(settingsMapProvider);
  final map = settings.value;
  if (map != null) {
    yield (map[SettingsRepo.countryCode] ?? '').isNotEmpty;
  }
});

/// The currently selected country, if any.
final selectedCountryProvider = Provider<CountryCurrency?>((ref) {
  final code = ref.watch(settingsMapProvider).value?[SettingsRepo.countryCode];
  if (code == null || code.isEmpty) return null;
  return findCountry(code);
});

/// App appearance: system / light / dark. Distinct stream so internal
/// settings writes (e.g. alert dedup tokens) never rebuild MaterialApp.
final themeModeProvider = StreamProvider<ThemeMode>((ref) async* {
  await for (final map in ref.watch(settingsRepoProvider).watchAll()) {
    final mode = switch (map[SettingsRepo.appearanceMode]) {
      'light' => ThemeMode.light,
      'dark' => ThemeMode.dark,
      _ => ThemeMode.system,
    };
    yield mode;
  }
});

/// Formats minor units with the live currency symbol; use inside widgets.
String money(WidgetRef ref, int minorUnits) =>
    MoneyFmt.withSymbol(ref.watch(currencySymbolProvider), minorUnits);

// ---------- Live financial data ----------

final balanceProvider = StreamProvider<int>(
    (ref) => ref.watch(transactionsRepoProvider).watchBalance());

final savingsPotProvider = StreamProvider<int>(
    (ref) => ref.watch(transactionsRepoProvider).watchSavingsPot());

final monthSummaryProvider = StreamProvider<MonthSummary>((ref) =>
    ref.watch(transactionsRepoProvider).watchMonthSummary(DateTime.now()));

final allCategoriesProvider = StreamProvider<List<Category>>((ref) =>
    ref.watch(categoriesRepoProvider).watchAll(includeArchived: true));

/// Family provider so the instance is cached per CategoryType — a plain
/// function returning a new provider each call would resubscribe every
/// rebuild and never emit.
final categoriesByTypeProvider =
    StreamProvider.family<List<Category>, CategoryType>(
        (ref, type) => ref.watch(categoriesRepoProvider).watchAll(type: type));

final budgetOverviewFamily =
    StreamProvider.family<List<BudgetRow>, DateTime>((ref, monthAnchor) {
  return ref.read(budgetsRepoProvider).watchMonthOverview(monthAnchor);
});

/// Newest transactions for the dashboard preview.
final recentTxProvider =
    StreamProvider.family<List<Tx>, int>((ref, limit) {
  return ref.watch(transactionsRepoProvider).watchFiltered();
});

final goalsWithProgressProvider = StreamProvider<List<GoalProgress>>(
    (ref) => ref.watch(goalsRepoProvider).watchGoalsWithProgress());

final recurringListProvider = StreamProvider<List<RecurringTemplate>>(
    (ref) => ref.watch(recurringRepoProvider).watchAll());

final activityLogProvider = StreamProvider<List<ActivityLog>>(
    (ref) => ref.watch(logsRepoProvider).watchRecent());


