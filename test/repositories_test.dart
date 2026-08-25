import 'dart:io';

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:expense_tracker/core/enums.dart';
import 'package:expense_tracker/data/database.dart';
import 'package:expense_tracker/data/repositories/logs_repo.dart';
import 'package:expense_tracker/data/repositories/recurring_repo.dart';
import 'package:expense_tracker/data/repositories/rules_repo.dart';
import 'package:expense_tracker/data/repositories/tags_repo.dart';
import 'package:expense_tracker/data/repositories/transactions_repo.dart';
import 'package:path/path.dart' as p;
import 'package:sqlite3/sqlite3.dart' as sqlite3;

void main() {
  late AppDatabase db;
  late TransactionsRepo txRepo;
  late RecurringRepo recRepo;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    final logs = LogsRepo(db);
    txRepo = TransactionsRepo(db, logs);
    recRepo = RecurringRepo(db, logs, txRepo);
  });

  tearDown(() async => db.close());

  group('TransactionsRepo aggregates', () {
    test('seeded database starts with default categories', () async {
      final cats = await db.select(db.categories).get();
      expect(cats, isNotEmpty);
      expect(cats.any((c) => c.type == CategoryType.expense), isTrue);
      expect(cats.any((c) => c.type == CategoryType.income), isTrue);
    });

    test('balance = income - spent; savings moves are neutral', () async {
      await txRepo.create(TransactionsCompanion.insert(
        type: TxType.income,
        amountMinor: 100000,
        occurredAt: DateTime.now(),
      ));
      await txRepo.create(TransactionsCompanion.insert(
        type: TxType.expense,
        amountMinor: 30000,
        occurredAt: DateTime.now(),
      ));
      await txRepo.create(TransactionsCompanion.insert(
        type: TxType.savingsDeposit,
        amountMinor: 20000,
        occurredAt: DateTime.now(),
      ));
      // Savings deposits do not change total balance.
      expect(await txRepo.currentBalance(), 70000);
      expect(await txRepo.savingsPot(), 20000);

      await txRepo.create(TransactionsCompanion.insert(
        type: TxType.savingsWithdrawal,
        amountMinor: 5000,
        occurredAt: DateTime.now(),
      ));
      expect(await txRepo.currentBalance(), 70000);
      expect(await txRepo.savingsPot(), 15000);
    });

    test('malicious strings cannot inject SQL', () async {
      const evilName = "Robert'); DROP TABLE transactions;--";
      const evilNote = "x'; DELETE FROM categories; SELECT '";
      final evilCatId = await db.into(db.categories).insert(
            CategoriesCompanion.insert(
              name: evilName,
              type: CategoryType.expense,
            ),
          );
      await txRepo.create(TransactionsCompanion.insert(
        type: TxType.expense,
        amountMinor: 1234,
        categoryId: Value(evilCatId),
        note: Value(evilNote),
        occurredAt: DateTime.now(),
      ));

      // Tables still exist and data round-trips verbatim.
      final txs = await txRepo.db.select(txRepo.db.transactions).get();
      expect(txs, hasLength(1));
      expect(txs.single.note, evilNote);
      final cat = await (txRepo.db.select(txRepo.db.categories)
            ..where((c) => c.id.equals(evilCatId)))
          .getSingle();
      expect(cat.name, evilName);

      // Searching for an injection pattern is safe (parameterized LIKE).
      final hits = await txRepo
          .watchFiltered(search: "'; DROP TABLE transactions;--")
          .first;
      expect(hits, isEmpty);
      expect(await txRepo.db.select(txRepo.db.transactions).get(),
          hasLength(1));
    });

    test('expenseByCategory groups by category within range', () async {
      final cats = await db.select(db.categories).get();
      final food = cats.firstWhere((c) => c.name == 'Groceries');
      await txRepo.create(TransactionsCompanion.insert(
        type: TxType.expense,
        amountMinor: 1000,
        categoryId: Value(food.id),
        occurredAt: DateTime.now(),
      ));
      await txRepo.create(TransactionsCompanion.insert(
        type: TxType.expense,
        amountMinor: 2500,
        categoryId: Value(food.id),
        occurredAt: DateTime.now(),
      ));
      final now = DateTime.now();
      final spend = await txRepo.expenseByCategory(
          DateTime(now.year, now.month), DateTime(now.year, now.month + 1));
      expect(spend[food.id], 3500);
    });
  });

  group('M3: splits, rules and tags', () {
    late TagsRepo tagsRepo;
    late RulesRepo rulesRepo;

    setUp(() {
      tagsRepo = TagsRepo(db);
      rulesRepo = RulesRepo(db);
    });

    test('expenseByCategory attributes split portions per category',
        () async {
      final cats = await db.select(db.categories).get();
      final food = cats.firstWhere((c) => c.name == 'Groceries');
      final house = cats.firstWhere((c) => c.name == 'Shopping');
      final txId = await txRepo.create(TransactionsCompanion.insert(
        type: TxType.expense,
        amountMinor: 5000,
        categoryId: Value(food.id),
        occurredAt: DateTime.now(),
      ));
      await txRepo.setSplits(txId, [
        (categoryId: food.id, amountMinor: 2000, note: null),
        (categoryId: house.id, amountMinor: 3000, note: 'cleaning'),
      ]);

      final now = DateTime.now();
      final spend = await txRepo.expenseByCategory(
          DateTime(now.year, now.month), DateTime(now.year, now.month + 1));
      // The parent category is ignored when splits exist.
      expect(spend[food.id], 2000);
      expect(spend[house.id], 3000);
      expect(spend.values.fold<int>(0, (a, b) => a + b), 5000);
    });

    test('setSplits replaces rows; delete cascades joins; undo restores them',
        () async {
      final cats = await db.select(db.categories).get();
      final food = cats.firstWhere((c) => c.name == 'Groceries');
      final tagId = await tagsRepo.getOrCreate('weekly shop');
      final txId = await txRepo.create(TransactionsCompanion.insert(
        type: TxType.expense,
        amountMinor: 4000,
        categoryId: Value(food.id),
        occurredAt: DateTime.now(),
      ));
      await txRepo.setSplits(txId, [
        (categoryId: food.id, amountMinor: 1500, note: null),
        (categoryId: food.id, amountMinor: 2500, note: null),
        (categoryId: food.id, amountMinor: 1000, note: null),
      ]);
      expect(txRepo.hasSplits(txId), completion(isTrue));
      await tagsRepo.setTagsForTx(txId, [tagId]);

      // Replace: three rows become two.
      await txRepo.setSplits(txId, [
        (categoryId: food.id, amountMinor: 1000, note: 'a'),
        (categoryId: food.id, amountMinor: 3000, note: 'b'),
      ]);
      expect(await txRepo.splitsForTx(txId), hasLength(2));

      // Delete captures joins for undo.
      final tx =
          await (db.select(db.transactions)..where((t) => t.id.equals(txId)))
              .getSingle();
      final joins = await txRepo.delete(tx);
      expect(joins.splits, hasLength(2));
      expect(joins.tagIds, [tagId]);
      expect(await db.select(db.transactionSplits).get(), isEmpty);
      expect(await db.select(db.transactionTags).get(), isEmpty);

      // Undo restores everything.
      await txRepo.restore(tx, splits: joins.splits, tagIds: joins.tagIds);
      expect(await txRepo.splitsForTx(txId), hasLength(2));
      expect(await tagsRepo.tagsForTx(txId), hasLength(1));
    });

    test('matchCategory honours priority over recency and skips disabled',
        () async {
      final cats = await db.select(db.categories).get();
      int catId(String name) => cats.firstWhere((c) => c.name == name).id;
      // Older + low priority.
      await rulesRepo.create(RulesCompanion.insert(
        pattern: 'netflix',
        categoryId: catId('Subscriptions'),
      ));
      // Newer but highest priority wins first.
      final strong = await rulesRepo.create(RulesCompanion.insert(
        pattern: 'net',
        categoryId: catId('Shopping'),
        priority: const Value(10),
      ));

      expect(await rulesRepo.matchCategory('NETFLIX subscription'),
          catId('Shopping'));
      expect(await rulesRepo.matchCategory('unrelated'), isNull);

      await rulesRepo.setEnabled(strong, false);
      expect(await rulesRepo.matchCategory('netflix subscription'),
          catId('Subscriptions'));
    });

    test('suggestCategory learns from historical note tokens', () async {
      final cats = await db.select(db.categories).get();
      int catId(String name) => cats.firstWhere((c) => c.name == name).id;
      Future<void> add(String note, String cat) =>
          txRepo.create(TransactionsCompanion.insert(
            type: TxType.expense,
            amountMinor: 1000,
            categoryId: Value(catId(cat)),
            note: Value(note),
            occurredAt: DateTime.now(),
          ));
      await add('uber ride to office', 'Transport');
      await add('uber back home', 'Transport');
      await add('uber eats order', 'Lunch & Dining');

      // 'uber' appears twice under Transport vs once under Lunch.
      expect(await rulesRepo.suggestCategory('uber trip tomorrow'),
          catId('Transport'));
      // No history at all -> null.
      expect(await rulesRepo.suggestCategory('zzz qqq'), isNull);
    });

    test('tags dedupe case-insensitively; rename; delete detaches joins',
        () async {
      final a = await tagsRepo.getOrCreate('Travel');
      final b = await tagsRepo.getOrCreate('travel');
      expect(a, b);

      await tagsRepo.rename(a, 'Trips');
      final all = await tagsRepo.all();
      expect(all.single.name, 'Trips');

      final cats = await db.select(db.categories).get();
      final txId = await txRepo.create(TransactionsCompanion.insert(
        type: TxType.expense,
        amountMinor: 900,
        categoryId: Value(cats.first.id),
        occurredAt: DateTime.now(),
      ));
      await tagsRepo.setTagsForTx(txId, [a]);
      expect(await tagsRepo.tagsForTx(txId), hasLength(1));

      await tagsRepo.delete(a);
      expect(await tagsRepo.all(), isEmpty);
      expect(await tagsRepo.tagsForTx(txId), isEmpty);
    });

    test('v2 -> v3 upgrade migrates a real legacy database', () async {
      // Hand-build a v2-shaped database: no tags/splits/rules tables,
      // transactions without receipt_path, budgets index already present.
      final dir = await Directory.systemTemp.createTemp('m3migration');
      addTearDown(() => dir.delete(recursive: true));
      final legacyPath = p.join(dir.path, 'legacy.sqlite');
      final raw = sqlite3.sqlite3.open(legacyPath);
      raw.execute('CREATE TABLE categories ('
          'id INTEGER PRIMARY KEY AUTOINCREMENT, '
          'name TEXT NOT NULL, type INTEGER NOT NULL, '
          'icon_code TEXT NOT NULL DEFAULT \'more_horiz\', '
          'color_value INTEGER NOT NULL DEFAULT 553582842, '
          'archived INTEGER NOT NULL DEFAULT 0)');
      raw.execute("INSERT INTO categories (name, type) VALUES ('Food', 0)");
      raw.execute('CREATE TABLE transactions ('
          'id INTEGER PRIMARY KEY AUTOINCREMENT, '
          'type INTEGER NOT NULL, amount_minor INTEGER NOT NULL, '
          'category_id INTEGER NULL, goal_id INTEGER NULL, note TEXT NULL, '
          'occurred_at INTEGER NOT NULL, '
          'created_at INTEGER NOT NULL DEFAULT 0)');
      raw.execute("INSERT INTO transactions (type, amount_minor, note, "
          "occurred_at, created_at) VALUES (0, 4242, 'legacy row', 0, 0)");
      raw.execute('CREATE TABLE budgets (id INTEGER PRIMARY KEY AUTOINCREMENT, '
          'category_id INTEGER NOT NULL, month_key TEXT NOT NULL, '
          'limit_minor INTEGER NOT NULL)');
      raw.execute('CREATE UNIQUE INDEX idx_budget_cat_month '
          'ON budgets (category_id, month_key)');
      raw.execute('PRAGMA user_version = 2');
      raw.dispose();

      // Opening through the current schema runs the v2->v3 migration.
      final legacyFile = File(legacyPath);
      expect(legacyFile.existsSync(), isTrue);
      final upgradedDb = AppDatabase.forTesting(NativeDatabase(legacyFile));
      addTearDown(upgradedDb.close);

      // New entities exist and legacy data survived.
      expect(await upgradedDb.select(upgradedDb.tags).get(), isEmpty);
      expect(await upgradedDb.select(upgradedDb.rules).get(), isEmpty);
      expect(await upgradedDb.select(upgradedDb.transactionSplits).get(),
          isEmpty);
      final legacy =
          await upgradedDb.select(upgradedDb.transactions).getSingle();
      expect(legacy.amountMinor, 4242);
      expect(legacy.receiptPath, isNull);

      // Splits remain usable end-to-end after the upgrade.
      final food = await (upgradedDb.select(upgradedDb.categories)
            ..where((c) => c.name.equals('Food')))
          .getSingle();
      final txRepoMigrated = TransactionsRepo(
          upgradedDb, LogsRepo(upgradedDb));
      await txRepoMigrated.setSplits(legacy.id, [
        (categoryId: food.id, amountMinor: 4242, note: null),
      ]);
      expect(await txRepoMigrated.splitsForTx(legacy.id), hasLength(1));
    });
  });

  group('RecurringRepo.processDue', () {
    test('generates due occurrences and advances nextDueAt idempotently',
        () async {
      final now = DateTime(2026, 3, 15);
      final jan31 = DateTime(2026, 1, 31);
      final id = await recRepo.create(RecurringTemplatesCompanion.insert(
        type: TxType.expense,
        amountMinor: 10000,
        frequency: Frequency.monthly,
        nextDueAt: jan31,
      ));

      // Jan 31 -> Feb 28 (clamped) -> Mar 14? No: monthly from Jan 31:
      // occurrences Jan31, Feb28, then Mar 28 is after `now` (Mar15)? Mar 28
      // > Mar 15 so exactly two occurrences are due.
      final generated = await recRepo.processDue(now: now);
      expect(generated, 2);

      final tpl = await recRepo.byId(id);
      expect(tpl.nextDueAt, DateTime(2026, 3, 28));
      expect(tpl.lastRunAt, isNotNull);

      // Idempotent: nothing more until Mar 28.
      expect(await recRepo.processDue(now: now), 0);
      expect(await recRepo.processDue(now: DateTime(2026, 3, 27)), 0);
      expect(await recRepo.processDue(now: DateTime(2026, 3, 28)), 1);

      final all =
          await txRepo.db.select(txRepo.db.transactions).get();
      expect(all.length, 3);
    });

    test('respects endAfter and inactive templates', () async {
      final now = DateTime(2026, 5, 10);
      final id = await recRepo.create(RecurringTemplatesCompanion.insert(
        type: TxType.income,
        amountMinor: 50000,
        frequency: Frequency.weekly,
        nextDueAt: DateTime(2026, 4, 20),
        endAfter: Value(DateTime(2026, 5, 4)),
      ));
      // Due: Apr20, Apr27, May4 (May11 > endAfter).
      expect(await recRepo.processDue(now: now), 3);
      await recRepo.setActive(id, false);

      final t2id = await recRepo.create(RecurringTemplatesCompanion.insert(
        type: TxType.expense,
        amountMinor: 100,
        frequency: Frequency.daily,
        nextDueAt: now.subtract(const Duration(days: 3)),
      ));
      await recRepo.setActive(t2id, false);
      expect(await recRepo.processDue(now: now), 0);
    });
  });
}
