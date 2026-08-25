import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants.dart';
import '../../core/enums.dart';
import '../../core/format.dart';
import '../../core/theme.dart';
import '../../data/database.dart';
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
                      label: 'Income (${DateTime.now().month})',
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
              child: const Text('Recurring'),
              onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const RecurringScreen())),
            ),
          ),
          Card(
            child: Column(children: [
              ListTile(
                leading: const Icon(Icons.account_balance_wallet_outlined),
                title: const Text('Budgets'),
                subtitle: const Text('Monthly limits per category'),
                onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const BudgetsScreen())),
              ),
              const Divider(height: 1, indent: 16),
              ListTile(
                leading: const Icon(Icons.savings_outlined),
                title: const Text('Savings Goals'),
                subtitle: const Text('Targets and progress'),
                onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const SavingsScreen())),
              ),
              if (upcoming.isNotEmpty) ...[
                const Divider(height: 1, indent: 16),
                ListTile(
                  leading: const Icon(Icons.repeat),
                  title: Text(
                      '${upcoming.length} upcoming recurring transaction${upcoming.length == 1 ? '' : 's'}'),
                  subtitle: Text(
                      'Next: ${_recurringLabel(upcoming.first, ref)} on ${DateX.prettyDate(upcoming.first.nextDueAt)}'),
                  onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(
                          builder: (_) => const RecurringScreen())),
                ),
              ],
            ]),
          ),
          SectionHeader(
            'Recent transactions',
            trailing: TextButton(
              child: const Text('See all'),
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

class _BalanceCard extends ConsumerWidget {
  const _BalanceCard({required this.balance, required this.savings});

  final int? balance;
  final int? savings;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sym = ref.watch(currencySymbolProvider);
    final bal = balance;
    final saved = savings;
    return Card(
      color: Theme.of(context).colorScheme.primaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Total Balance',
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color:
                        Theme.of(context).colorScheme.onPrimaryContainer)),
            const SizedBox(height: 4),
            AnimatedAmount(
              bal == null ? '…' : fmtAmount(sym, bal),
              style: Theme.of(context)
                  .textTheme
                  .headlineMedium
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Row(children: [
              Icon(Icons.savings_outlined,
                  size: 18,
                  color: Theme.of(context).colorScheme.onPrimaryContainer),
              const SizedBox(width: 6),
              Text(
                'In savings: ${saved == null ? '…' : fmtAmount(sym, saved)}',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onPrimaryContainer),
              ),
            ]),
          ],
        ),
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
          clipBehavior: Clip.antiAlias,
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
    final color = switch (tx.type) {
      TxType.income => AppTheme.incomeColor(context),
      TxType.expense => AppTheme.expenseColor(context),
      TxType.savingsDeposit ||
      TxType.savingsWithdrawal =>
        AppTheme.savingsColor(context),
    };
    final sign = switch (tx.type) {
      TxType.income || TxType.savingsDeposit => '+',
      TxType.expense || TxType.savingsWithdrawal => '-',
    };
    return ListTile(
      leading: category != null
          ? CategoryIcon(
              iconCode: category!.iconCode, colorValue: category!.colorValue)
          : CircleAvatar(
              radius: 20,
              backgroundColor:
                  Theme.of(context).colorScheme.surfaceContainerHighest,
              child: Icon(
                  tx.type.isSavings ? Icons.savings : Icons.more_horiz,
                  size: 20),
            ),
      title: Text(category?.name ?? tx.note ?? tx.type.label,
          maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Text(
          '${DateX.prettyDate(tx.occurredAt)}'
          '${tx.goalId != null ? " • goal" : ""}'
          '${tx.note != null && category != null ? " • ${tx.note}" : ""}',
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
                color: color, fontWeight: FontWeight.bold, fontSize: 15)),
        if (onDelete != null)
          IconButton(icon: const Icon(Icons.delete_outline), onPressed: onDelete),
      ]),
      onTap: onTap,
    );
  }
}

