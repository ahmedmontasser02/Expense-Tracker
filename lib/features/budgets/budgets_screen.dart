import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/format.dart';

import '../../data/repositories/budgets_repo.dart';
import '../../providers/providers.dart';
import '../widgets/common.dart';

/// Monthly per-category budgets with live progress.
class BudgetsScreen extends ConsumerStatefulWidget {
  const BudgetsScreen({super.key});

  @override
  ConsumerState<BudgetsScreen> createState() => _BudgetsScreenState();
}

class _BudgetsScreenState extends ConsumerState<BudgetsScreen> {
  late DateTime _anchor = DateX.startOfMonth(DateTime.now());

  @override
  Widget build(BuildContext context) {
    final rows = ref.watch(budgetOverviewFamily(_anchor)).value ?? [];
    final sym = ref.watch(currencySymbolProvider);
    final withBudget = rows.where((r) => r.limitMinor > 0).toList();
    final totalLimit =
        withBudget.fold(0, (a, r) => a + r.limitMinor);
    final totalSpent = withBudget.fold(0, (a, r) => a + r.spentMinor);

    return Scaffold(
      appBar: AppBar(title: const Text('Monthly Budgets')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            IconButton(
                onPressed: () =>
                    setState(() => _anchor = DateTime(_anchor.year, _anchor.month - 1)),
                icon: const Icon(Icons.chevron_left)),
            Text(
                '${DateX.monthName(_anchor.month)} ${_anchor.year}',
                style: Theme.of(context).textTheme.titleMedium),
            IconButton(
                onPressed: () =>
                    setState(() => _anchor = DateTime(_anchor.year, _anchor.month + 1)),
                icon: const Icon(Icons.chevron_right)),
          ]),
          if (withBudget.isNotEmpty) ...[
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(children: [
                  Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Total budgeted',
                            style: Theme.of(context).textTheme.bodyMedium),
                        Text(fmtAmount(sym, totalSpent),
                            style: const TextStyle(fontWeight: FontWeight.bold)),
                        Text('/ ${fmtAmount(sym, totalLimit)}',
                            style: Theme.of(context).textTheme.bodySmall),
                      ]),
                  const SizedBox(height: 8),
                  FillBar(
                    fraction:
                        totalLimit == 0 ? 0 : totalSpent / totalLimit,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ]),
              ),
            ),
          ],
          const SectionHeader('Categories'),
          if (rows.isEmpty)
            const EmptyState('No expense categories yet'),
          for (final row in rows)
            Card(
              margin: const EdgeInsets.symmetric(vertical: 4),
              child: InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: () => _editLimit(context, ref, row),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(children: [
                    Row(children: [
                      CategoryIcon(
                          iconCode: row.iconCode,
                          colorValue: row.colorValue,
                          size: 32),
                      const SizedBox(width: 10),
                      Expanded(child: Text(row.name)),
                      Text(row.limitMinor == 0
                          ? 'Set budget'
                          : '${fmtAmount(sym, row.spentMinor)} / ${fmtAmount(sym, row.limitMinor)}',
                          style: TextStyle(
                              fontSize: 13,
                              color: row.spentMinor > row.limitMinor && row.limitMinor > 0
                                  ? Colors.red
                                  : null,
                              fontWeight: FontWeight.w600)),
                      const SizedBox(width: 4),
                      const Icon(Icons.edit_outlined, size: 16),
                    ]),
                    if (row.limitMinor > 0) ...[
                      const SizedBox(height: 8),
                      FillBar(
                        fraction: row.limitMinor == 0
                            ? 0
                            : row.spentMinor / row.limitMinor,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ],
                  ]),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _editLimit(
      BuildContext context, WidgetRef ref, BudgetRow row) async {
    final ctrl = TextEditingController(
        text: row.limitMinor == 0 ? '' : (row.limitMinor / 100).toStringAsFixed(2));
    final result = await showDialog<int>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('${row.name} — monthly limit'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          keyboardType:
              const TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(
              prefixText: '${ref.read(currencySymbolProvider)} '),
        ),
        actions: [
          if (row.limitMinor > 0)
            TextButton(
              onPressed: () => Navigator.pop(ctx, 0), // clear
              child: const Text('Remove limit'),
            ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, MoneyFmt.parseToMinorUnits(ctrl.text)),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    ctrl.dispose();
    if (result == null) return;
    await ref
        .read(budgetsRepoProvider)
        .upsert(row.categoryId, _anchor, result);
    if (!mounted) return;
    await ref.read(alertServiceProvider).runChecks();
  }
}




