import 'package:drift/drift.dart';

import '../database.dart';

/// Tag CRUD + attachment of tags to transactions.
class TagsRepo {
  TagsRepo(this._db);

  final AppDatabase _db;

  Stream<List<Tag>> watchAll() =>
      (_db.select(_db.tags)..orderBy([(t) => OrderingTerm.asc(t.name)]))
          .watch();

  Future<List<Tag>> all() => _db.select(_db.tags).get();

  /// Returns the tag id, creating the tag when the name is new
  /// (case-insensitive match).
  Future<int> getOrCreate(String name) async {
    final clean = name.trim();
    if (clean.isEmpty) throw ArgumentError('Tag name is empty');
    final existing = await (_db.select(_db.tags)
          ..where((t) => t.name.lower().equals(clean.toLowerCase())))
        .getSingleOrNull();
    if (existing != null) return existing.id;
    final id = await _db.into(_db.tags).insert(
          TagsCompanion.insert(name: clean),
        );
    return id;
  }

  Future<void> rename(int id, String name) =>
      (_db.update(_db.tags)..where((t) => t.id.equals(id)))
          .write(TagsCompanion(name: Value(name.trim())));

  /// Deletes the tag; join rows cascade manually (no FK action defined).
  Future<void> delete(int id) async {
    await (_db.delete(_db.transactionTags)..where((j) => j.tagId.equals(id)))
        .go();
    await (_db.delete(_db.tags)..where((t) => t.id.equals(id))).go();
  }

  Future<void> setTagsForTx(int txId, List<int> tagIds) async {
    await _db.transaction(() async {
      await (_db.delete(_db.transactionTags)
            ..where((j) => j.txId.equals(txId)))
          .go();
      for (final tagId in tagIds) {
        await _db.into(_db.transactionTags).insert(
              TransactionTagsCompanion.insert(txId: txId, tagId: tagId),
            );
      }
    });
  }

  Future<List<Tag>> tagsForTx(int txId) async {
    final query = _db.select(_db.transactionTags).join([
      innerJoin(_db.tags, _db.tags.id.equalsExp(_db.transactionTags.tagId)),
    ])
      ..where(_db.transactionTags.txId.equals(txId));
    final rows = await query.get();
    return rows.map((r) => r.readTable(_db.tags)).toList();
  }

  Stream<List<Tag>> watchTagsForTx(int txId) {
    final query = _db.select(_db.transactionTags).join([
      innerJoin(_db.tags, _db.tags.id.equalsExp(_db.transactionTags.tagId)),
    ])
      ..where(_db.transactionTags.txId.equals(txId));
    return query.watch().map(
        (rows) => rows.map((r) => r.readTable(_db.tags)).toList());
  }
}
