import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants.dart';
import '../../core/enums.dart';
import '../../core/format.dart';
import '../../core/theme.dart';
import '../../data/database.dart';
import '../../data/repositories/goals_repo.dart';
import '../budgets/budgets_screen.dart';
import '../categories/categories_screen.dart';
import '../recurring/recurring_screen.dart';
import '../savings/savings_screen.dart';
import '../transactions/transactions_screen.dart';
import '../widgets/common.dart';
import '../widgets/update_banner.dart';
import '../../providers/providers.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final balance = ref.watch(balanceProvider);
    final pot = ref.watch(savingsPotProvider);
    final summary = ref.watch(monthSummaryProvider);
    final recurring = ref.watch(recurringListProvider).value ?? [];
    final upcoming = [
      for (final r in recurring)
        if (r.active) r,
    ]..sort((a, b) => a.nextDueAt.compareTo(b.nextDueAt));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Expense Tracker'),
        actions: [
          if (isDevBuild)
            const Padding(
              padding: EdgeInsets.only(right: 8),
              child: Chip(
                label: Text('DEV',
                    style:
                        TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                visualDensity: VisualDensity.compact,
              ),
            ),
          IconButton(
            tooltip: 'Manage categories',
            icon: const Icon(Icons.category_outlined),
            onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const CategoriesScreen())),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
        children: [
          const UpdateBanner(),
          _BalanceCard(
            balance: balance.value,
            savings: pot.value,
          ),
          const SizedBox(height: 12),
          summary.when(
            loading: () => const Center(child: Padding(
              padding: EdgeInsets.all(24), child: CircularProgressIndicator())),
            error: (e, _) => EmptyState('Could not load month data'),
            data: (s) {
              final sym = ref.watch(currencySymbolProvider);
              return Row(
                children: [
                  Expanded(
                    child: StatCard(
                      label: 'Income',
                      value: fmtAmount(sym, s.incomeMinor),
                      color: AppTheme.incomeColor(context),
                      icon: Icons.south_west,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: StatCard(
                      label: 'Spent',
                      value: fmtAmount(sym, s.expenseMinor),
                      color: AppTheme.expenseColor(context),
                      icon: Icons.north_east,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: StatCard(
                      label: 'Saved',
                      value: MoneyFmt.signedWith(sym, s.savedInMinor - s.savedOutMinor),
                      color: AppTheme.savingsColor(context),
                      icon: Icons.savings_outlined,
                    ),
                  ),
                ],
              );
            },
          ),
          SectionHeader(
            'Plan',
            trailing: TextButton(
              child: const Text('RECURRING'),
              onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const RecurringScreen())),
            ),
          ),
          const _PlanPreviews(),
          if (upcoming.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Card(
                child: ListTile(
                  leading: const Icon(Icons.repeat),
                  title: Text(
                      '${upcoming.length} upcoming recurring transaction${upcoming.length == 1 ? '' : 's'}'),
                  subtitle: Text(
                      'Next: ${_recurringLabel(upcoming.first, ref)} on ${DateX.prettyDate(upcoming.first.nextDueAt)}'),
                  onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(
                          builder: (_) => const RecurringScreen())),
                ),
              ),
            ),
          SectionHeader(
            'Recent',
            trailing: TextButton(
              child: const Text('SEE ALL'),
              onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => const TransactionsScreen())),
            ),
          ),
          _RecentTransactions(limit: 5),
        ],
      ),
    );
  }

  String _recurringLabel(RecurringTemplate t, WidgetRef ref) {
    final sym = ref.watch(currencySymbolProvider);
    return '${t.type.label} ${fmtAmount(sym, t.amountMinor)}';
  }
}

/// Budgets + savings goals preview cards with live progress bars.
class _PlanPreviews extends ConsumerWidget {
  const _PlanPreviews();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sym = ref.watch(currencySymbolProvider);
    final budgets = ref.watch(budgetOverviewFamily(DateTime.now())).value ?? [];
    final goals = ref.watch(goalsWithProgressProvider).value ?? [];
    final limited = budgets.where((b) => b.limitMinor > 0).toList();

    String? budgetSummary;
    double? budgetFraction;
    if (limited.isNotEmpty) {
      final limit = limited.fold(0, (a, b) => a + b.limitMinor);
      final spent = limited.fold(0, (a, b) => a + b.spentMinor);
      budgetFraction = spent / limit;
      final left = limit - spent;
      budgetSummary = left >= 0
          ? '${(spent * 100 / limit).round()}% spent  ·  ${fmtAmount(sym, left)} left'
          : '${fmtAmount(sym, -left)} over budget';
    }

    GoalProgress? goal;
    double? goalFraction;
    String? goalSummary;
    for (final g in goals) {
      if (g.goal.targetMinor > 0) {
        goal = g;
        goalFraction = g.savedMinor / g.goal.targetMinor;
        goalSummary =
            '${fmtAmount(sym, g.savedMinor)} / ${fmtAmount(sym, g.goal.targetMinor)}';
        break;
      }
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: _PlanCard(
            label: 'Budgets',
            icon: Icons.account_balance_wallet_outlined,
            accent: Theme.of(context).colorScheme.primary,
            fraction: budgetFraction,
            summary: budgetSummary ?? 'No limits set yet',
            empty: budgetFraction == null,
            onTap: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const BudgetsScreen())),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _PlanCard(
            label: 'Savings',
            icon: Icons.savings_outlined,
            accent: AppTheme.savingsColor(context),
            fraction: goalFraction,
            summary: goal == null
                ? 'Create a goal'
                : '${goal.goal.name} · $goalSummary',
            empty: goal == null,
            onTap: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const SavingsScreen())),
          ),
        ),
      ],
    );
  }
}

class _PlanCard extends StatelessWidget {
  const _PlanCard({
    required this.label,
    required this.icon,
    required this.accent,
    required this.fraction,
    required this.summary,
    required this.empty,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final Color accent;
  final double? fraction;
  final String summary;
  final bool empty;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(children: [
                Expanded(
                  child: Text(label.toUpperCase(),
                      overflow: TextOverflow.ellipsis,
                      style: AppTheme.labelCaps(context)),
                ),
                Icon(icon, size: 16, color: accent),
              ]),
              const SizedBox(height: 10),
              FillBar(fraction: fraction ?? 0, color: accent),
              const SizedBox(height: 10),
              Text(
                summary,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: empty
                    ? Theme.of(context).textTheme.bodySmall
                    : Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BalanceCard extends ConsumerWidget {
  const _BalanceCard({required this.balance, required this.savings});

  final int? balance;
  final int? savings;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sym = ref.watch(currencySymbolProvider);
    final bal = balance;
    final saved = savings;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final labelColor = dark ? AppTheme.savingsColor(context) : const Color(0xFFB6EBFE);
    final amountColor = dark ? Theme.of(context).colorScheme.primary : Colors.white;
    final subColor = dark
        ? Theme.of(context).colorScheme.onSurfaceVariant
        : Colors.white.withValues(alpha: .82);

    return Container(
      decoration: BoxDecoration(
        gradient: AppTheme.balanceGradient(context),
        borderRadius: BorderRadius.circular(16),
        border: dark
            ? Border.all(color: Theme.of(context).colorScheme.primary.withValues(alpha: .4))
            : null,
        boxShadow: AppTheme.glow(context, Theme.of(context).colorScheme.primary,
            radius: 28, alpha: .22),
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('TOTAL BALANCE',
              style: AppTheme.labelCaps(context, color: labelColor)),
          const SizedBox(height: 6),
          FittedBox(
            child: AnimatedAmount(
              bal == null ? '…' : fmtAmount(sym, bal),
              style: Theme.of(context).textTheme.displayLarge?.copyWith(
                    color: amountColor,
                    shadows: dark
                        ? const [
                            Shadow(color: Color(0x88FF2D78), blurRadius: 18),
                          ]
                        : null,
                  ),
            ),
          ),
          const SizedBox(height: 12),
          Row(children: [
            Icon(Icons.savings_outlined, size: 16, color: subColor),
            const SizedBox(width: 6),
            Text(
              'IN SAVINGS: ${saved == null ? '…' : fmtAmount(sym, saved).toUpperCase()}',
              style: AppTheme.labelCaps(context, color: subColor),
            ),
          ]),
        ],
      ),
    );
  }
}

class _RecentTransactions extends ConsumerWidget {
  const _RecentTransactions({required this.limit});

  final int limit;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cats = ref.watch(allCategoriesProvider).value ?? [];
    final byId = {for (final c in cats) c.id: c};
    final sym = ref.watch(currencySymbolProvider);
    final asyncRows = ref.watch(recentTxProvider(limit));

    return asyncRows.when(
      loading: () => const LinearProgressIndicator(),
      error: (e, _) => const EmptyState('Could not load transactions'),
      data: (rows) {
        if (rows.isEmpty) {
          return const EmptyState('No transactions yet — tap Add to start',
              icon: Icons.receipt_long_outlined);
        }
        return Card(
          child: Column(
            children: [
              for (final tx in rows.take(limit))
                TransactionTile(
                    tx: tx, category: byId[tx.categoryId], symbol: sym),
            ],
          ),
        );
      },
    );
  }
}

/// Shared transaction row used by dashboard + list screen.
class TransactionTile extends StatelessWidget {
  const TransactionTile({
    super.key,
    required this.tx,
    required this.category,
    required this.symbol,
    this.onTap,
    this.onDelete,
  });

  final Tx tx;
  final Category? category;
  final String symbol;
  final VoidCallback? onTap;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    // In lists, expenses stay neutral (on-surface) so income and savings
    // movements pop; stat cards and reports use the full semantic colors.
    final color = switch (tx.type) {
      TxType.income => AppTheme.incomeColor(context),
      TxType.expense => Theme.of(context).colorScheme.onSurface,
      TxType.savingsDeposit ||
      TxType.savingsWithdrawal =>
        AppTheme.savingsColor(context),
    };
    final sign = switch (tx.type) {
      TxType.income || TxType.savingsDeposit => '+',
      TxType.expense || TxType.savingsWithdrawal => '-',
    };
    final note = tx.note;
    return ListTile(
      leading: category != null
          ? CategoryIcon(
              iconCode: category!.iconCode, colorValue: category!.colorValue)
          : CategoryIcon(
              iconCode: tx.type.isSavings ? 'savings' : 'more_horiz',
              colorValue: AppTheme.savingsColor(context).toARGB32()),
      title: Text(category?.name ?? note ?? tx.type.label,
          maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Text(
          '${DateX.prettyDate(tx.occurredAt).toUpperCase()}'
          '${tx.goalId != null ? " • GOAL" : ""}'
          '${note != null && category != null ? " • ${note.toUpperCase()}" : ""}',
          maxLines: 1,
          overflow: TextOverflow.ellipsis),
      trailing: Row(mainAxisSize: MainAxisSize.min, children: [
        if (tx.receiptPath != null)
          Padding(
            padding: const EdgeInsets.only(right: 4),
            child: Icon(Icons.receipt_outlined,
                size: 16, color: Theme.of(context).colorScheme.outline),
          ),
        Text('$sign${fmtAmount(symbol, tx.amountMinor)}',
            style: TextStyle(
                fontFamily: 'Inter',
                color: color,
                fontWeight: FontWeight.w700,
                fontSize: 15)),
        if (onDelete != null)
          IconButton(icon: const Icon(Icons.delete_outline), onPressed: onDelete),
      ]),
      onTap: onTap,
    );
  }
}
