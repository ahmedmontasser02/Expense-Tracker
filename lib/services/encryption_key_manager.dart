import 'dart:math';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Manages the SQLCipher key for the app database.
/// The key is generated once, stored in the device secure storage, and
/// never leaves the device. Losing it means losing the database — which is
/// why [restore] flows only accept backups created on the same key.
class EncryptionKeyManager {
  EncryptionKeyManager._();

  static final instance = EncryptionKeyManager._();

  static const _storageKey = 'db.encryption_key';
  static const _storage = FlutterSecureStorage();

  static final _hex64 = RegExp(r'^[0-9a-f]{64}$');

  Future<String> getOrCreate() async {
    final existing = await _storage.read(key: _storageKey);
    // Only trust well-formed keys; anything else is regenerated so a
    // corrupted value can never reach a SQL PRAGMA/KEY statement.
    if (existing != null && _hex64.hasMatch(existing)) return existing;

    final rand = Random.secure();
    final key =
        List.generate(32, (_) => rand.nextInt(256).toRadixString(16).padLeft(2, '0'))
            .join();
    await _storage.write(key: _storageKey, value: key);
    return key;
  }

  Future<bool> hasKey() async =>
      (await _storage.read(key: _storageKey))?.isNotEmpty ?? false;
}

