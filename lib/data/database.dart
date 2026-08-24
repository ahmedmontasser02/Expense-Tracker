import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../core/category_presets.dart';
import '../core/enums.dart';

part 'database.g.dart';

@DataClassName('Tx')
class Transactions extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get type => intEnum<TxType>()();
  // Minor units (cents). Always positive; direction comes from [type].
  IntColumn get amountMinor => integer()();
  IntColumn get categoryId => integer().nullable().references(Categories, #id)();
  IntColumn get goalId =>
      integer().nullable().references(SavingsGoals, #id)();
  TextColumn get note => text().nullable()();
  DateTimeColumn get occurredAt => dateTime()();
  DateTimeColumn get createdAt =>
      dateTime().withDefault(currentDateAndTime)();
}

class Categories extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text().withLength(min: 1, max: 60)();
  IntColumn get type => intEnum<CategoryType>()();
  TextColumn get iconCode => text().withDefault(const Constant('more_horiz'))();
  IntColumn get colorValue => integer().withDefault(const Constant(0xFF546E7A))();
  BoolColumn get archived => boolean().withDefault(const Constant(false))();
}

@TableIndex(
    name: 'idx_budget_cat_month', columns: {#categoryId, #monthKey}, unique: true)
class Budgets extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get categoryId => integer().references(Categories, #id)();
  TextColumn get monthKey => text().withLength(min: 7, max: 7)(); // '2026-08'
  IntColumn get limitMinor => integer()();
}

class SavingsGoals extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text().withLength(min: 1, max: 80)();
  IntColumn get targetMinor => integer()();
  DateTimeColumn get deadline => dateTime().nullable()();
  BoolColumn get archived => boolean().withDefault(const Constant(false))();
  DateTimeColumn get createdAt =>
      dateTime().withDefault(currentDateAndTime)();
}

class RecurringTemplates extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get type => intEnum<TxType>()();
  IntColumn get amountMinor => integer()();
  IntColumn get categoryId => integer().nullable().references(Categories, #id)();
  IntColumn get goalId =>
      integer().nullable().references(SavingsGoals, #id)();
  TextColumn get note => text().nullable()();
  IntColumn get frequency => intEnum<Frequency>()();
  IntColumn get everyN => integer().withDefault(const Constant(1))();
  DateTimeColumn get nextDueAt => dateTime()();
  DateTimeColumn get endAfter => dateTime().nullable()();
  DateTimeColumn get lastRunAt => dateTime().nullable()();
  BoolColumn get active => boolean().withDefault(const Constant(true))();
  DateTimeColumn get createdAt =>
      dateTime().withDefault(currentDateAndTime)();
}

class ActivityLogs extends Table {
  IntColumn get id => integer().autoIncrement()();
  DateTimeColumn get at => dateTime().withDefault(currentDateAndTime)();
  IntColumn get action => intEnum<LogAction>()();
  TextColumn get entityType => text()(); // transaction|category|budget|goal|recurring
  IntColumn get entityId => integer().nullable()();
  TextColumn get details => text().withDefault(const Constant(''))();
}

class SettingsEntries extends Table {
  TextColumn get key => text()();
  TextColumn get value => text()();

  @override
  Set<Column> get primaryKey => {key};
}

@DriftDatabase(
  tables: [
    Categories,
    Transactions,
    Budgets,
    SavingsGoals,
    RecurringTemplates,
    ActivityLogs,
    SettingsEntries,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  AppDatabase.forTesting(super.e);

  @override
  int get schemaVersion => 2;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (m) async {
          await m.createAll();
          await _ensureSeedCategories();
        },
        onUpgrade: (m, from, to) async {
          // v2: richer default catalog; idempotently adds missing names.
          await _ensureSeedCategories();
        },
      );

  /// Inserts any seed category whose name does not exist yet.
  Future<void> _ensureSeedCategories() async {
    final existing = await select(categories).get();
    final names = existing.map((e) => e.name).toSet();
    final missing = <CategoriesCompanion>[
      for (final (name, icon, colorIdx) in SeedCategories.expenses)
        if (!names.contains(name))
          CategoriesCompanion.insert(
            name: name,
            type: CategoryType.expense,
            iconCode: Value(icon),
            colorValue: Value(IconPresets.palette[colorIdx].toARGB32()),
          ),
      for (final (name, icon, colorIdx) in SeedCategories.incomes)
        if (!names.contains(name))
          CategoriesCompanion.insert(
            name: name,
            type: CategoryType.income,
            iconCode: Value(icon),
            colorValue: Value(IconPresets.palette[colorIdx].toARGB32()),
          ),
    ];
    if (missing.isNotEmpty) {
      await batch((b) => b.insertAll(categories, missing));
    }
  }
}

LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final dir = await getApplicationDocumentsDirectory();
    final file = File(p.join(dir.path, 'expense_tracker.sqlite'));
    return NativeDatabase.createInBackground(file);
  });
}
