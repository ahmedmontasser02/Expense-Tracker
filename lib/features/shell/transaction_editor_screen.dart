import 'dart:io';

import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../core/enums.dart';
import '../../core/format.dart';
import '../../data/database.dart';
import '../../providers/providers.dart';
import '../widgets/common.dart';
import '../widgets/pickers.dart';

/// Opens the add/edit screen and returns true if something was saved.
Future<void> openTransactionEditor(BuildContext context, WidgetRef ref,
    [Tx? existing, ({int? amountMinor, String? note})? prefill]) async {
  await Navigator.of(context).push(MaterialPageRoute(
    builder: (_) => TransactionEditorScreen(
      existing: existing,
      prefill: prefill,
    ),
  ));
}

enum _Kind { expense, income, savings }

/// One editable split row.
class _SplitRow {
  int? categoryId;
  final TextEditingController amountCtrl = TextEditingController();
  final TextEditingController noteCtrl = TextEditingController();

  void dispose() {
    amountCtrl.dispose();
    noteCtrl.dispose();
  }
}

/// Full-screen add/edit transaction form with tags, category splits and
/// receipt attachments.
class TransactionEditorScreen extends ConsumerStatefulWidget {
  const TransactionEditorScreen(
      {super.key, this.existing, this.prefill});

  final Tx? existing;

  /// Values used to prefill a brand-new entry (share-to-log, quick actions).
  final ({int? amountMinor, String? note})? prefill;

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
  int? _suggestedCategoryId;
  DateTime _date = DateTime.now();
  bool _saving = false;

  // M3 state
  final Set<int> _tagIds = {};
  bool _splitMode = false;
  final List<_SplitRow> _splits = [];
  String? _receiptPath;

  bool get _editing => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    final prefill = widget.prefill;
    _type = existing?.type ?? TxType.expense;
    _amountCtrl = TextEditingController(text: existing == null
        ? (prefill?.amountMinor != null
            ? (prefill!.amountMinor! / 100).toStringAsFixed(2)
            : '')
        : (existing.amountMinor / 100).toStringAsFixed(2));
    _noteCtrl = TextEditingController(
        text: existing?.note ?? prefill?.note ?? '');
    _categoryId = existing?.categoryId;
    _goalId = existing?.goalId;
    _date = existing?.occurredAt ?? DateTime.now();
    _receiptPath = existing?.receiptPath;
    _noteCtrl.addListener(_onNoteChanged);
    if (existing != null) _loadJoins(existing.id);
  }

  Future<void> _loadJoins(int txId) async {
    final tags = await ref.read(tagsRepoProvider).tagsForTx(txId);
    final splits = await ref.read(transactionsRepoProvider).splitsForTx(txId);
    if (!mounted) return;
    setState(() {
      _tagIds.addAll(tags.map((t) => t.id));
      if (splits.isNotEmpty) {
        _splitMode = true;
        for (final s in splits) {
          final row = _SplitRow()
            ..categoryId = s.categoryId
            ..amountCtrl.text = (s.amountMinor / 100).toStringAsFixed(2)
            ..noteCtrl.text = s.note ?? '';
          _splits.add(row);
        }
      }
    });
  }

  void _onNoteChanged() {
    if (_kind == _Kind.savings ||
        _categoryId != null ||
        _noteCtrl.text.trim().length < 3) {
      if (_suggestedCategoryId != null && mounted) {
        setState(() => _suggestedCategoryId = null);
      }
      return;
    }
    _computeSuggestion();
  }

  Future<void> _computeSuggestion() async {
    final rules = ref.read(rulesRepoProvider);
    final note = _noteCtrl.text;
    var suggestion = await rules.matchCategory(note);
    suggestion ??= await rules.suggestCategory(note);
    if (!mounted ||
        _categoryId != null ||
        note != _noteCtrl.text ||
        suggestion == null) {
      return;
    }
    setState(() => _suggestedCategoryId = suggestion);
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
    for (final s in _splits) {
      s.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    final amount = MoneyFmt.parseToMinorUnits(_amountCtrl.text);
    if (amount <= 0) {
      _toast('Enter an amount greater than zero');
      return;
    }
    if (_kind != _Kind.savings && !_splitMode && _categoryId == null) {
      _toast('Pick a category');
      return;
    }

    List<({int categoryId, int amountMinor, String? note})>? splits;
    if (_kind != _Kind.savings && _splitMode) {
      splits = [];
      for (final row in _splits) {
        final rowAmount = MoneyFmt.parseToMinorUnits(row.amountCtrl.text);
        if (row.categoryId == null || rowAmount <= 0) {
          _toast('Every split needs a category and an amount');
          return;
        }
        splits.add((
          categoryId: row.categoryId!,
          amountMinor: rowAmount,
          note: row.noteCtrl.text.trim().isEmpty
              ? null
              : row.noteCtrl.text.trim(),
        ));
      }
      final splitSum = splits.fold(0, (a, s) => a + s.amountMinor);
      if (splitSum != amount) {
        _toast(
            'Splits total ${MoneyFmt.amount(splitSum)} but the amount is ${MoneyFmt.amount(amount)}');
        return;
      }
    }

    // Auto-categorization: rules first, then learned suggestion.
    int? effectiveCategory =
        _kind == _Kind.savings ? null : _categoryId;
    String? autoApplied;
    if (effectiveCategory == null && splits == null) {
      final rules = ref.read(rulesRepoProvider);
      effectiveCategory = await rules.matchCategory(_noteCtrl.text);
      effectiveCategory ??= await rules.suggestCategory(_noteCtrl.text);
      if (effectiveCategory != null) autoApplied = 'Auto-categorized';
    }

    setState(() => _saving = true);
    final repo = ref.read(transactionsRepoProvider);
    try {
      final note =
          _noteCtrl.text.trim().isEmpty ? null : _noteCtrl.text.trim();
      int txId;
      if (_editing) {
        final old = widget.existing!;
        txId = old.id;
        await repo.update(Tx(
          id: old.id,
          type: _type,
          amountMinor: amount,
          categoryId: effectiveCategory,
          goalId: _kind == _Kind.savings ? _goalId : null,
          note: note,
          occurredAt: _date,
          createdAt: old.createdAt,
          receiptPath: _receiptPath,
        ));
      } else {
        txId = await repo.create(TransactionsCompanion.insert(
          type: _type,
          amountMinor: amount,
          categoryId: Value(effectiveCategory),
          goalId: Value(_kind == _Kind.savings ? _goalId : null),
          note: Value(note),
          occurredAt: _date,
          receiptPath: Value(_receiptPath),
        ));
        await ref.read(alertServiceProvider).runChecks();
      }

      if (_kind != _Kind.savings && splits != null) {
        await repo.setSplits(txId, splits);
      } else if (_editing) {
        await repo.setSplits(txId, []);
      }
      await ref.read(tagsRepoProvider).setTagsForTx(txId, _tagIds.toList());

      if (mounted && autoApplied != null) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(autoApplied)));
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
    final joins = await ref.read(transactionsRepoProvider).delete(tx);
    showUndoSnackBar(messenger, ref, tx, wasNew: false, joins: joins);
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
      _splitMode = false;
    });
  }

  Future<void> _addTag() async {
    final name = await promptForText(
      context,
      title: 'New tag',
      label: 'Tag name',
      confirmLabel: 'Add',
    );
    if (name == null) return;
    final id = await ref.read(tagsRepoProvider).getOrCreate(name);
    if (mounted) setState(() => _tagIds.add(id));
  }

  Future<void> _attachReceipt({required bool fromCamera}) async {
    try {
      final picked = await ImagePicker().pickImage(
        source: fromCamera ? ImageSource.camera : ImageSource.gallery,
        maxWidth: 1600,
        imageQuality: 80,
      );
      if (picked == null) return;
      final docs = await getApplicationDocumentsDirectory();
      final dir = Directory(p.join(docs.path, 'receipts'));
      if (!dir.existsSync()) dir.createSync(recursive: true);
      final target = File(p.join(
          dir.path, 'receipt_${DateTime.now().millisecondsSinceEpoch}.jpg'));
      await File(picked.path).copy(target.path);
      if (mounted) setState(() => _receiptPath = target.path);
    } catch (e) {
      _toast('Could not attach receipt: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final expenseCats =
        ref.watch(categoriesByTypeProvider(CategoryType.expense)).value ?? [];
    final suggestedCat = _suggestedCategoryId == null
        ? null
        : expenseCats.where((c) => c.id == _suggestedCategoryId).firstOrNull;

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
          const SizedBox(height: 20),
          TextField(
            controller: _amountCtrl,
            keyboardType:
                const TextInputType.numberWithOptions(decimal: true),
            textAlign: TextAlign.center,
            style: Theme.of(context)
                .textTheme
                .displayMedium
                ?.copyWith(fontWeight: FontWeight.w800),
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}')),
            ],
            decoration: InputDecoration(
              filled: false,
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
              hintText: '0.00',
              hintStyle: TextStyle(
                  color: Theme.of(context)
                      .colorScheme
                      .onSurfaceVariant
                      .withValues(alpha: .4)),
              prefixText: '${ref.watch(currencySymbolProvider)} ',
              prefixStyle: Theme.of(context)
                  .textTheme
                  .displayMedium
                  ?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: Theme.of(context)
                          .colorScheme
                          .onSurfaceVariant
                          .withValues(alpha: .4)),
            ),
          ),
          Center(
            child: Container(
              width: 180,
              height: 3,
              decoration: BoxDecoration(
                color: Theme.of(context)
                    .colorScheme
                    .primary
                    .withValues(alpha: .5),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          CapsHeader('Category',
              padding: const EdgeInsets.only(top: 20, bottom: 6)),
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
                    onChanged: (v) =>
                        setState(() {
                          _categoryId = v;
                          _suggestedCategoryId = null;
                        }),
                  ),
          ),
          if (_kind != _Kind.savings &&
              suggestedCat != null &&
              _categoryId == null) ...[
            const SizedBox(height: 8),
            ActionChip(
              avatar: const Icon(Icons.auto_awesome, size: 16),
              label: Text('Use "${suggestedCat.name}" (suggested)'),
              onPressed: () => setState(() {
                _categoryId = suggestedCat.id;
                _suggestedCategoryId = null;
              }),
            ),
          ],
          const SizedBox(height: 16),
          CapsHeader('Note',
              padding: const EdgeInsets.only(top: 16, bottom: 6)),
          TextField(
            controller: _noteCtrl,
            textCapitalization: TextCapitalization.sentences,
            minLines: 2,
            maxLines: 4,
            decoration:
                const InputDecoration(hintText: 'Add a description…'),
          ),
          const SizedBox(height: 16),
          _TagsSection(
            selectedIds: _tagIds,
            onChanged: (ids) => setState(() => _tagIds
              ..clear()
              ..addAll(ids)),
            onAddTag: _addTag,
          ),
          if (_kind != _Kind.savings) ...[
            const SizedBox(height: 8),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Split across categories'),
              subtitle: const Text(
                  'e.g. a supermarket bill split into food and household'),
              value: _splitMode,
              onChanged: (v) => setState(() {
                _splitMode = v;
                if (v && _splits.isEmpty) {
                  _splits.add(_SplitRow());
                }
              }),
            ),
            if (_splitMode) _SplitsEditor(
            splits: _splits,
            symbol: ref.watch(currencySymbolProvider),
            onChanged: () => setState(() {}),
          ),
          ],
          const SizedBox(height: 8),
          _ReceiptSection(
            path: _receiptPath,
            onAttach: _attachReceipt,
            onRemove: () => setState(() => _receiptPath = null),
          ),
          const SizedBox(height: 16),
          CapsHeader('Date',
              padding: const EdgeInsets.only(top: 8, bottom: 6)),
          InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: _pickDate,
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
              decoration: BoxDecoration(
                color: Theme.of(context).inputDecorationTheme.fillColor,
                border: Border.fromBorderSide(BorderSide(
                    color: Theme.of(context).colorScheme.outlineVariant)),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(children: [
                Expanded(
                  child: Text(DateX.prettyDate(_date),
                      style: Theme.of(context).textTheme.bodyLarge),
                ),
                Icon(Icons.calendar_month_outlined,
                    size: 20, color: Theme.of(context).colorScheme.primary),
              ]),
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
            label: Text(_editing ? 'Save Changes' : 'Save Transaction'),
          ),
        ],
      ),
    );
  }
}

class _TagsSection extends ConsumerWidget {
  const _TagsSection({
    required this.selectedIds,
    required this.onChanged,
    required this.onAddTag,
  });

  final Set<int> selectedIds;
  final ValueChanged<Set<int>> onChanged;
  final VoidCallback onAddTag;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tags = ref.watch(allTagsProvider).value ?? [];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CapsHeader('Tags',
            padding: const EdgeInsets.only(top: 16, bottom: 8)),
        Wrap(
          spacing: 8,
          runSpacing: 4,
          children: [
            for (final t in tags)
              FilterChip(
                label: Text(t.name),
                selected: selectedIds.contains(t.id),
                onSelected: (sel) {
                  final next = {...selectedIds};
                  sel ? next.add(t.id) : next.remove(t.id);
                  onChanged(next);
                },
              ),
            ActionChip(
              avatar: const Icon(Icons.add, size: 16),
              label: const Text('New tag'),
              onPressed: onAddTag,
            ),
          ],
        ),
      ],
    );
  }
}

class _SplitsEditor extends StatelessWidget {
  const _SplitsEditor({
    required this.splits,
    required this.symbol,
    required this.onChanged,
  });

  final List<_SplitRow> splits;
  final String symbol;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (var i = 0; i < splits.length; i++)
          Card(
            margin: const EdgeInsets.symmetric(vertical: 4),
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: _SplitRowEditor(
                row: splits[i],
                symbol: symbol,
                canRemove: splits.length > 1,
                onRemove: () {
                  splits.removeAt(i);
                  onChanged();
                },
                onChanged: onChanged,
              ),
            ),
          ),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: () {
              splits.add(_SplitRow());
              onChanged();
            },
            icon: const Icon(Icons.add, size: 18),
            label: const Text('Add split'),
          ),
        ),
      ],
    );
  }
}

class _SplitRowEditor extends StatelessWidget {
  const _SplitRowEditor({
    required this.row,
    required this.symbol,
    required this.canRemove,
    required this.onRemove,
    required this.onChanged,
  });

  final _SplitRow row;
  final String symbol;
  final bool canRemove;
  final VoidCallback onRemove;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      CategoryPickerField(
        type: CategoryType.expense,
        value: row.categoryId,
        onChanged: (v) {
          row.categoryId = v;
          onChanged();
        },
      ),
      const SizedBox(height: 8),
      Row(children: [
        Expanded(
          child: TextField(
            controller: row.amountCtrl,
            keyboardType:
                const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
                labelText: 'Split amount', prefixText: '$symbol '),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: TextField(
            controller: row.noteCtrl,
            decoration: const InputDecoration(labelText: 'Note'),
          ),
        ),
        if (canRemove)
          IconButton(
            icon: const Icon(Icons.remove_circle_outline),
            onPressed: () {
              onRemove();
              onChanged();
            },
          ),
      ]),
    ]);
  }
}

class _ReceiptSection extends StatelessWidget {
  const _ReceiptSection({
    required this.path,
    required this.onAttach,
    required this.onRemove,
  });

  final String? path;
  final void Function({required bool fromCamera}) onAttach;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.primary;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CapsHeader('Receipt',
            padding: const EdgeInsets.only(top: 16, bottom: 2)),
        Row(children: [
          PopupMenuButton<String>(
            padding: EdgeInsets.zero,
            onSelected: (v) => onAttach(fromCamera: v == 'camera'),
            itemBuilder: (_) => const [
              PopupMenuItem(
                  value: 'camera',
                  child: ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(Icons.photo_camera_outlined),
                      title: Text('Camera'))),
              PopupMenuItem(
                  value: 'gallery',
                  child: ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(Icons.photo_outlined),
                      title: Text('Gallery'))),
            ],
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(
                    path == null
                        ? Icons.add_photo_alternate_outlined
                        : Icons.receipt_long_outlined,
                    size: 18,
                    color: accent),
                const SizedBox(width: 6),
                Text(path == null ? 'Attach Receipt' : 'Replace Receipt',
                    style: Theme.of(context)
                        .textTheme
                        .labelLarge
                        ?.copyWith(color: accent)),
              ]),
            ),
          ),
          const Spacer(),
          if (path != null)
            TextButton(onPressed: onRemove, child: const Text('Remove')),
        ]),
        if (path != null && File(path!).existsSync())
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 220),
                child: Image.file(File(path!), fit: BoxFit.cover),
              ),
            ),
          ),
      ],
    );
  }
}

/// Shared undo snackbar used by the editor and the swipe-to-delete list.
/// Deferred to after the current frame so it never races tree mutations
/// (deletions/dismissals) happening in the same tick. [joins] carries the
/// splits/tags captured by [TransactionsRepo.delete] so an undo restores
/// the full row.
void showUndoSnackBar(
    ScaffoldMessengerState messenger, WidgetRef ref, Tx tx,
    {required bool wasNew,
    ({List<TransactionSplit> splits, List<int> tagIds})? joins}) {
  WidgetsBinding.instance.addPostFrameCallback((_) {
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        content: Text(wasNew ? 'Transaction added' : 'Transaction deleted'),
        duration: const Duration(seconds: 4),
        action: SnackBarAction(
          label: 'UNDO',
          onPressed: () => ref.read(transactionsRepoProvider).restore(tx,
              splits: joins?.splits, tagIds: joins?.tagIds),
        ),
      ),
    );
  });
}
