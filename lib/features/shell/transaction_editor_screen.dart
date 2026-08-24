import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/enums.dart';
import '../../core/format.dart';
import '../../data/database.dart';
import '../../providers/providers.dart';
import '../widgets/pickers.dart';

/// Opens the add/edit screen and returns true if something was saved.
Future<void> openTransactionEditor(BuildContext context, WidgetRef ref,
    [Tx? existing]) async {
  await Navigator.of(context).push(MaterialPageRoute(
    builder: (_) => TransactionEditorScreen(existing: existing),
  ));
}

enum _Kind { expense, income, savings }

/// Full-screen add/edit transaction form, covering expenses, incomes and
/// savings deposits/withdrawals (optionally linked to a goal).
class TransactionEditorScreen extends ConsumerStatefulWidget {
  const TransactionEditorScreen({super.key, this.existing});

  final Tx? existing;

  @override
  ConsumerState<TransactionEditorScreen> createState() =>
      _TransactionEditorScreenState();
}

class _TransactionEditorScreenState
    extends ConsumerState<TransactionEditorScreen> {
  late TxType _type;
  late final TextEditingController _amountCtrl;
  late final TextEditingController _noteCtrl;
  int? _categoryId;
  int? _goalId;
  DateTime _date = DateTime.now();
  bool _saving = false;

  bool get _editing => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    _type = existing?.type ?? TxType.expense;
    _amountCtrl = TextEditingController(text: existing == null
        ? ''
        : (existing.amountMinor / 100).toStringAsFixed(2));
    _noteCtrl = TextEditingController(text: existing?.note ?? '');
    _categoryId = existing?.categoryId;
    _goalId = existing?.goalId;
    _date = existing?.occurredAt ?? DateTime.now();
  }

  _Kind get _kind => switch (_type) {
        TxType.expense => _Kind.expense,
        TxType.income => _Kind.income,
        _ => _Kind.savings,
      };

  @override
  void dispose() {
    _amountCtrl.dispose();
    _noteCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final amount = MoneyFmt.parseToMinorUnits(_amountCtrl.text);
    if (amount <= 0) {
      _toast('Enter an amount greater than zero');
      return;
    }
    if (_kind != _Kind.savings && _categoryId == null) {
      _toast('Pick a category');
      return;
    }

    setState(() => _saving = true);
    final repo = ref.read(transactionsRepoProvider);
    try {
      final note =
          _noteCtrl.text.trim().isEmpty ? null : _noteCtrl.text.trim();
      if (_editing) {
        final old = widget.existing!;
        await repo.update(Tx(
          id: old.id,
          type: _type,
          amountMinor: amount,
          categoryId: _kind == _Kind.savings ? null : _categoryId,
          goalId: _kind == _Kind.savings ? _goalId : null,
          note: note,
          occurredAt: _date,
          createdAt: old.createdAt,
        ));
      } else {
        await repo.create(TransactionsCompanion.insert(
          type: _type,
          amountMinor: amount,
          categoryId: Value(_kind == _Kind.savings ? null : _categoryId),
          goalId: Value(_kind == _Kind.savings ? _goalId : null),
          note: Value(note),
          occurredAt: _date,
        ));
        await ref.read(alertServiceProvider).runChecks();
      }
      if (mounted) Navigator.of(context).pop(true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _delete() async {
    final tx = widget.existing!;
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    await ref.read(transactionsRepoProvider).delete(tx);
    showUndoSnackBar(messenger, ref, tx, wasNew: false);
    navigator.pop(true);
  }

  void _toast(String msg) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));

  Future<void> _pickDate() async {
    final d = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (d != null) setState(() => _date = d);
  }

  void _selectKind(_Kind k) {
    setState(() {
      switch (k) {
        case _Kind.expense:
          _type = TxType.expense;
        case _Kind.income:
          _type = TxType.income;
        case _Kind.savings:
          _type = _type.isSavings ? _type : TxType.savingsDeposit;
      }
      _categoryId = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_editing ? 'Edit Transaction' : 'New Transaction'),
        actions: [
          if (_editing)
            IconButton(
              tooltip: 'Delete transaction',
              icon: const Icon(Icons.delete_outline),
              onPressed: _delete,
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          SegmentedButton<_Kind>(
            segments: const [
              ButtonSegment(value: _Kind.expense, label: Text('Expense')),
              ButtonSegment(value: _Kind.income, label: Text('Income')),
              ButtonSegment(value: _Kind.savings, label: Text('Savings')),
            ],
            selected: {_kind},
            onSelectionChanged: (s) => _selectKind(s.first),
          ),
          if (_kind == _Kind.savings) ...[
            const SizedBox(height: 12),
            SegmentedButton<bool>(
              segments: const [
                ButtonSegment(value: true, label: Text('Deposit')),
                ButtonSegment(value: false, label: Text('Withdraw')),
              ],
              selected: {_type == TxType.savingsDeposit},
              onSelectionChanged: (s) => setState(
                  () => _type = s.first
                      ? TxType.savingsDeposit
                      : TxType.savingsWithdrawal),
            ),
          ],
          const SizedBox(height: 16),
          TextField(
            controller: _amountCtrl,
            keyboardType:
                const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}')),
            ],
            decoration: InputDecoration(
              labelText: 'Amount',
              prefixText: '${ref.watch(currencySymbolProvider)} ',
            ),
          ),
          const SizedBox(height: 16),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 250),
            child: _kind == _Kind.savings
                ? GoalPickerField(
                    key: const ValueKey('goal'),
                    value: _goalId,
                    onChanged: (v) => setState(() => _goalId = v),
                  )
                : CategoryPickerField(
                    key: ValueKey('cat-${_kind.name}'),
                    type: _kind == _Kind.income
                        ? CategoryType.income
                        : CategoryType.expense,
                    value: _categoryId,
                    onChanged: (v) => setState(() => _categoryId = v),
                  ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _noteCtrl,
            textCapitalization: TextCapitalization.sentences,
            decoration:
                const InputDecoration(labelText: 'Note (what was it for?)'),
          ),
          const SizedBox(height: 16),
          Card(
            child: ListTile(
              leading: const Icon(Icons.calendar_today_outlined),
              title: const Text('Date'),
              subtitle: Text(DateX.prettyDate(_date)),
              trailing: const Icon(Icons.chevron_right),
              onTap: _pickDate,
            ),
          ),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: _saving ? null : _save,
            icon: _saving
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.check),
            label: Text(_editing ? 'Save Changes' : 'Add Transaction'),
          ),
        ],
      ),
    );
  }
}

/// Shared undo snackbar used by the editor and the swipe-to-delete list.
/// Deferred to after the current frame so it never races tree mutations
/// (deletions/dismissals) happening in the same tick.
void showUndoSnackBar(
    ScaffoldMessengerState messenger, WidgetRef ref, Tx tx,
    {required bool wasNew}) {
  WidgetsBinding.instance.addPostFrameCallback((_) {
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        content: Text(wasNew ? 'Transaction added' : 'Transaction deleted'),
        duration: const Duration(seconds: 4),
        action: SnackBarAction(
          label: 'UNDO',
          onPressed: () =>
              ref.read(transactionsRepoProvider).restore(tx),
        ),
      ),
    );
  });
}
