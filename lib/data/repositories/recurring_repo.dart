import 'package:drift/drift.dart';

import '../database.dart';
import '../../core/enums.dart';
import '../../core/format.dart';
import 'logs_repo.dart';
import 'transactions_repo.dart';

/// Recurring transaction templates + the engine that materializes due ones.
class RecurringRepo {
  RecurringRepo(this._db, this._logs, this._txRepo);

  final AppDatabase _db;
  final LogsRepo _logs;
  final TransactionsRepo _txRepo;

  Stream<List<RecurringTemplate>> watchAll() => (_db.select(
        _db.recurringTemplates,
      )
            ..orderBy([
              (r) => OrderingTerm.asc(r.nextDueAt),
            ]))
          .watch();

  Future<RecurringTemplate> byId(int id) =>
      (_db.select(_db.recurringTemplates)..where((r) => r.id.equals(id)))
          .getSingle();

  Future<int> create(RecurringTemplatesCompanion entry) async {
    final id = await _db.into(_db.recurringTemplates).insert(entry);
    await _logs.add(LogAction.created, 'recurring', id,
        '${entry.type.value.label} ${entry.amountMinor.value}');
    return id;
  }

  Future<void> updateTemplate(RecurringTemplate template) async {
    await (_db.update(_db.recurringTemplates)
          ..where((r) => r.id.equals(template.id)))
        .write(RecurringTemplatesCompanion(
      type: Value(template.type),
      amountMinor: Value(template.amountMinor),
      categoryId: Value(template.categoryId),
      goalId: Value(template.goalId),
      note: Value(template.note),
      frequency: Value(template.frequency),
      everyN: Value(template.everyN),
      nextDueAt: Value(template.nextDueAt),
      endAfter: Value(template.endAfter),
      active: Value(template.active),
    ));
    await _logs.add(LogAction.updated, 'recurring', template.id,
        '${template.type.label} ${template.amountMinor}');
  }

  Future<void> setActive(int id, bool active) =>
      (_db.update(_db.recurringTemplates)..where((r) => r.id.equals(id)))
          .write(RecurringTemplatesCompanion(active: Value(active)));

  Future<void> delete(int id) async {
    await (_db.delete(_db.recurringTemplates)
          ..where((r) => r.id.equals(id)))
        .go();
    await _logs.add(LogAction.deleted, 'recurring', id, '');
  }

  /// Generates transactions for every due occurrence of every active
  /// template. Returns how many were created. Idempotent: advances
  /// nextDueAt past [now] so nothing is generated twice.
  Future<int> processDue({DateTime? now}) async {
    final at = now ?? DateTime.now();
    var generated = 0;

    final due = await (_db.select(_db.recurringTemplates)
          ..where((r) =>
              r.active.equals(true) & r.nextDueAt.isSmallerOrEqualValue(at)))
        .get();

    for (final tpl in due) {
      var cursor = tpl.nextDueAt;
      while (!cursor.isAfter(at) &&
          (tpl.endAfter == null || !cursor.isAfter(tpl.endAfter!))) {
        await _txRepo.createGenerated(TransactionsCompanion.insert(
          type: tpl.type,
          amountMinor: tpl.amountMinor,
          categoryId: Value(tpl.categoryId),
          goalId: Value(tpl.goalId),
          note: Value(tpl.note ?? 'Recurring'),
          occurredAt: cursor,
        ));
        generated++;
        cursor = DateX.addPeriods(cursor, tpl.frequency, tpl.everyN);
      }
      await (_db.update(_db.recurringTemplates)
            ..where((r) => r.id.equals(tpl.id)))
          .write(RecurringTemplatesCompanion(
        nextDueAt: Value(cursor),
        lastRunAt: Value(at),
      ));
    }
    return generated;
  }
}
