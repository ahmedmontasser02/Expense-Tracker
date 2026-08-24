import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/enums.dart';
import '../../core/format.dart';
import '../../data/database.dart';
import '../../providers/providers.dart';
import '../widgets/common.dart';
import '../widgets/pickers.dart';

/// Manage recurring transaction templates (subscriptions, rent, salary…).
class RecurringScreen extends ConsumerWidget {
  const RecurringScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final templates = ref.watch(recurringListProvider).value ?? [];
    final sym = ref.watch(currencySymbolProvider);
    final cats = ref.watch(allCategoriesProvider).value ?? [];
    final byId = {for (final c in cats) c.id: c};

    return Scaffold(
      appBar: AppBar(title: const Text('Recurring Transactions')),
      floatingActionButton: FloatingActionButton(
        onPressed: () => showModalBottomSheet(
          context: context,
          isScrollControlled: true,
          builder: (_) => const _RecurringEditor(),
        ),
        child: const Icon(Icons.add),
      ),
      body: templates.isEmpty
          ? const EmptyState(
              'No recurring transactions yet.\nAdd rent, subscriptions or salary here.',
              icon: Icons.autorenew)
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
              children: [
                for (final t in templates)
                  Card(
                    margin: const EdgeInsets.symmetric(vertical: 4),
                    child: ListTile(
                      leading: CategoryIcon(
                        iconCode:
                            byId[t.categoryId]?.iconCode ?? 'more_horiz',
                        colorValue: byId[t.categoryId]?.colorValue,
                      ),
                      title: Text(
                        '${t.type.label} ${fmtAmount(sym, t.amountMinor)}'
                        '${t.note != null ? ' • ${t.note}' : ''}',
                        style: TextStyle(
                          decoration:
                              t.active ? null : TextDecoration.lineThrough,
                        ),
                      ),
                      subtitle: Text(
                        '${_cadenceLabel(t)} — next: ${DateX.prettyDate(t.nextDueAt)}',
                      ),
                      trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                        Switch(
                          value: t.active,
                          onChanged: (v) => ref
                              .read(recurringRepoProvider)
                              .setActive(t.id, v),
                        ),
                        PopupMenuButton<String>(
                          onSelected: (v) async {
                            if (v == 'edit') {
                              if (!context.mounted) return;
                              await showModalBottomSheet(
                                context: context,
                                isScrollControlled: true,
                                builder: (_) => _RecurringEditor(existing: t),
                              );
                            } else if (v == 'delete') {
                              await ref
                                  .read(recurringRepoProvider)
                                  .delete(t.id);
                            }
                          },
                          itemBuilder: (_) => const [
                            PopupMenuItem(value: 'edit', child: Text('Edit')),
                            PopupMenuItem(
                                value: 'delete', child: Text('Delete')),
                          ],
                        ),
                      ]),
                    ),
                  ),
              ],
            ),
    );
  }

  static String _cadenceLabel(RecurringTemplate t) {
    final n = t.everyN;
    return switch (t.frequency) {
      Frequency.daily => n == 1 ? 'Every day' : 'Every $n days',
      Frequency.weekly => n == 1 ? 'Weekly' : 'Every $n weeks',
      Frequency.monthly => n == 1 ? 'Monthly' : 'Every $n months',
      Frequency.yearly => n == 1 ? 'Yearly' : 'Every $n years',
    };
  }
}

class _RecurringEditor extends ConsumerStatefulWidget {
  const _RecurringEditor({this.existing});

  final RecurringTemplate? existing;

  @override
  ConsumerState<_RecurringEditor> createState() => _RecurringEditorState();
}

class _RecurringEditorState extends ConsumerState<_RecurringEditor> {
  late TxType _type;
  late final TextEditingController _amountCtrl;
  late final TextEditingController _noteCtrl;
  int? _categoryId;
  int? _goalId;
  late Frequency _frequency;
  late int _everyN;
  DateTime _nextDueAt = DateTime.now();
  DateTime? _endAfter;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _type = e?.type ?? TxType.expense;
    _amountCtrl = TextEditingController(
        text: e == null ? '' : (e.amountMinor / 100).toStringAsFixed(2));
    _noteCtrl = TextEditingController(text: e?.note ?? '');
    _categoryId = e?.categoryId;
    _goalId = e?.goalId;
    _frequency = e?.frequency ?? Frequency.monthly;
    _everyN = e?.everyN ?? 1;
    _nextDueAt = e?.nextDueAt ?? DateTime.now();
    _endAfter = e?.endAfter;
  }

  @override
  void dispose() {
    _amountCtrl.dispose();
    _noteCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(widget.existing == null ? 'New Recurring' : 'Edit Recurring',
                style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 12),
            SegmentedButton<TxType>(
              segments: [
                for (final t in TxType.values)
                  ButtonSegment(value: t, label: Text(_shortLabel(t))),
              ],
              selected: {_type},
              onSelectionChanged: (s) => setState(() {
                _type = s.first;
                _categoryId = null;
                _goalId = null;
              }),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _amountCtrl,
              autofocus: true,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                labelText: 'Amount',
                prefixText: '${ref.watch(currencySymbolProvider)} ',
              ),
            ),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(
                child: DropdownButtonFormField<Frequency>(
                  initialValue: _frequency,
                  decoration: const InputDecoration(labelText: 'Frequency'),
                  items: [
                    for (final f in Frequency.values)
                      DropdownMenuItem(value: f, child: Text(f.label)),
                  ],
                  onChanged: (v) => setState(() => _frequency = v!),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: DropdownButtonFormField<int>(
                  initialValue: _everyN,
                  decoration: const InputDecoration(labelText: 'Every'),
                  items: [
                    for (var i = 1; i <= 30; i++)
                      DropdownMenuItem(value: i, child: Text('$i')),
                  ],
                  onChanged: (v) => setState(() => _everyN = v!),
                ),
              ),
            ]),
            const SizedBox(height: 12),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 250),
              child: _type.isSavings
                  ? GoalPickerField(
                      key: const ValueKey('rgoal'),
                      value: _goalId,
                      onChanged: (v) => setState(() => _goalId = v),
                    )
                  : CategoryPickerField(
                      key: ValueKey('rcat-${_type.name}'),
                      type: _type.isIncome
                          ? CategoryType.income
                          : CategoryType.expense,
                      value: _categoryId,
                      onChanged: (v) => setState(() => _categoryId = v),
                    ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _noteCtrl,
              decoration: const InputDecoration(labelText: 'Note (optional)'),
            ),
            Card(
              child: ListTile(
                leading: const Icon(Icons.play_arrow),
                title: const Text('Next due date'),
                subtitle: Text(DateX.prettyDate(_nextDueAt)),
                onTap: () async {
                  final d = await showDatePicker(
                    context: context,
                    initialDate: _nextDueAt,
                    firstDate: DateTime.now(),
                    lastDate: DateTime(2100),
                  );
                  if (d != null) setState(() => _nextDueAt = d);
                },
              ),
            ),
            Card(
              child: ListTile(
                leading: const Icon(Icons.stop_circle_outlined),
                title: const Text('End after (optional)'),
                subtitle: Text(_endAfter == null
                    ? 'Never ends'
                    : DateX.prettyDate(_endAfter!)),
                trailing: _endAfter == null
                    ? const Icon(Icons.add)
                    : IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () => setState(() => _endAfter = null)),
                onTap: () async {
                  final d = await showDatePicker(
                    context: context,
                    initialDate: _endAfter ?? _nextDueAt.add(const Duration(days: 365)),
                    firstDate: DateTime.now(),
                    lastDate: DateTime(2100),
                  );
                  if (d != null) setState(() => _endAfter = d);
                },
              ),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              icon: const Icon(Icons.check),
              label: Text(widget.existing == null ? 'Create' : 'Save'),
              onPressed: () async {
                final amount = MoneyFmt.parseToMinorUnits(_amountCtrl.text);
                if (amount <= 0) return;
                final repo = ref.read(recurringRepoProvider);
                final note =
                    _noteCtrl.text.trim().isEmpty ? null : _noteCtrl.text.trim();
                if (widget.existing == null) {
                  await repo.create(RecurringTemplatesCompanion.insert(
                    type: _type,
                    amountMinor: amount,
                    categoryId: Value(
                        _type.isSavings ? null : _categoryId),
                    goalId: Value(_type.isSavings ? _goalId : null),
                    note: Value(note),
                    frequency: _frequency,
                    everyN: Value(_everyN),
                    nextDueAt: _nextDueAt,
                    endAfter: Value(_endAfter),
                  ));
                } else {
                  final old = widget.existing!;
                  await repo.updateTemplate(RecurringTemplate(
                    id: old.id,
                    type: _type,
                    amountMinor: amount,
                    categoryId: _type.isSavings ? null : _categoryId,
                    goalId: _type.isSavings ? _goalId : null,
                    note: note,
                    frequency: _frequency,
                    everyN: _everyN,
                    nextDueAt: _nextDueAt,
                    endAfter: _endAfter,
                    lastRunAt: old.lastRunAt,
                    active: old.active,
                    createdAt: old.createdAt,
                  ));
                }
                if (context.mounted) Navigator.pop(context);
              },
            ),
          ],
        ),
      ),
    );
  }

  String _shortLabel(TxType t) => switch (t) {
        TxType.expense => 'Expense',
        TxType.income => 'Income',
        TxType.savingsDeposit => 'Deposit',
        TxType.savingsWithdrawal => 'Withdraw',
      };
}

