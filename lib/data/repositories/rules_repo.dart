import 'package:drift/drift.dart';

import '../database.dart';

/// User-defined auto-categorization rules + history-learned suggestions.
class RulesRepo {
  RulesRepo(this._db);

  final AppDatabase _db;

  Stream<List<Rule>> watchAll() => (_db.select(_db.rules)
        ..orderBy([(r) => OrderingTerm.desc(r.priority),
          (r) => OrderingTerm.asc(r.id)]))
      .watch();

  Future<List<Rule>> all() => _db.select(_db.rules).get();

  Future<int> create(RulesCompanion entry) =>
      _db.into(_db.rules).insert(entry);

  Future<void> update(Rule rule) => (_db.update(_db.rules)
        ..where((r) => r.id.equals(rule.id)))
      .write(RulesCompanion(
        pattern: Value(rule.pattern),
        categoryId: Value(rule.categoryId),
        priority: Value(rule.priority),
        enabled: Value(rule.enabled),
      ));

  Future<void> delete(int id) =>
      (_db.delete(_db.rules)..where((r) => r.id.equals(id))).go();

  Future<void> setEnabled(int id, bool enabled) =>
      (_db.update(_db.rules)..where((r) => r.id.equals(id)))
          .write(RulesCompanion(enabled: Value(enabled)));

  /// First matching enabled rule for [note]: pattern contained
  /// case-insensitively; highest priority wins, then oldest rule.
  Future<int?> matchCategory(String? note) async {
    if (note == null || note.trim().isEmpty) return null;
    final needle = note.trim().toLowerCase();
    final rules = await (_db.select(_db.rules)
          ..where((r) => r.enabled.equals(true))
          ..orderBy([
            (r) => OrderingTerm.desc(r.priority),
            (r) => OrderingTerm.asc(r.id),
          ]))
        .get();
    for (final rule in rules) {
      if (needle.contains(rule.pattern.toLowerCase())) {
        return rule.categoryId;
      }
    }
    return null;
  }

  /// Learned suggestion: the category most often used by past transactions
  /// whose notes contain the longest token of the new note (>= 3 chars).
  Future<int?> suggestCategory(String? note) async {
    if (note == null) return null;
    final tokens = note
        .toLowerCase()
        .replaceAll(RegExp(r'[^\p{L}\p{N} ]', unicode: true), ' ')
        .split(RegExp(r'\s+'))
        .where((t) => t.length >= 3)
        .toList()
      ..sort((a, b) => b.length.compareTo(a.length));
    for (final token in tokens) {
      final rows = await _db.customSelect(
        "SELECT category_id FROM transactions "
        "WHERE category_id IS NOT NULL AND note LIKE ? "
        "GROUP BY category_id ORDER BY COUNT(*) DESC LIMIT 1",
        variables: [Variable.withString('%$token%')],
        readsFrom: {_db.transactions},
      ).get();
      if (rows.isNotEmpty) return rows.first.readNullable<int>('category_id');
    }
    return null;
  }
}

