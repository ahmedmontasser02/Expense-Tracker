import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/enums.dart';
import '../../core/format.dart';
import '../../data/database.dart';
import '../../data/repositories/goals_repo.dart';
import '../../providers/providers.dart';
import '../widgets/common.dart';
import 'goal_editor_sheet.dart';

/// Savings goals overview with progress and quick deposit/withdraw.
class SavingsScreen extends ConsumerWidget {
  const SavingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final goals = ref.watch(goalsWithProgressProvider).value ?? [];
    final pot = ref.watch(savingsPotProvider).value;
    final sym = ref.watch(currencySymbolProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Savings Goals')),
      floatingActionButton: FloatingActionButton(
        onPressed: () => showGoalEditor(context),
        child: const Icon(Icons.add),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
        children: [
          Card(
            color: Theme.of(context).colorScheme.secondaryContainer,
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Total in savings',
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                          color: Theme.of(context)
                              .colorScheme
                              .onSecondaryContainer)),
                  const SizedBox(height: 4),
                  Text(pot == null ? '…' : fmtAmount(sym, pot),
                      style: Theme.of(context)
                          .textTheme
                          .headlineSmall
                          ?.copyWith(fontWeight: FontWeight.bold)),
                ],
              ),
            ),
          ),
          const SectionHeader('Goals'),
          if (goals.isEmpty)
            const EmptyState('No goals yet — add one to start saving',
                icon: Icons.savings_outlined),
          for (final g in goals) _goalCard(context, ref, g, sym),
        ],
      ),
    );
  }

  Widget _goalCard(
      BuildContext context, WidgetRef ref, GoalProgress g, String sym) {
    final progress =
        g.goal.targetMinor == 0 ? 0.0 : g.savedMinor / g.goal.targetMinor;
    final done = progress >= 1;
    final deadline = g.goal.deadline;

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onLongPress: () => _confirmDelete(context, ref, g.goal),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(children: [
            Row(children: [
              Icon(done ? Icons.emoji_events : Icons.savings,
                  color: done ? Colors.amber : null),
              const SizedBox(width: 10),
              Expanded(child: Text(g.goal.name)),
              Text(
                  '${fmtAmount(sym, g.savedMinor)} / ${fmtAmount(sym, g.goal.targetMinor)}',
                  style: const TextStyle(
                      fontSize: 13, fontWeight: FontWeight.w600)),
            ]),
            const SizedBox(height: 8),
            FillBar(
                fraction: progress,
                color:
                    done ? Colors.amber : Theme.of(context).colorScheme.primary),
            Row(children: [
              if (deadline != null)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text('by ${DateX.prettyDate(deadline)}',
                      style: Theme.of(context).textTheme.bodySmall),
                ),
              const Spacer(),
              TextButton.icon(
                onPressed: () => _quickMove(
                    context, ref, g.goal.id, TxType.savingsDeposit),
                icon: const Icon(Icons.add_circle_outline, size: 18),
                label: const Text('Deposit'),
              ),
              TextButton.icon(
                onPressed: () => _quickMove(
                    context, ref, g.goal.id, TxType.savingsWithdrawal),
                icon: const Icon(Icons.remove_circle_outline, size: 18),
                label: const Text('Withdraw'),
              ),
            ]),
          ]),
        ),
      ),
    );
  }

  Future<void> _confirmDelete(
      BuildContext context, WidgetRef ref, SavingsGoal goal) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Delete "${goal.name}"?'),
        content: const Text(
            'Past transactions are kept; they will no longer link to a goal.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Delete')),
        ],
      ),
    );
    if (ok == true) await ref.read(goalsRepoProvider).delete(goal.id);
  }

  Future<void> _quickMove(BuildContext context, WidgetRef ref, int goalId,
      TxType type) async {
    final ctrl = TextEditingController();
    final amount = await showDialog<int>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(type == TxType.savingsDeposit
            ? 'Deposit to goal'
            : 'Withdraw from goal'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          keyboardType:
              const TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(
              prefixText: '${ref.read(currencySymbolProvider)} '),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            onPressed: () =>
                Navigator.pop(ctx, MoneyFmt.parseToMinorUnits(ctrl.text)),
            child: const Text('OK'),
          ),
        ],
      ),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) => ctrl.dispose());
    if (amount == null || amount <= 0) return;
    await ref.read(transactionsRepoProvider).create(
          TransactionsCompanion.insert(
            type: type,
            amountMinor: amount,
            categoryId: const Value(null),
            goalId: Value(goalId),
            occurredAt: DateTime.now(),
          ),
        );
    await ref.read(alertServiceProvider).runChecks();
  }
}

