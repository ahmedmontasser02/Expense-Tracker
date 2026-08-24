import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/format.dart';
import '../../data/database.dart';
import '../../providers/providers.dart';
import '../dashboard/dashboard_screen.dart';
import '../widgets/common.dart';
import '../shell/transaction_editor_screen.dart';

enum _Range { today, week, month, year, all }

extension _RangeX on _Range {
  String get label => switch (this) {
        _Range.today => 'Today',
        _Range.week => '7 days',
        _Range.month => 'This month',
        _Range.year => 'This year',
        _Range.all => 'All time',
      };

  (DateTime?, DateTime?) bounds() {
    final now = DateTime.now();
    return switch (this) {
      _Range.today => (DateX.startOfDay(now), DateX.endOfDay(now)),
      _Range.week => (
          DateX.startOfDay(now.subtract(const Duration(days: 6))),
          DateX.endOfDay(now),
        ),
      _Range.month => (DateX.startOfMonth(now), DateX.endOfMonth(now)),
      _Range.year => (
          DateTime(now.year, 1, 1),
          DateX.endOfYear(now.year),
        ),
      _Range.all => (null, null),
    };
  }
}

/// Filterable, searchable transaction history.
class TransactionsScreen extends ConsumerStatefulWidget {
  const TransactionsScreen({super.key});

  @override
  ConsumerState<TransactionsScreen> createState() =>
      _TransactionsScreenState();
}

class _TransactionsScreenState extends ConsumerState<TransactionsScreen> {
  _Range _range = _Range.month;
  int? _categoryFilter;
  String _search = '';

  @override
  Widget build(BuildContext context) {
    final cats = ref.watch(allCategoriesProvider).value ?? [];
    final byId = {for (final c in cats) c.id: c};
    final sym = ref.watch(currencySymbolProvider);
    final (from, to) = _range.bounds();

    final repo = ref.watch(transactionsRepoProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Transactions')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: TextField(
              onChanged: (v) => setState(() => _search = v),
              decoration: InputDecoration(
                hintText: 'Search notes…',
                prefixIcon: const Icon(Icons.search),
                isDense: true,
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24)),
              ),
            ),
          ),
          SizedBox(
            height: 48,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              children: [
                for (final r in _Range.values)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: ChoiceChip(
                      label: Text(r.label),
                      selected: _range == r,
                      onSelected: (_) => setState(() => _range = r),
                    ),
                  ),
              ],
            ),
          ),
          SizedBox(
            height: 48,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: ChoiceChip(
                    label: const Text('All categories'),
                    selected: _categoryFilter == null,
                    onSelected: (_) => setState(() => _categoryFilter = null),
                  ),
                ),
                for (final c in cats.where((c) => !c.archived))
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: ChoiceChip(
                      label: Text(c.name),
                      selected: _categoryFilter == c.id,
                      onSelected: (_) => setState(() => _categoryFilter = c.id),
                    ),
                  ),
              ],
            ),
          ),
          Expanded(
            child: StreamBuilder<List<Tx>>(
              key: ValueKey('$_search|$_categoryFilter|$_range'),
              stream: repo.watchFiltered(
                from: from,
                to: to,
                categoryId: _categoryFilter,
                search: _search,
              ),
              builder: (context, snap) {
                if (!snap.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                final rows = snap.data!;
                if (rows.isEmpty) {
                  return const EmptyState('Nothing here yet',
                      icon: Icons.receipt_long_outlined);
                }
                return ListView.builder(
                  padding: const EdgeInsets.only(bottom: 96),
                  itemCount: rows.length,
                  itemBuilder: (context, i) {
                    final tx = rows[i];
                    return Dismissible(
                      key: ValueKey('tx-${tx.id}'),
                      direction: DismissDirection.endToStart,
                      background: Container(
                        alignment: Alignment.centerRight,
                        padding: const EdgeInsets.only(right: 24),
                        margin: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.red,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: const Icon(Icons.delete_outline,
                            color: Colors.white, size: 28),
                      ),
                      onDismissed: (_) async {
                        final messenger = ScaffoldMessenger.of(context);
                        await ref
                            .read(transactionsRepoProvider)
                            .delete(tx);
                        showUndoSnackBar(messenger, ref, tx, wasNew: false);
                      },
                      child: TransactionTile(
                        tx: tx,
                        category: byId[tx.categoryId],
                        symbol: sym,
                        onTap: () => openTransactionEditor(context, ref, tx),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
