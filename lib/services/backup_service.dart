import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:sqlite3/sqlite3.dart' as sqlite3;

import '../data/database.dart';
import '../data/repositories/settings_repo.dart';

/// Local, device-only backups: copies of the (SQLCipher-encrypted) database
/// file plus a small JSON meta sidecar. Backups are only restorable on a
/// device sharing the same encryption key — for cross-device moves use
/// Settings → Data → CSV export/import.
class BackupService {
  BackupService(this._db, this._settings, this._encryptionKey);

  final AppDatabase _db;
  final SettingsRepo _settings;
  final String _encryptionKey;

  static const keepCount = 7;

  String get lastBackupKey => SettingsRepo.lastBackupKey;
  String get autoBackupKey => SettingsRepo.autoBackupKey;

  Future<Directory> backupDir() async {
    final docs = await getApplicationDocumentsDirectory();
    final dir = Directory(p.join(docs.path, 'ExpenseTrackerBackups'));
    if (!dir.existsSync()) dir.createSync(recursive: true);
    return dir;
  }

  Future<File> backupNow() async {
    final dir = await backupDir();
    final stamp = DateTime.now()
        .toIso8601String()
        .replaceAll(':', '-')
        .replaceAll('.', '-');
    final dbFile = await AppDatabase.databaseFile();

    // Checkpoint WAL so the copy is complete.
    await _db.customSelect('PRAGMA wal_checkpoint(FULL)').get();

    final backup = File(p.join(dir.path, 'backup-$stamp.db'));
    if (dbFile.existsSync()) dbFile.copySync(backup.path);

    final info = await PackageInfo.fromPlatform();
    File(p.join(dir.path, 'backup-$stamp.json')).writeAsStringSync(
      jsonEncode({
        'createdAt': DateTime.now().toIso8601String(),
        'appVersion': info.version,
        'schemaVersion': _db.schemaVersion,
        'encrypted': true,
      }),
    );

    await _pruneOldBackups(dir);
    await _settings.set(lastBackupKey, DateTime.now().toIso8601String());
    return backup;
  }

  /// Runs an automatic backup at most once every 24h when enabled.
  Future<void> autoBackupIfDue() async {
    if (!await _settings.getBool(autoBackupKey)) return;
    final last = DateTime.tryParse(await _settings.getString(lastBackupKey));
    final due = last == null ||
        DateTime.now().difference(last) > const Duration(hours: 24);
    if (due) await backupNow();
  }

  Future<List<BackupEntry>> listBackups() async {
    final dir = await backupDir();
    final entries = <BackupEntry>[];
    for (final f in dir.listSync().whereType<File>()) {
      if (!f.path.endsWith('.db')) continue;
      final meta = File(f.path.replaceFirst('.db', '.json'));
      DateTime createdAt = f.lastModifiedSync();
      String version = '';
      if (meta.existsSync()) {
        try {
          final j = jsonDecode(meta.readAsStringSync()) as Map<String, dynamic>;
          createdAt = DateTime.tryParse(j['createdAt'] as String? ?? '') ??
              createdAt;
          version = j['appVersion'] as String? ?? '';
        } catch (_) {}
      }
      entries.add(BackupEntry(f, createdAt, version,
          f.lengthSync()));
    }
    entries.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return entries;
  }

  Future<void> deleteBackup(BackupEntry entry) async {
    entry.file.deleteSync();
    final meta = File(entry.file.path.replaceFirst('.db', '.json'));
    if (meta.existsSync()) meta.deleteSync();
  }

  /// Restores a backup file. The database must be closed first — returns a
  /// callback that performs the swap, or throws when the file is invalid.
  Future<void> restore(File backup) async {
    // Validate: must open with our key and contain our tables.
    final dbFile = await AppDatabase.databaseFile();

    // Safety net: back up current state before overwriting.
    if (dbFile.existsSync()) await backupNow();

    final tmp = File('${dbFile.path}.restore');
    backup.copySync(tmp.path);

    // Sanity check happens after swap on next open; verify beforehand via
    // a throwaway connection using the same key setup as production.
    final raw = _openRawForCheck(tmp.path);
    raw.dispose();

    await _db.close();
    await tmp.rename(dbFile.path);
  }

  /// Opens a copy with the production key to prove it decrypts and
  /// contains the expected schema.
  sqlite3.Database _openRawForCheck(String path) {
    final db = sqlite3.sqlite3.open(path);
    try {
      db.execute("PRAGMA key = '${sqlQuoteLiteral(_encryptionKey)}'");
      db.select('SELECT count(*) FROM sqlite_master');
      final tables = db.select(
          "SELECT name FROM sqlite_master WHERE type='table' AND name='transactions'");
      if (tables.isEmpty) {
        throw Exception('Not an Expense Tracker backup');
      }
      return db;
    } catch (_) {
      db.dispose();
      rethrow;
    }
  }

  Future<void> _pruneOldBackups(Directory dir) async {
    final dbs = dir
        .listSync()
        .whereType<File>()
        .where((f) => f.path.endsWith('.db'))
        .toList()
      ..sort((a, b) => b.lastModifiedSync().compareTo(a.lastModifiedSync()));
    for (final old in dbs.skip(keepCount)) {
      await old.delete();
      final meta = File(old.path.replaceFirst('.db', '.json'));
      if (meta.existsSync()) meta.deleteSync();
    }
  }
}

class BackupEntry {
  const BackupEntry(this.file, this.createdAt, this.appVersion, this.sizeBytes);

  final File file;
  final DateTime createdAt;
  final String appVersion;
  final int sizeBytes;
}

