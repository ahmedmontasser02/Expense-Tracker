import 'package:drift/drift.dart';

import '../database.dart';
import '../../core/enums.dart';
import 'logs_repo.dart';

/// Month-level aggregate of transaction flows.
typedef MonthSummary = ({
  int incomeMinor,
  int expenseMinor,
  int savedInMinor,
  int savedOutMinor,
});

/// CRUD + aggregate queries over transactions. Money in minor units.
class TransactionsRepo {
  TransactionsRepo(this._db, this._logs);

  final AppDatabase _db;
  final LogsRepo _logs;

  AppDatabase get db => _db;

  // ---------- Aggregates ----------

  /// Balance = income − expenses (all time). Savings deposits/withdrawals
  /// are internal allocations of the same money and do not change total
  /// balance — the savings pot is reported separately via [watchSavingsPot].
  Stream<int> watchBalance() => _watchAll().map(
        (rows) => rows.fold<int>(
            0,
            (s, t) =>
                s +
                switch (t.type) {
                  TxType.income => t.amountMinor,
                  TxType.expense => -t.amountMinor,
                  _ => 0,
                }),
      );

  /// Savings pot = deposits − withdrawals (all time).
  Stream<int> watchSavingsPot() => _watchAll().map(
        (rows) => rows.fold<int>(
            0,
            (s, t) =>
                s +
                switch (t.type) {
                  TxType.savingsDeposit => t.amountMinor,
                  TxType.savingsWithdrawal => -t.amountMinor,
                  _ => 0,
                }),
      );

  Stream<MonthSummary> watchMonthSummary(DateTime monthAnchor) {
    final from = DateTime(monthAnchor.year, monthAnchor.month);
    final to = DateTime(monthAnchor.year, monthAnchor.month + 1);
    return _watchRangeQuery(from, to).map(_summarize);
  }

  Future<MonthSummary> monthSummary(DateTime monthAnchor) async {
    final from = DateTime(monthAnchor.year, monthAnchor.month);
    final to = DateTime(monthAnchor.year, monthAnchor.month + 1);
    final rows = await (_db.select(_db.transactions)
          ..where((t) => t.occurredAt.isBetweenValues(from, to)))
        .get();
    return _summarize(rows);
  }

  Future<int> currentBalance() async =>
      (await _db.select(_db.transactions).get()).fold<int>(
          0,
          (s, t) =>
              s +
              switch (t.type) {
                TxType.income => t.amountMinor,
                TxType.expense => -t.amountMinor,
                _ => 0,
              });

  Future<int> savingsPot() async => (await _db.select(_db.transactions).get())
      .fold<int>(
          0,
          (s, t) =>
              s +
              switch (t.type) {
                TxType.savingsDeposit => t.amountMinor,
                TxType.savingsWithdrawal => -t.amountMinor,
                _ => 0,
              });

  /// Expense total per categoryId within [from, to).
  Future<Map<int, int>> expenseByCategory(DateTime from, DateTime to) async {
    final rows = await (_db.select(_db.transactions)
          ..where((t) =>
              t.type.equalsValue(TxType.expense) &
              t.occurredAt.isBetweenValues(from, to) &
              t.categoryId.isNotNull()))
        .get();
    final map = <int, int>{};
    for (final r in rows) {
      map[r.categoryId!] = (map[r.categoryId!] ?? 0) + r.amountMinor;
    }
    return map;
  }

  Stream<Map<int, int>> watchExpenseByCategory(
      DateTime from, DateTime to) {
    return _watchRangeQuery(from, to)
        .map((rows) {
      final map = <int, int>{};
      for (final r in rows.where((e) =>
          e.type == TxType.expense && e.categoryId != null)) {
        map[r.categoryId!] = (map[r.categoryId!] ?? 0) + r.amountMinor;
      }
      return map;
    });
  }

  MonthSummary _summarize(List<Tx> rows) {
    var income = 0, expense = 0, savedIn = 0, savedOut = 0;
    for (final t in rows) {
      switch (t.type) {
        case TxType.income:
          income += t.amountMinor;
        case TxType.expense:
          expense += t.amountMinor;
        case TxType.savingsDeposit:
          savedIn += t.amountMinor;
        case TxType.savingsWithdrawal:
          savedOut += t.amountMinor;
      }
    }
    return (
      incomeMinor: income,
      expenseMinor: expense,
      savedInMinor: savedIn,
      savedOutMinor: savedOut,
    );
  }

  // ---------- List / filters ----------

  /// Watch transactions in an optional range with optional category filter
  /// and note search, newest first.
  Stream<List<Tx>> watchFiltered({
    DateTime? from,
    DateTime? to,
    int? categoryId,
    String? search,
  }) {
    return _filteredQuery(from: from, to: to, categoryId: categoryId, search: search)
        .watch();
  }

  SimpleSelectStatement<$TransactionsTable, Tx> _filteredQuery({
    DateTime? from,
    DateTime? to,
    int? categoryId,
    String? search,
  }) {
    final q = _db.select(_db.transactions);
    if (from != null && to != null) {
      q.where((t) => t.occurredAt.isBetweenValues(from, to));
    }
    if (categoryId != null) q.where((t) => t.categoryId.equals(categoryId));
    if (search != null && search.trim().isNotEmpty) {
      q.where((t) => t.note.like('%${search.trim()}%'));
    }
    q.orderBy([(t) => OrderingTerm.desc(t.occurredAt)]);
    return q;
  }

  Stream<List<Tx>> _watchAll() => _db.select(_db.transactions).watch();

  Expression<bool> Function($TransactionsTable) _between(DateTime from,
          DateTime to) =>
      (t) => t.occurredAt.isBetweenValues(from, to);

  Stream<List<Tx>> _watchRangeQuery(DateTime from, DateTime to) {
    final q = _db.select(_db.transactions)..where(_between(from, to));
    return q.watch();
  }

  // ---------- Mutations ----------

  Future<int> create(TransactionsCompanion entry) async {
    final id = await _db.into(_db.transactions).insert(entry);
    final tx = await (_db.select(_db.transactions)
          ..where((t) => t.id.equals(id)))
        .getSingle();
    await _logs.add(LogAction.created, 'transaction', id,
        '${tx.type.label} ${tx.amountMinor}');
    return id;
  }

  Future<void> update(Tx tx) async {
    await (_db.update(_db.transactions)..where((t) => t.id.equals(tx.id)))
        .write(TransactionsCompanion(
      type: Value(tx.type),
      amountMinor: Value(tx.amountMinor),
      categoryId: Value(tx.categoryId),
      goalId: Value(tx.goalId),
      note: Value(tx.note),
      occurredAt: Value(tx.occurredAt),
    ));
    await _logs.add(LogAction.updated, 'transaction', tx.id,
        '${tx.type.label} ${tx.amountMinor}');
  }

  Future<void> delete(Tx tx) async {
    await (_db.delete(_db.transactions)..where((t) => t.id.equals(tx.id)))
        .go();
    await _logs.add(LogAction.deleted, 'transaction', tx.id,
        '${tx.type.label} ${tx.amountMinor}');
  }

  /// Re-inserts a previously deleted row with its original id (undo).
  Future<void> restore(Tx tx) async {
    await _db.into(_db.transactions).insert(TransactionsCompanion.insert(
          id: Value(tx.id),
          type: tx.type,
          amountMinor: tx.amountMinor,
          categoryId: Value(tx.categoryId),
          goalId: Value(tx.goalId),
          note: Value(tx.note),
          occurredAt: tx.occurredAt,
          createdAt: Value(tx.createdAt),
        ));
    await _logs.add(LogAction.created, 'transaction', tx.id,
        'restored ${tx.type.label} ${tx.amountMinor}');
  }

  /// Used by the recurring engine; logs a distinct "generated" action.
  Future<int> createGenerated(TransactionsCompanion entry) async {
    final id = await _db.into(_db.transactions).insert(entry);
    await _logs.add(LogAction.generated, 'transaction', id,
        '${entry.type.value.label} ${entry.amountMinor.value}');
    return id;
  }
}
