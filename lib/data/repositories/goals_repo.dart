import 'package:drift/drift.dart';

import '../database.dart';
import '../../core/enums.dart';
import 'logs_repo.dart';

/// A goal joined with its saved-so-far total (deposits − withdrawals).
typedef GoalProgress = ({SavingsGoal goal, int savedMinor});

class GoalsRepo {
  GoalsRepo(this._db, this._logs);

  final AppDatabase _db;
  final LogsRepo _logs;

  /// Goals with computed progress; deposits count, withdrawals subtract.
  Stream<List<GoalProgress>> watchGoalsWithProgress(
      {bool includeArchived = false}) {
    final filter = includeArchived ? '' : 'WHERE g.archived = 0';
    return _db.customSelect(
      'SELECT g.id AS gid, g.name AS name, g.target_minor AS target_minor, '
          'g.deadline AS deadline, g.archived AS archived, '
          'g.created_at AS created_at, '
          'COALESCE(SUM(CASE WHEN t.type = ? THEN t.amount_minor '
          'WHEN t.type = ? THEN -t.amount_minor ELSE 0 END), 0) AS saved '
          'FROM savings_goals g LEFT JOIN transactions t ON t.goal_id = g.id '
          '$filter GROUP BY g.id ORDER BY g.created_at ASC',
      variables: [
        Variable.withInt(TxType.savingsDeposit.index),
        Variable.withInt(TxType.savingsWithdrawal.index),
      ],
      readsFrom: {_db.savingsGoals, _db.transactions},
    ).watch().map((rows) => [
          for (final row in rows)
            (
              goal: SavingsGoal(
                id: row.read<int>('gid'),
                name: row.read<String>('name'),
                targetMinor: row.read<int>('target_minor'),
                deadline: _fromUnix(row.readNullable<int>('deadline')),
                archived: row.read<bool>('archived'),
                createdAt: _fromUnix(row.read<int>('created_at'))!,
              ),
              savedMinor: row.read<int>('saved'),
            ),
        ]);
  }

  static DateTime? _fromUnix(int? seconds) =>
      seconds == null ? null : DateTime.fromMillisecondsSinceEpoch(seconds * 1000);

  Future<int> create(SavingsGoalsCompanion entry) async {
    final id = await _db.into(_db.savingsGoals).insert(entry);
    await _logs.add(LogAction.created, 'goal', id, entry.name.value);
    return id;
  }

  Future<void> update(SavingsGoal goal) async {
    await (_db.update(_db.savingsGoals)..where((g) => g.id.equals(goal.id)))
        .write(SavingsGoalsCompanion(
      name: Value(goal.name),
      targetMinor: Value(goal.targetMinor),
      deadline: Value(goal.deadline),
      archived: Value(goal.archived),
    ));
    await _logs.add(LogAction.updated, 'goal', goal.id, goal.name);
  }

  Future<void> delete(int id) async {
    await (_db.delete(_db.savingsGoals)..where((g) => g.id.equals(id))).go();
    await _logs.add(LogAction.deleted, 'goal', id, '');
  }
}
