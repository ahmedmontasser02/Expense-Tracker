import 'dart:io';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../core/format.dart';
import '../../data/repositories/settings_repo.dart';
import '../../providers/providers.dart';
import '../../services/diagnostic_logger.dart';
import '../../services/notification_service.dart';
import '../../services/update_checker.dart';
import 'package:package_info_plus/package_info_plus.dart';
import '../onboarding/country_picker_screen.dart';
import '../recurring/recurring_screen.dart';
import '../rules/rules_screen.dart';
import '../widgets/common.dart';
/// Currency, alert thresholds, notification preferences and data tools.
enum _ManualUpdatePhase { confirm, downloading, error }

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});
  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}
class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  @override
  Widget build(BuildContext context) {
    final s = ref.watch(settingsMapProvider).value ?? {};
    if (s.isEmpty) {
      return Scaffold(
          appBar: AppBar(title: const Text('Settings')),
          body: const Center(child: CircularProgressIndicator()));
    }
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
        children: [
          SectionHeader('Appearance'),
          Card(
            margin: const EdgeInsets.only(bottom: 8),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Icon(Icons.brightness_6_outlined,
                        color: Theme.of(context).colorScheme.primary),
                    const SizedBox(width: 12),
                    Text('Theme',
                        style: Theme.of(context).textTheme.titleSmall),
                  ]),
                  const SizedBox(height: 12),
                  SegmentedButton<String>(
                    segments: const [
                      ButtonSegment(
                          value: 'system',
                          label: Text('System'),
                          icon: Icon(Icons.settings_suggest_outlined)),
                      ButtonSegment(
                          value: 'light',
                          label: Text('Light'),
                          icon: Icon(Icons.light_mode_outlined)),
                      ButtonSegment(
                          value: 'dark',
                          label: Text('Dark'),
                          icon: Icon(Icons.dark_mode_outlined)),
                    ],
                    selected: {
                      s[SettingsRepo.appearanceMode] ?? 'system'
                    },
                    onSelectionChanged: (sel) =>
                        _set(SettingsRepo.appearanceMode, sel.first),
                  ),
                ],
              ),
            ),
          ),
          SectionHeader('General'),
          ListTile(
            leading: Text(
              ref.watch(selectedCountryProvider)?.flag ?? '🌐',
              style: const TextStyle(fontSize: 26),
            ),
            title: const Text('Country'),
            subtitle: Text(
                ref.watch(selectedCountryProvider)?.name ?? 'Not selected'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.of(context).push(MaterialPageRoute(
              builder: (_) => const CountryPickerScreen(),
            )),
          ),
          ListTile(
            leading: const Icon(Icons.currency_exchange_outlined),
            title: const Text('Currency'),
            subtitle: Text(_currencyLabel(ref)),
            trailing: const Icon(Icons.edit_outlined, size: 18),
            onTap: () => _editSymbol(context, ref, s),
          ),
          ListTile(
            leading: const Icon(Icons.repeat),
            title: const Text('Recurring transactions'),
            subtitle: const Text('Manage automatic entries'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const RecurringScreen())),
          ),
          ListTile(
            leading: const Icon(Icons.auto_awesome_outlined),
            title: const Text('Auto-categorization rules'),
            subtitle: const Text('Categorize notes automatically'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const RulesScreen())),
          ),
          SectionHeader('Alert thresholds'),
          SwitchListTile(
            secondary: const Icon(Icons.notifications_outlined),
            title: const Text('Notifications'),
            subtitle: const Text('Low balance, savings and budget warnings'),
            value: s[SettingsRepo.notificationsEnabled] == 'true',
            onChanged: (v) => _set(SettingsRepo.notificationsEnabled, '$v'),
          ),
          _percentTile(context, 'Low balance (% of monthly income)',
              SettingsRepo.lowBalancePct, s),
          _moneyTile(context, 'Low balance absolute floor',
              SettingsRepo.lowBalanceFloorMinor, s),
          _moneyTile(context, 'Savings floor', SettingsRepo.savingsFloorMinor, s),
          _percentTile(context,
              'Budget warning at (% of category limit)', SettingsRepo.budgetWarnPct, s),
          _percentTile(context,
              'Monthly cap warning at (%)', SettingsRepo.monthCapWarnPct, s),
          _moneyTile(
              context,
              'Monthly spending cap (0 = off)',
              SettingsRepo.monthlyCapMinor,
              s),
          SectionHeader('Daily summary'),
          SwitchListTile(
            secondary: const Icon(Icons.today_outlined),
            title: const Text('Daily reminder'),
            subtitle: const Text('A once-a-day nudge with your numbers'),
            value: s[SettingsRepo.dailySummaryEnabled] == 'true',
            onChanged: (v) async {
              await _set(SettingsRepo.dailySummaryEnabled, '$v');
              if (mounted) await _rescheduleDaily(s);
            },
          ),
          _numberTile(
            context,
            title: 'Reminder hour (0–23)',
            current:
                int.tryParse(s[SettingsRepo.dailySummaryHour] ?? '20') ?? 20,
            onSave: (v) async {
              final h = v.clamp(0, 23);
              await _set(SettingsRepo.dailySummaryHour, '$h');
              await _rescheduleDaily({...s, SettingsRepo.dailySummaryHour: '$h'});
            },
          ),
          const SectionHeader('Data & backups'),
          SwitchListTile(
            secondary: const Icon(Icons.backup_outlined),
            title: const Text('Automatic daily backup'),
            subtitle: Text(
                'Keeps the last 7 backups on this device'
                '${s[SettingsRepo.lastBackupKey] != null && s[SettingsRepo.lastBackupKey]!.isNotEmpty ? ' • last: ${_prettyLastBackup(s[SettingsRepo.lastBackupKey]!)}' : ''}'),
            value: s[SettingsRepo.autoBackupKey] == 'true',
            onChanged: (v) => _set(SettingsRepo.autoBackupKey, '$v'),
          ),
          ListTile(
            leading: const Icon(Icons.cloud_sync_outlined),
            title: const Text('Back up now'),
            subtitle: const Text('Snapshot the database to device storage'),
            onTap: () => _backupNow(context),
          ),
          ListTile(
            leading: const Icon(Icons.restore_outlined),
            title: const Text('Restore from backup'),
            subtitle: const Text(
                'Replaces current data — restarts the app when done'),
            onTap: () => _restoreFlow(context),
          ),
          SectionHeader('App updates'),
          ListTile(
            leading: const Icon(Icons.system_update_outlined),
            title: const Text('Check for updates'),
            subtitle: const Text(
                'Looks for a newer release on GitHub and installs it'),
            trailing: _checkingUpdate
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.chevron_right),
            onTap: _checkingUpdate ? null : () => _checkUpdatesManually(context),
          ),
          SectionHeader('Diagnostics'),
          ListTile(
            leading: const Icon(Icons.bug_report_outlined),
            title: const Text('Export diagnostic logs'),
            subtitle: const Text(
                'Share a bug report with app info, errors and recent activity'),
            trailing: const Icon(Icons.ios_share),
            onTap: () => _exportLogs(context),
          ),
          ListTile(
            leading: const Icon(Icons.copy_outlined),
            title: const Text('Copy logs to clipboard'),
            subtitle: const Text('Paste into a bug report or message'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _copyLogs(context),
          ),
          SectionHeader('About'),
          const ListTile(
            leading: Icon(Icons.info_outline),
            title: Text('Expense Tracker'),
            subtitle:
                Text('Local-only expense, budget and savings tracker.\n'
                    'All data stays on this device.'),
            isThreeLine: true,
          ),
        ],
      ),
    );
  }
  Future<void> _set(String key, String value) =>
      ref.read(settingsRepoProvider).set(key, value);

  bool _checkingUpdate = false;
  double? _manualProgress;
  String? _manualError;

  Future<void> _checkUpdatesManually(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _checkingUpdate = true);
    try {
      await ref
          .read(settingsRepoProvider)
          .set(SettingsRepo.updateLastCheckedAt, DateTime.now().toIso8601String());
      final info = await UpdateChecker.instance.fetchLatest();
      final current = (await PackageInfo.fromPlatform()).version;
      if (!context.mounted) return;

      if (info == null) {
        messenger.showSnackBar(const SnackBar(
            content: Text('Could not reach GitHub — try again later')));
        return;
      }
      if (!UpdateChecker.isNewer(info.version, current)) {
        messenger.showSnackBar(SnackBar(
            content: Text('You are on the latest version (v$current)')));
        return;
      }
      if (!context.mounted) return;

      // Newer release available — offer download + install with progress.
      var phase = _ManualUpdatePhase.confirm;
      await showDialog<void>(
        context: context,
        builder: (ctx) => StatefulBuilder(
          builder: (ctx, setDialog) => AlertDialog(
            icon: const Icon(Icons.system_update_alt_outlined),
            title: Text('Update to v${info.version}'),
            content: switch (phase) {
              _ManualUpdatePhase.confirm => const Text(
                  'The new version will be downloaded and the installer '
                  'will open. Install it to finish updating.'),
              _ManualUpdatePhase.downloading => Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    LinearProgressIndicator(value: _manualProgress),
                    const SizedBox(height: 8),
                    Text(_manualProgress == null
                        ? 'Downloading…'
                        : 'Downloading… ${(_manualProgress! * 100).toStringAsFixed(0)}%'),
                  ],
                ),
              _ManualUpdatePhase.error => Text(_manualError ?? 'Download failed'),
            },
            actions: [
              if (phase == _ManualUpdatePhase.confirm)
                TextButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: const Text('Later')),
              if (phase == _ManualUpdatePhase.confirm)
                FilledButton(
                  onPressed: () async {
                    setDialog(() => phase = _ManualUpdatePhase.downloading);
                    try {
                      final path = await UpdateChecker.instance
                          .downloadApk(info.apkUrl,
                              onProgress: (received, total) {
                        if (total != null && total > 0) {
                          setDialog(() =>
                              _manualProgress = received / total);
                        }
                      });
                      await UpdateChecker.instance.install(path);
                    } catch (e) {
                      _manualError = '$e';
                      setDialog(() => phase = _ManualUpdatePhase.error);
                    }
                  },
                  child: const Text('Download & install'),
                ),
              if (phase == _ManualUpdatePhase.error)
                FilledButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: const Text('Close')),
            ],
          ),
        ),
      );
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('Update check failed: $e')));
    } finally {
      if (mounted) setState(() => _checkingUpdate = false);
    }
  }

  String _prettyLastBackup(String iso) {
    final d = DateTime.tryParse(iso);
    return d == null ? iso : DateX.prettyDateTime(d);
  }

  Future<void> _backupNow(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      final file = await ref.read(backupServiceProvider).backupNow();
      messenger.showSnackBar(SnackBar(
          content: Text('Backup saved: ${p.basename(file.path)}')));
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('Backup failed: $e')));
    }
  }

  Future<void> _restoreFlow(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Restore from backup?'),
        content: const Text(
            'Your current data will be replaced with the backup contents. '
            'A safety backup of the current state is made first. '
            'The app restarts after restoring.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Choose file')),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;

    final messenger = ScaffoldMessenger.of(context);
    final XFile? picked = await openFile();
    if (picked == null) return;
    try {
      // Copy out of the provider cache into app storage first.
      final tmpDir = await getTemporaryDirectory();
      final local = File(p.join(tmpDir.path, 'restore-incoming.db'));
      await picked.saveTo(local.path);
      await ref.read(backupServiceProvider).restore(local);
      if (!context.mounted) return;
      await showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Restore complete'),
          content: const Text('The app will now close. Please reopen it.'),
          actions: [
            FilledButton(
              onPressed: () => SystemNavigator.pop(),
              child: const Text('Close app'),
            ),
          ],
        ),
      );
    } catch (e) {
      messenger.showSnackBar(SnackBar(
          content: Text('Restore failed: $e')));
    }
  }
  Future<void> _exportLogs(BuildContext context) async {
    try {
      await DiagnosticLogger.instance
          .exportReport(ref.read(logsRepoProvider));
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Could not export logs: $e')));
    }
  }
  Future<void> _copyLogs(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      final report =
          await DiagnosticLogger.instance.collectReport(ref.read(logsRepoProvider));
      await Clipboard.setData(ClipboardData(text: report));
      messenger.showSnackBar(
          const SnackBar(content: Text('Logs copied to clipboard')));
    } catch (e) {
      messenger.showSnackBar(
          SnackBar(content: Text('Could not copy logs: $e')));
    }
  }
  String _currencyLabel(WidgetRef ref) {
    final map = ref.watch(settingsMapProvider).value ?? {};
    final code = map[SettingsRepo.currencyCode] ?? '';
    final symbol = map[SettingsRepo.currencySymbol] ?? r'$';
    return code.isEmpty ? symbol : '$code · $symbol';
  }
  Future<void> _editSymbol(
      BuildContext context, WidgetRef ref, Map<String, String> s) async {
    final ctrl =
        TextEditingController(text: s[SettingsRepo.currencySymbol] ?? r'$');
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Currency symbol'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          maxLength: 4,
          decoration: const InputDecoration(
              hintText: 'e.g. \$ , € , E£ , د.إ',
              helperText:
                  'Derived from your country; override here if needed.'),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Save')),
        ],
      ),
    );
    final value = ctrl.text.trim();
    WidgetsBinding.instance.addPostFrameCallback((_) => ctrl.dispose());
    if (ok == true && value.isNotEmpty) {
      await _set(SettingsRepo.currencySymbol, value);
      MoneyFmt.symbol = value;
    }
  }
  Future<void> _rescheduleDaily(Map<String, String> s) async {
    final enabled = s[SettingsRepo.dailySummaryEnabled] == 'true';
    final hour = int.tryParse(s[SettingsRepo.dailySummaryHour] ?? '20') ?? 20;
    if (!enabled) {
      await NotificationService.instance.cancelDailySummary();
      return;
    }
    final balance = ref.read(balanceProvider).value;
    final pot = ref.read(savingsPotProvider).value;
    final sym = ref.watch(currencySymbolProvider);
    await NotificationService.instance.scheduleDailySummary(
      hour,
      'Daily money check-in',
      'Balance: ${balance == null ? '—' : MoneyFmt.withSymbol(sym, balance)} • '
          'Savings: ${pot == null ? '—' : MoneyFmt.withSymbol(sym, pot)}',
    );
  }
  Widget _percentTile(
      BuildContext context, String title, String key, Map<String, String> s) {
    return ListTile(
      leading: const Icon(Icons.percent),
      title: Text(title),
      trailing: Text('${s[key] ?? '0'}%',
          style: Theme.of(context).textTheme.titleMedium),
      onTap: () => _prompt(context, title, s[key] ?? '',
          text: true,
          onSave: (v) => _set(key, '${int.tryParse(v)?.clamp(1, 100) ?? 100}')),
    );
  }
  Widget _moneyTile(BuildContext context, String title, String key,
      Map<String, String> s) {
    final minor = int.tryParse(s[key] ?? '0') ?? 0;
    return ListTile(
      leading: const Icon(Icons.payments_outlined),
      title: Text(title),
      trailing: Text(MoneyFmt.withSymbol(ref.watch(currencySymbolProvider), minor),
          style: Theme.of(context).textTheme.titleMedium),
      onTap: () => _prompt(context, title, minor == 0 ? '' : (minor / 100).toStringAsFixed(2),
          text: true,
          onSave: (v) => _set(key, '${MoneyFmt.parseToMinorUnits(v)}')),
    );
  }
  Widget _numberTile(BuildContext context,
      {required String title,
      required int current,
      required Future<void> Function(int) onSave}) {
    return ListTile(
      leading: const Icon(Icons.schedule),
      title: Text(title),
      trailing: Text('$current:00',
          style: Theme.of(context).textTheme.titleMedium),
      onTap: () => _prompt(context, title, '$current',
          text: true, onSave: (v) => onSave(int.tryParse(v) ?? current)),
    );
  }
  Future<void> _prompt(BuildContext context, String title, String initial,
      {required bool text, required Future<void> Function(String) onSave}) async {
    final ctrl = TextEditingController(text: initial);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          keyboardType: TextInputType.text,
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Save')),
        ],
      ),
    );
    final value = ctrl.text;
    WidgetsBinding.instance.addPostFrameCallback((_) => ctrl.dispose());
    if (ok == true) await onSave(value);
    if (mounted) setState(() {});
  }
}




