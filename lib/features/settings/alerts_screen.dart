import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/format.dart';
import '../../core/theme.dart';
import '../../data/repositories/settings_repo.dart';
import '../../providers/providers.dart';
import '../../services/notification_service.dart';

/// Dedicated alerts + notifications settings.
/// Maps 1:1 to existing [SettingsRepo] keys — no data-model work.
class AlertsScreen extends ConsumerStatefulWidget {
  const AlertsScreen({super.key});

  @override
  ConsumerState<AlertsScreen> createState() => _AlertsScreenState();
}

class _AlertsScreenState extends ConsumerState<AlertsScreen> {
  late final TextEditingController _lowFloorCtrl;
  late final TextEditingController _lowPctCtrl;
  late final TextEditingController _savingsFloorCtrl;
  late final TextEditingController _monthlyCapCtrl;

  String _minorDisplay(String raw) {
    final minor = int.tryParse(raw) ?? 0;
    if (minor == 0) return '';
    if (minor % 100 == 0) return (minor ~/ 100).toString();
    return (minor / 100).toStringAsFixed(2);
  }

  @override
  void initState() {
    super.initState();
    final m = ref.read(settingsMapProvider).value ?? const <String, String>{};
    String withDef(String key) =>
        m[key] ?? SettingsRepo.defaults[key] ?? '';
    _lowFloorCtrl =
        TextEditingController(text: _minorDisplay(withDef(SettingsRepo.lowBalanceFloorMinor)));
    _lowPctCtrl =
        TextEditingController(text: withDef(SettingsRepo.lowBalancePct));
    _savingsFloorCtrl =
        TextEditingController(text: _minorDisplay(withDef(SettingsRepo.savingsFloorMinor)));
    _monthlyCapCtrl =
        TextEditingController(text: _minorDisplay(withDef(SettingsRepo.monthlyCapMinor)));
  }

  @override
  void dispose() {
    _lowFloorCtrl.dispose();
    _lowPctCtrl.dispose();
    _savingsFloorCtrl.dispose();
    _monthlyCapCtrl.dispose();
    super.dispose();
  }

  Future<void> _set(String key, String value) =>
      ref.read(settingsRepoProvider).set(key, value);

  void _commitMoney(TextEditingController ctrl, String key) {
    final t = ctrl.text.trim();
    if (t.isEmpty) {
      _set(key, '0');
      return;
    }
    _set(key, '${MoneyFmt.parseToMinorUnits(t)}');
  }

  void _commitPct(TextEditingController ctrl, String key) {
    final n = int.tryParse(ctrl.text.trim());
    if (n == null) return;
    _set(key, '${n.clamp(1, 100)}');
  }

  String _fmtHour(int h) {
    final t = TimeOfDay(hour: h, minute: 0);
    final h12 = t.hourOfPeriod == 0 ? 12 : t.hourOfPeriod;
    final suffix = t.period == DayPeriod.am ? 'AM' : 'PM';
    return '${h12.toString().padLeft(2, '0')}:00 $suffix';
  }

  Future<void> _pickHour(int current, Map<String, String> s) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: current, minute: 0),
      helpText: 'Delivery time',
    );
    if (picked == null || !mounted) return;
    final h = picked.hour;
    await _set(SettingsRepo.dailySummaryHour, '$h');
    await _reschedule({...s, SettingsRepo.dailySummaryHour: '$h'});
  }

  Future<void> _reschedule(Map<String, String> s) async {
    final enabled = s[SettingsRepo.dailySummaryEnabled] == 'true';
    final hour = int.tryParse(s[SettingsRepo.dailySummaryHour] ?? '20') ?? 20;
    if (!enabled) {
      await NotificationService.instance.cancelDailySummary();
      return;
    }
    final sym = ref.read(currencySymbolProvider);
    final bal = ref.read(balanceProvider).value;
    final pot = ref.read(savingsPotProvider).value;
    await NotificationService.instance.scheduleDailySummary(
      hour,
      'Daily money check-in',
      'Balance: ${bal == null ? '—' : MoneyFmt.withSymbol(sym, bal)} • '
          'Savings: ${pot == null ? '—' : MoneyFmt.withSymbol(sym, pot)}',
    );
  }

  @override
  Widget build(BuildContext context) {
    final sAsync = ref.watch(settingsMapProvider);
    final s = sAsync.value ?? <String, String>{};
    if (sAsync.isLoading && s.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('Alerts & notifications')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }
    // Slider values: always derive from map so a restore stream rebuilds them.
    final budgetPct =
        (int.tryParse(s[SettingsRepo.budgetWarnPct] ?? '') ??
                int.tryParse(SettingsRepo.defaults[SettingsRepo.budgetWarnPct]!) ??
                80)
            .clamp(10, 100);
    final capWarnPct =
        (int.tryParse(s[SettingsRepo.monthCapWarnPct] ?? '') ??
                int.tryParse(SettingsRepo.defaults[SettingsRepo.monthCapWarnPct]!) ??
                90)
            .clamp(10, 100);
    final dailyOn = s[SettingsRepo.dailySummaryEnabled] == 'true' ||
        (s.isEmpty && SettingsRepo.defaults[SettingsRepo.dailySummaryEnabled] == 'true');
    final masterOn = (s[SettingsRepo.notificationsEnabled] ??
            SettingsRepo.defaults[SettingsRepo.notificationsEnabled]!) ==
        'true';
    final hour =
        int.tryParse(s[SettingsRepo.dailySummaryHour] ?? '20') ?? 20;

    return Scaffold(
      appBar: AppBar(title: const Text('Alerts & notifications')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        children: [
          Text(
            'Configure your vigilance settings. Ensure you are notified of critical '
            'thresholds while minimizing daily noise.',
            style: Theme.of(context)
                .textTheme
                .bodyMedium
                ?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
          ),
          const SizedBox(height: 16),
          _AlertCard(
            icon: Icons.notifications_active_outlined,
            accent: Theme.of(context).colorScheme.primary,
            title: 'Master Alerts',
            subtitle: 'Enable or disable all notifications system-wide.',
            trailing: Switch(
              value: masterOn,
              onChanged: (v) => _set(SettingsRepo.notificationsEnabled, '$v'),
            ),
          ),
          _AlertCard(
            icon: Icons.account_balance_wallet_outlined,
            accent: AppTheme.expenseColor(context),
            title: 'Low Balance',
            subtitle: 'Trigger alerts when primary account drops.',
            children: [
              _FieldLabel(text: 'ABSOLUTE FLOOR (\$)', context: context),
              TextField(
                controller: _lowFloorCtrl,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(
                  prefixText: '\$ ',
                  hintText: '0.00',
                ),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}')),
                ],
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => _commitMoney(
                    _lowFloorCtrl, SettingsRepo.lowBalanceFloorMinor),
                onEditingComplete: () => _commitMoney(
                    _lowFloorCtrl, SettingsRepo.lowBalanceFloorMinor),
                onTapOutside: (_) => _commitMoney(
                    _lowFloorCtrl, SettingsRepo.lowBalanceFloorMinor),
              ),
              _FieldLabel(text: 'PERCENTAGE DROP (%)', context: context),
              TextField(
                controller: _lowPctCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(suffixText: '%'),
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                ],
                textInputAction: TextInputAction.done,
                onSubmitted: (_) =>
                    _commitPct(_lowPctCtrl, SettingsRepo.lowBalancePct),
                onEditingComplete: () =>
                    _commitPct(_lowPctCtrl, SettingsRepo.lowBalancePct),
                onTapOutside: (_) =>
                    _commitPct(_lowPctCtrl, SettingsRepo.lowBalancePct),
              ),
            ],
          ),
          _AlertCard(
            icon: Icons.savings_outlined,
            accent: AppTheme.savingsColor(context),
            title: 'Goals & Budgets',
            subtitle: 'Monitor savings integrity and spending caps.',
            children: [
              _FieldLabel(text: 'SAVINGS FLOOR (\$)', context: context),
              TextField(
                controller: _savingsFloorCtrl,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  prefixText: '\$ ',
                  hintText: '0.00',
                ),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}')),
                ],
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => _commitMoney(
                    _savingsFloorCtrl, SettingsRepo.savingsFloorMinor),
                onEditingComplete: () => _commitMoney(
                    _savingsFloorCtrl, SettingsRepo.savingsFloorMinor),
                onTapOutside: (_) => _commitMoney(
                    _savingsFloorCtrl, SettingsRepo.savingsFloorMinor),
              ),
              _FieldLabel(text: 'BUDGET WARNING (%)', context: context),
              Row(
                children: [
                  Expanded(
                    child: Slider(
                      value: budgetPct.toDouble(),
                      min: 10,
                      max: 100,
                      divisions: 18,
                      label: '$budgetPct%',
                      onChanged: (v) =>
                          _set(SettingsRepo.budgetWarnPct, '${v.round()}'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  SizedBox(
                    width: 52,
                    child: Text('$budgetPct%',
                        textAlign: TextAlign.end,
                        style: Theme.of(context)
                            .textTheme
                            .titleMedium
                            ?.copyWith(fontWeight: FontWeight.w700)),
                  ),
                ],
              ),
            ],
          ),
          _AlertCard(
            icon: Icons.trending_up,
            accent: AppTheme.incomeColor(context),
            title: 'Monthly Spending Cap',
            subtitle: 'Hard limit alert across all variable categories.',
            children: [
              _FieldLabel(text: 'MONTHLY LIMIT (0 = OFF)', context: context),
              TextField(
                controller: _monthlyCapCtrl,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  prefixText: '\$ ',
                  hintText: '0.00',
                ),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}')),
                ],
                textInputAction: TextInputAction.done,
                onSubmitted: (_) =>
                    _commitMoney(_monthlyCapCtrl, SettingsRepo.monthlyCapMinor),
                onEditingComplete: () =>
                    _commitMoney(_monthlyCapCtrl, SettingsRepo.monthlyCapMinor),
                onTapOutside: (_) =>
                    _commitMoney(_monthlyCapCtrl, SettingsRepo.monthlyCapMinor),
              ),
              _FieldLabel(text: 'CAP WARNING (%)', context: context),
              Row(
                children: [
                  Expanded(
                    child: Slider(
                      value: capWarnPct.toDouble(),
                      min: 10,
                      max: 100,
                      divisions: 18,
                      label: '$capWarnPct%',
                      onChanged: (v) => _set(
                          SettingsRepo.monthCapWarnPct, '${v.round()}'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  SizedBox(
                    width: 52,
                    child: Text('$capWarnPct%',
                        textAlign: TextAlign.end,
                        style: Theme.of(context)
                            .textTheme
                            .titleMedium
                            ?.copyWith(fontWeight: FontWeight.w700)),
                  ),
                ],
              ),
            ],
          ),
          _AlertCard(
            icon: Icons.calendar_today_outlined,
            accent: Theme.of(context).colorScheme.primary,
            title: 'Daily Digest',
            subtitle:
                "Receive a consolidated brief of yesterday's activity.",
            trailing: Switch(
              value: dailyOn,
              onChanged: (v) async {
                await _set(SettingsRepo.dailySummaryEnabled, '$v');
                if (mounted) {
                  await _reschedule(
                      {...s, SettingsRepo.dailySummaryEnabled: '$v'});
                }
              },
            ),
            children: [
              const Divider(height: 24),
              Row(
                children: [
                  Text('DELIVERY TIME',
                      style: AppTheme.labelCaps(context)),
                  const Spacer(),
                  OutlinedButton.icon(
                    onPressed: () => _pickHour(hour, s),
                    icon: const Icon(Icons.schedule, size: 16),
                    label: Text(_fmtHour(hour)),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 20),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Done'),
          ),
        ],
      ),
    );
  }
}

class _FieldLabel extends StatelessWidget {
  const _FieldLabel({required this.text, required this.context});
  final String text;
  final BuildContext context;
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 12, bottom: 6),
      child: Text(text, style: AppTheme.labelCaps(context)),
    );
  }
}

class _AlertCard extends StatelessWidget {
  const _AlertCard({
    required this.icon,
    required this.accent,
    required this.title,
    required this.subtitle,
    this.trailing,
    this.children = const [],
  });

  final IconData icon;
  final Color accent;
  final String title;
  final String subtitle;
  final Widget? trailing;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: .14),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, size: 18, color: accent),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title,
                          style: Theme.of(context)
                              .textTheme
                              .titleSmall
                              ?.copyWith(fontWeight: FontWeight.w700)),
                      const SizedBox(height: 2),
                      Text(subtitle,
                          style: Theme.of(context)
                              .textTheme
                              .bodySmall
                              ?.copyWith(
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onSurfaceVariant)),
                    ],
                  ),
                ),
                if (trailing != null) ...[
                  const SizedBox(width: 8),
                  trailing!,
                ],
              ],
            ),
            if (children.isNotEmpty) ...[
              const Divider(height: 24),
              ...children,
            ],
          ],
        ),
      ),
    );
  }
}
