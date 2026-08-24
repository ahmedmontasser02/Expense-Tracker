import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// Checks GitHub Releases for a newer app version, downloads the APK and
/// hands it to the Android package installer.
class UpdateChecker {
  UpdateChecker._();

  static final instance = UpdateChecker._();

  static const _apiUrl =
      'https://api.github.com/repos/ahmedmontasser02/Expense-Tracker/releases/latest';

  /// Fetches the latest release; null when none/network error.
  Future<ReleaseInfo?> fetchLatest() async {
    try {
      final client = HttpClient();
      final req = await client.getUrl(Uri.parse(_apiUrl));
      req.headers.set(HttpHeaders.acceptHeader, 'application/vnd.github+json');
      final res = await req.close().timeout(const Duration(seconds: 15));
      if (res.statusCode != 200) {
        await res.drain<void>();
        client.close();
        return null;
      }
      final body = jsonDecode(await res.transform(utf8.decoder).join())
          as Map<String, dynamic>;
      client.close();

      final tag = (body['tag_name'] as String?) ?? '';
      if (tag.isEmpty) return null;
      final assets = (body['assets'] as List? ?? [])
          .whereType<Map<String, dynamic>>()
          .toList();
      final apk = assets.firstWhere(
        (a) => (a['name'] as String? ?? '').endsWith('.apk'),
        orElse: () => <String, dynamic>{},
      );
      final url = apk['browser_download_url'] as String?;
      if (url == null) return null;
      return ReleaseInfo(
        version: normalizeVersion(tag),
        tagName: tag,
        apkUrl: url,
        notes: (body['body'] as String? ?? '').trim(),
      );
    } catch (e) {
      debugPrint('update check failed: $e');
      return null;
    }
  }

  /// Strips a leading 'v' so tags compare against pubspec versions.
  static String normalizeVersion(String tag) =>
      tag.startsWith('v') || tag.startsWith('V') ? tag.substring(1) : tag;

  /// Returns -1 when [a] is older than [b], 0 when equal, 1 when newer.
  /// Non-numeric parts compare lexically; missing parts count as 0.
  /// Version parts are separated by dot, plus or hyphen characters.
  static int compareVersions(String a, String b) {
    final pa = a.split(RegExp(r'[.+\-]'));
    final pb = b.split(RegExp(r'[.+\-]'));
    final n = pa.length > pb.length ? pa.length : pb.length;
    for (var i = 0; i < n; i++) {
      final sa = i < pa.length ? pa[i] : '0';
      final sb = i < pb.length ? pb[i] : '0';
      final na = int.tryParse(sa);
      final nb = int.tryParse(sb);
      final c = na != null && nb != null
          ? na.compareTo(nb)
          : sa.compareTo(sb);
      if (c != 0) return c;
    }
    return 0;
  }

  static bool isNewer(String candidate, String current) =>
      compareVersions(candidate, current) > 0;

  /// Downloads the APK to the temp directory; returns the local path.
  Future<String> downloadApk(String url,
      {void Function(int received, int? total)? onProgress}) async {
    final client = HttpClient();
    final req = await client.getUrl(Uri.parse(url));
    final res = await req.close().timeout(const Duration(minutes: 5));
    if (res.statusCode != 200) {
      throw Exception('Download failed (HTTP ${res.statusCode})');
    }
    final dir = await getTemporaryDirectory();
    final file = File(p.join(dir.path, 'update.apk'));
    final sink = file.openWrite();
    final total = res.contentLength > 0 ? res.contentLength : null;
    var received = 0;
    await for (final chunk in res) {
      received += chunk.length;
      sink.add(chunk);
      onProgress?.call(received, total);
    }
    await sink.flush();
    await sink.close();
    client.close();
    return file.path;
  }

  /// Hands the APK to the Android installer.
  Future<void> install(String apkPath) async {
    final result = await OpenFilex.open(apkPath,
        type: 'application/vnd.android.package-archive');
    if (result.type != ResultType.done) {
      throw Exception('Installer error: ${result.message}');
    }
  }
}

class ReleaseInfo {
  const ReleaseInfo({
    required this.version,
    required this.tagName,
    required this.apkUrl,
    required this.notes,
  });

  final String version;
  final String tagName;
  final String apkUrl;
  final String notes;
}
