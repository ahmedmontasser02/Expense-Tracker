import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:expense_tracker/core/enums.dart';
import 'package:expense_tracker/data/database.dart';
import 'package:expense_tracker/data/repositories/logs_repo.dart';
import 'package:expense_tracker/data/repositories/recurring_repo.dart';
import 'package:expense_tracker/data/repositories/transactions_repo.dart';

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
