import 'package:drift/drift.dart';

import '../database.dart';
import '../../core/enums.dart';

/// Append-mostly activity log powering the Logs screen.
class LogsRepo {
  LogsRepo(this._db);

  final AppDatabase _db;

  Future<void> add(LogAction action, String entityType, int? entityId,
      String details) {
    return _db.into(_db.activityLogs).insert(ActivityLogsCompanion.insert(
          action: action,
          entityType: entityType,
          entityId: Value(entityId),
          details: Value(details),
        ));
  }

  Stream<List<ActivityLog>> watchRecent({int limit = 300}) {
    return (_db.select(_db.activityLogs)
          ..orderBy([(l) => OrderingTerm.desc(l.at)])
          ..limit(limit))
        .watch();
  }

  Future<void> clear() => _db.delete(_db.activityLogs).go();
}
