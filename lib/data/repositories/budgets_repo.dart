import 'package:drift/drift.dart';

import '../database.dart';
import '../../core/enums.dart';
import '../../core/format.dart';
import 'logs_repo.dart';

/// One expense category joined with its monthly limit and live spend.
typedef BudgetRow = ({
  int categoryId,
  String name,
  String iconCode,
  int colorValue,
  int limitMinor,
  int spentMinor,
});

/// Monthly per-category spending limits.
class BudgetsRepo {
  BudgetsRepo(this._db, this._logs);

  final AppDatabase _db;
  final LogsRepo _logs;

  Future<List<Budget>> forMonth(String monthKey) =>
      (_db.select(_db.budgets)..where((b) => b.monthKey.equals(monthKey)))
          .get();

  /// All active expense categories for [monthAnchor] with optional limits
  /// and actual spend so far — one reactive query.
  Stream<List<BudgetRow>> watchMonthOverview(DateTime monthAnchor) {
    final key = DateX.monthKey(monthAnchor);
    final from = DateTime(monthAnchor.year, monthAnchor.month);
    final to = DateTime(monthAnchor.year, monthAnchor.month + 1);
    return _db.customSelect(
      'SELECT c.id AS cid, c.name AS name, c.icon_code AS icon_code, '
          'c.color_value AS color_value, '
          'COALESCE(b.limit_minor, 0) AS limit_minor, '
          'COALESCE((SELECT SUM(t.amount_minor) FROM transactions t '
          'WHERE t.category_id = c.id AND t.type = ? '
          'AND t.occurred_at >= ? AND t.occurred_at < ?), 0) AS spent '
          'FROM categories c '
          'LEFT JOIN budgets b ON b.category_id = c.id AND b.month_key = ? '
          'WHERE c.archived = 0 AND c.type = ? '
          'ORDER BY spent DESC',
      variables: [
        Variable.withInt(TxType.expense.index),
        Variable.withDateTime(from),
        Variable.withDateTime(to),
        Variable.withString(key),
        Variable.withInt(CategoryType.expense.index),
      ],
      readsFrom: {_db.categories, _db.budgets, _db.transactions},
    ).watch().map((rows) => [
          for (final row in rows)
            (
              categoryId: row.read<int>('cid'),
              name: row.read<String>('name'),
              iconCode: row.read<String>('icon_code'),
              colorValue: row.read<int>('color_value'),
              limitMinor: row.read<int>('limit_minor'),
              spentMinor: row.read<int>('spent'),
            ),
        ]);
  }

  Future<Budget?> forCategoryAndMonth(int categoryId, String monthKey) =>
      (_db.select(_db.budgets)
            ..where((b) =>
                b.categoryId.equals(categoryId) & b.monthKey.equals(monthKey)))
          .getSingleOrNull();

  /// Insert or update the limit for one category in one month.
  /// A non-positive [limitMinor] removes the budget row entirely.
  Future<void> upsert(int categoryId, DateTime monthAnchor, int limitMinor) {
    final key = DateX.monthKey(monthAnchor);
    if (limitMinor <= 0) {
      return (_db.delete(_db.budgets)
            ..where((b) => b.categoryId.equals(categoryId) & b.monthKey.equals(key)))
          .go();
    }
    return _db.into(_db.budgets).insertOnConflictUpdate(
          BudgetsCompanion.insert(
            categoryId: categoryId,
            monthKey: key,
            limitMinor: limitMinor,
          ),
        );
  }

  Future<void> delete(int id) async {
    await (_db.delete(_db.budgets)..where((b) => b.id.equals(id))).go();
    await _logs.add(LogAction.deleted, 'budget', id, '');
  }
}
