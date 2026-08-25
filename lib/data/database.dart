import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqlite3/sqlite3.dart' as sqlite3;

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
  // v3: optional receipt photo stored in app documents.
  TextColumn get receiptPath => text().nullable()();
}

/// v3: free-form tags attached to transactions (many-to-many).
class Tags extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text().withLength(min: 1, max: 40)();
  DateTimeColumn get createdAt =>
      dateTime().withDefault(currentDateAndTime)();
}

class TransactionTags extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get txId => integer().references(Transactions, #id)();
  IntColumn get tagId => integer().references(Tags, #id)();
}

/// v3: category-level splits for a single transaction. When splits exist,
/// the parent transaction's own categoryId is ignored in reports/budgets.
class TransactionSplits extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get txId => integer().references(Transactions, #id)();
  IntColumn get categoryId => integer().references(Categories, #id)();
  IntColumn get amountMinor => integer()();
  TextColumn get note => text().nullable()();
}

/// v3: user-defined auto-categorization rules. First matching rule (by
/// priority, then id) whose pattern occurs in the note wins.
class Rules extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get pattern => text().withLength(min: 1, max: 80)();
  IntColumn get categoryId => integer().references(Categories, #id)();
  IntColumn get priority => integer().withDefault(const Constant(0))();
  BoolColumn get enabled => boolean().withDefault(const Constant(true))();
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
    Tags,
    TransactionTags,
    TransactionSplits,
    Rules,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase({String? encryptionKey}) : super(_openConnection(encryptionKey));

  AppDatabase.forTesting(super.e);

  /// Path of the database file used by [AppDatabase()] (not the test one).
  static Future<File> databaseFile() async {
    final dir = await getApplicationDocumentsDirectory();
    return File(p.join(dir.path, 'expense_tracker.sqlite'));
  }

  @override
  int get schemaVersion => 3;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (m) async {
          await m.createAll();
          await _ensureSeedCategories();
        },
        onUpgrade: (m, from, to) async {
          if (from < 2) {
            // v2: richer default catalog; idempotently adds missing names.
            await _ensureSeedCategories();
          }
          if (from < 3) {
            // v3: tags, splits, rules + receiptPath column. Only the NEW
            // entities are created here — createAll() would attempt to
            // recreate pre-existing objects such as the budgets index and
            // fail with "already exists".
            await m.createTable(tags);
            await m.createTable(transactionTags);
            await m.createTable(transactionSplits);
            await m.createTable(rules);
            await m.addColumn(transactions, transactions.receiptPath);
          }
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

LazyDatabase _openConnection(String? encryptionKey) {
  return LazyDatabase(() async {
    final file = await AppDatabase.databaseFile();

    // One-time upgrade: move a legacy plaintext database into an
    // SQLCipher-encrypted one, preserving all data.
    if (encryptionKey != null) {
      await migratePlaintextToEncrypted(file, encryptionKey);
    }

    // Foreground executor: the SQLCipher library override registered in
    // main() lives in this isolate; a background isolate would not see it.
    return NativeDatabase(
      file,
      setup: (rawDb) {
        if (encryptionKey != null) {
          rawDb.execute("PRAGMA key = '$encryptionKey'");
          // Sanity check: encrypted DBs fail this without the right key.
          rawDb.select('SELECT count(*) FROM sqlite_master');
        }
      },
    );
  });
}

/// Escapes a string for safe embedding inside single quotes in a SQL
/// literal. Used only for file paths and the hex key in PRAGMA/ATTACH
/// statements, which cannot be parameterized. All user data flows through
/// Drift's bound variables and never through this.
String sqlQuoteLiteral(String value) => value.replaceAll("'", "''");

/// If [dbFile] exists as a plaintext SQLite database, converts it to an
/// encrypted copy (via SQLCipher's sqlcipher_export) and swaps it in.
/// No-op when the file is missing or already encrypted.
Future<void> migratePlaintextToEncrypted(File dbFile, String key) async {
  if (!await dbFile.exists()) return;

  final plain = sqlite3.sqlite3.open(dbFile.path);
  var isPlaintext = false;
  try {
    // Encrypted files throw here when opened without a key.
    plain.select('SELECT count(*) FROM sqlite_master');
    isPlaintext = true;
  } catch (_) {
    isPlaintext = false;
  }

  if (!isPlaintext) {
    plain.dispose();
    return;
  }

  try {
    final tmpPath = '${dbFile.path}.enc';
    plain.execute(
        "ATTACH DATABASE '${sqlQuoteLiteral(tmpPath)}' AS encrypted "
        "KEY '${sqlQuoteLiteral(key)}'");
    plain.select("SELECT sqlcipher_export('encrypted')");
    plain.execute("DETACH DATABASE encrypted");
  } finally {
    plain.dispose();
  }

  // Swap: keep the plaintext file briefly as a safety net, replace main.
  final legacyCopy = File('${dbFile.path}.plaintext.bak');
  if (await legacyCopy.exists()) await legacyCopy.delete();
  await dbFile.rename(legacyCopy.path);
  await File('${dbFile.path}.enc').rename(dbFile.path);
  await legacyCopy.delete();
}


