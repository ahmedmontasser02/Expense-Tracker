import 'package:drift/drift.dart';

import '../database.dart';
import '../../core/enums.dart';
import 'logs_repo.dart';

class CategoriesRepo {
  CategoriesRepo(this._db, this._logs);

  final AppDatabase _db;
  final LogsRepo _logs;

  Stream<List<Category>> watchAll({CategoryType? type, bool includeArchived = false}) {
    final q = _db.select(_db.categories)
      ..orderBy([(c) => OrderingTerm.asc(c.name)]);
    if (type != null) q.where((c) => c.type.equalsValue(type));
    if (!includeArchived) q.where((c) => c.archived.equals(false));
    return q.watch();
  }

  Future<Category> byId(int id) =>
      (_db.select(_db.categories)..where((c) => c.id.equals(id))).getSingle();

  Future<int> create(CategoriesCompanion entry) async {
    final id = await _db.into(_db.categories).insert(entry);
    await _logs.add(LogAction.created, 'category', id, entry.name.value);
    return id;
  }

  Future<void> update(Category category) async {
    await (_db.update(_db.categories)..where((c) => c.id.equals(category.id)))
        .write(CategoriesCompanion(
      name: Value(category.name),
      iconCode: Value(category.iconCode),
      colorValue: Value(category.colorValue),
      archived: Value(category.archived),
    ));
    await _logs.add(LogAction.updated, 'category', category.id, category.name);
  }

  /// Soft delete: archive so historical transactions keep their meaning.
  Future<void> archive(Category category) async {
    final updated = Category(
      id: category.id,
      name: category.name,
      type: category.type,
      iconCode: category.iconCode,
      colorValue: category.colorValue,
      archived: true,
    );
    await update(updated);
  }

  Future<void> restore(int id) => (_db.update(_db.categories)
            ..where((c) => c.id.equals(id)))
      .write(const CategoriesCompanion(archived: Value(false)));
}
