import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../data/repositories/logs_repo.dart';

/// Lightweight diagnostics: captures uncaught Flutter/platform errors to an
/// in-memory ring buffer AND an append-only file, and can assemble a full
/// bug report (device/app info + errors + activity log) for sharing.
class DiagnosticLogger {
  DiagnosticLogger._();

  static final instance = DiagnosticLogger._();

  static const _fileName = 'app_diagnostics.log';
  static const _maxFileBytes = 256 * 1024;
  static const _maxMemoryEntries = 200;

  final _buffer = <_Entry>[];
  File? _file;
  PackageInfo? _info;

  Future<void> init() async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      _file = File(p.join(dir.path, _fileName));
      _info = await PackageInfo.fromPlatform();
    } catch (e) {
      debugPrint('diagnostic logger init failed: $e');
    }
  }

  void record(String source, Object error, [StackTrace? stack]) {
    final entry = _Entry(DateTime.now(), source, error.toString(),
        _firstLines(stack, 6));
    _buffer.add(entry);
    if (_buffer.length > _maxMemoryEntries) _buffer.removeAt(0);
    _append(entry);
  }

  void info(String message) {
    final entry = _Entry(DateTime.now(), 'info', message, null);
    _buffer.add(entry);
    if (_buffer.length > _maxMemoryEntries) _buffer.removeAt(0);
    _append(entry);
  }

  Future<void> _append(_Entry e) async {
    final file = _file;
    if (file == null) return;
    try {
      if (await file.exists() && await file.length() > _maxFileBytes) {
        // Keep the most recent half.
        final lines = await file.readAsLines();
        await file.writeAsString(lines.skip(lines.length ~/ 2).join('\n'));
      }
      await file.writeAsString('${e.format()}\n',
          mode: FileMode.append, flush: false);
    } catch (_) {
      // Never let diagnostics break the app.
    }
  }

  /// Full bug report text: environment + recent errors + activity log.
  Future<String> collectReport(LogsRepo logs) async {
    final sb = StringBuffer()
      ..writeln('=== Expense Tracker diagnostics ===')
      ..writeln('Generated: ${DateTime.now().toIso8601String()}')
      ..writeln(
          'App: ${_info?.appName ?? '?'} ${_info?.version}+${_info?.buildNumber}')
      ..writeln('Platform: ${defaultTargetPlatform.name}')
      ..writeln();

    sb.writeln('--- Recent errors (newest last) ---');
    if (_buffer.isEmpty) {
      sb.writeln('(none captured this session)');
    } else {
      for (final e in _buffer) {
        sb.writeln(e.format());
      }
    }
    sb.writeln();

    try {
      final activity = await logs.watchRecent(limit: 100).first;
      sb.writeln('--- Last ${activity.length} activity entries ---');
      for (final l in activity.reversed) {
        sb.writeln(
            '${l.at.toIso8601String()} ${l.action.name} ${l.entityType} ${l.details}');
      }
    } catch (e) {
      sb.writeln('(activity log unavailable: $e)');
    }
    return sb.toString();
  }

  /// Writes the report to a timestamped file and opens the share sheet.
  Future<void> exportReport(LogsRepo logs) async {
    final report = await collectReport(logs);
    final dir = await getTemporaryDirectory();
    final stamp = DateTime.now().toIso8601String().replaceAll(':', '-');
    final file = File(p.join(dir.path, 'expense_tracker_logs_$stamp.txt'));
    await file.writeAsString(report);
    await SharePlus.instance.share(ShareParams(
      files: [XFile(file.path)],
      text: 'Expense Tracker diagnostic logs',
    ));
  }

  static String _firstLines(StackTrace? stack, int max) {
    if (stack == null) return '';
    return stack
        .toString()
        .split('\n')
        .take(max)
        .join('\n');
  }
}

class _Entry {
  const _Entry(this.at, this.source, this.message, this.stack);

  final DateTime at;
  final String source;
  final String message;
  final String? stack;

  String format() {
    final s = stack == null || stack!.isEmpty ? '' : '\n$stack';
    return '[${at.toIso8601String()}] $source: $message$s';
  }
}

