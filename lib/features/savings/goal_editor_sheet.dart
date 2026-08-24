import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/format.dart';
import '../../data/database.dart';
import '../../providers/providers.dart';

/// Bottom-sheet editor for savings goals. Pops with the saved goal id.
Future<int?> showGoalEditor(BuildContext context, {SavingsGoal? existing}) {
  return showModalBottomSheet<int>(
    context: context,
    isScrollControlled: true,
    builder: (_) => GoalEditorSheet(existing: existing),
  );
}

class GoalEditorSheet extends ConsumerStatefulWidget {
  const GoalEditorSheet({super.key, this.existing});

  final SavingsGoal? existing;

  @override
  ConsumerState<GoalEditorSheet> createState() => _GoalEditorSheetState();
}

class _GoalEditorSheetState extends ConsumerState<GoalEditorSheet> {
  late final TextEditingController _nameCtrl;
  late final TextEditingController _targetCtrl;
  DateTime? _deadline;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _nameCtrl = TextEditingController(text: e?.name ?? '');
    _targetCtrl = TextEditingController(
        text: e == null ? '' : (e.targetMinor / 100).toStringAsFixed(2));
    _deadline = e?.deadline;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _targetCtrl.dispose();
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
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(widget.existing == null ? 'New Goal' : 'Edit Goal',
              style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 12),
          TextField(
            autofocus: true,
            controller: _nameCtrl,
            decoration: const InputDecoration(labelText: 'Name'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _targetCtrl,
            keyboardType:
                const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
              labelText: 'Target amount',
              prefixText: '${ref.watch(currencySymbolProvider)} ',
            ),
          ),
          const SizedBox(height: 8),
          Card(
            child: ListTile(
              leading: const Icon(Icons.event_outlined),
              title: const Text('Deadline (optional)'),
              subtitle:
                  Text(_deadline == null ? 'None' : DateX.prettyDate(_deadline!)),
              trailing: _deadline == null
                  ? const Icon(Icons.add)
                  : IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () => setState(() => _deadline = null)),
              onTap: () async {
                final d = await showDatePicker(
                  context: context,
                  initialDate: _deadline ?? DateTime.now(),
                  firstDate: DateTime.now(),
                  lastDate: DateTime(2100),
                );
                if (d != null) setState(() => _deadline = d);
              },
            ),
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            icon: const Icon(Icons.check),
            label: Text(widget.existing == null ? 'Create' : 'Save'),
            onPressed: () async {
              final name = _nameCtrl.text.trim();
              final target = MoneyFmt.parseToMinorUnits(_targetCtrl.text);
              if (name.isEmpty || target <= 0) return;
              final repo = ref.read(goalsRepoProvider);
              int id;
              if (widget.existing == null) {
                id = await repo.create(SavingsGoalsCompanion.insert(
                  name: name,
                  targetMinor: target,
                  deadline: Value(_deadline),
                ));
              } else {
                id = widget.existing!.id;
                await repo.update(SavingsGoal(
                  id: id,
                  name: name,
                  targetMinor: target,
                  deadline: _deadline,
                  archived: widget.existing!.archived,
                  createdAt: widget.existing!.createdAt,
                ));
              }
              if (context.mounted) Navigator.pop(context, id);
            },
          ),
        ],
      ),
    );
  }
}
