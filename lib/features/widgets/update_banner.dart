import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../../core/constants.dart';
import '../../data/repositories/settings_repo.dart';
import '../../providers/providers.dart';
import '../../services/update_checker.dart';

enum _UpdatePhase { checking, available, downloading, upToDate }

/// Self-contained banner shown on the dashboard when a newer GitHub
/// release exists. Checks at most once per 24h (and remembers skips).
class UpdateBanner extends ConsumerStatefulWidget {
  const UpdateBanner({super.key});

  @override
  ConsumerState<UpdateBanner> createState() => _UpdateBannerState();
}

class _UpdateBannerState extends ConsumerState<UpdateBanner> {
  _UpdatePhase _phase = _UpdatePhase.checking;
  ReleaseInfo? _info;
  double? _progress;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkIfDue());
  }

  Future<void> _checkIfDue() async {
    // Never let update checking break the app (e.g. platform channels are
    // unavailable in widget tests, or offline).
    try {
      if (isDevBuild) {
        setState(() => _phase = _UpdatePhase.upToDate);
        return;
      }
      final settings = ref.read(settingsRepoProvider);
      final last = DateTime.tryParse(
          await settings.getString(SettingsRepo.updateLastCheckedAt));
      if (last != null &&
          DateTime.now().difference(last) < const Duration(hours: 24)) {
        // Skip the network call, but keep any previously found update visible.
        if (!mounted) return;
        setState(() => _phase = _UpdatePhase.upToDate);
        return;
      }
      await _check();
    } catch (_) {
      if (mounted) setState(() => _phase = _UpdatePhase.upToDate);
    }
  }

  Future<void> _check() async {
    setState(() {
      _phase = _UpdatePhase.checking;
      _error = null;
    });
    await ref
        .read(settingsRepoProvider)
        .set(SettingsRepo.updateLastCheckedAt, DateTime.now().toIso8601String());

    final info = await UpdateChecker.instance.fetchLatest();
    final current = (await PackageInfo.fromPlatform()).version;
    if (!mounted) return;
    if (info == null || !UpdateChecker.isNewer(info.version, current)) {
      setState(() => _phase = _UpdatePhase.upToDate);
      return;
    }
    final skipped =
        await ref.read(settingsRepoProvider).getString(
            SettingsRepo.updateSkippedVersion);
    if (skipped == info.version) {
      setState(() => _phase = _UpdatePhase.upToDate);
      return;
    }
    setState(() {
      _info = info;
      _phase = _UpdatePhase.available;
    });
  }

  Future<void> _downloadAndInstall() async {
    final info = _info;
    if (info == null) return;
    setState(() => _phase = _UpdatePhase.downloading);
    try {
      final path = await UpdateChecker.instance.downloadApk(info.apkUrl,
          onProgress: (received, total) {
        if (!mounted || total == null) return;
        setState(() => _progress = received / total);
      });
      await UpdateChecker.instance.install(path);
      if (mounted) setState(() => _phase = _UpdatePhase.available);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = '$e';
        _phase = _UpdatePhase.available;
      });
    }
  }

  Future<void> _skip() async {
    final info = _info;
    if (info != null) {
      await ref
          .read(settingsRepoProvider)
          .set(SettingsRepo.updateSkippedVersion, info.version);
    }
    if (mounted) setState(() => _phase = _UpdatePhase.upToDate);
  }

  @override
  Widget build(BuildContext context) {
    switch (_phase) {
      case _UpdatePhase.checking:
      case _UpdatePhase.upToDate:
        return const SizedBox.shrink();
      case _UpdatePhase.available:
        return Card(
          color: Theme.of(context).colorScheme.tertiaryContainer,
          margin: const EdgeInsets.only(bottom: 12),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 12, 12),
            child: Row(children: [
              const Icon(Icons.system_update_outlined),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Update available: v${_info!.version}',
                        style: Theme.of(context)
                            .textTheme
                            .titleSmall
                            ?.copyWith(fontWeight: FontWeight.bold)),
                    if (_error != null)
                      Text(_error!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.bodySmall),
                  ],
                ),
              ),
              TextButton(onPressed: _skip, child: const Text('Skip')),
              FilledButton.tonal(
                  onPressed: _downloadAndInstall,
                  child: const Text('Update')),
            ]),
          ),
        );
      case _UpdatePhase.downloading:
        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(children: [
              Row(children: [
                const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2)),
                const SizedBox(width: 12),
                Text('Downloading update…',
                    style: Theme.of(context).textTheme.bodyMedium),
              ]),
              const SizedBox(height: 10),
              LinearProgressIndicator(value: _progress ?? 0),
            ]),
          ),
        );
    }
  }
}
