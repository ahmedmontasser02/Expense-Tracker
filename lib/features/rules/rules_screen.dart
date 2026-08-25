import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/enums.dart';
import '../../data/database.dart';
import '../../providers/providers.dart';
import '../widgets/common.dart';

/// Manage auto-categorization rules. When a new transaction's note matches
/// a rule pattern, its category is suggested/applied automatically.
class RulesScreen extends ConsumerWidget {
  const RulesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rules = ref.watch(rulesListProvider).value;
    final cats = ref.watch(allCategoriesProvider).value ?? [];
    final byId = {for (final c in cats) c.id: c};

    return Scaffold(
      appBar: AppBar(title: const Text('Auto-categorization')),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showRuleEditor(context, ref),
        child: const Icon(Icons.add),
      ),
      body: rules == null
          ? const Center(child: CircularProgressIndicator())
          : rules.isEmpty
              ? const EmptyState(
                  'No rules yet — teach the app your recurring bills',
                  icon: Icons.auto_awesome_outlined)
              : ListView(
                  padding: const EdgeInsets.only(bottom: 96),
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                      child: Text(
                          'When a note contains the pattern, that category is '
                          'picked automatically. Higher priority wins when '
                          'several rules match.',
                          style: Theme.of(context).textTheme.bodySmall),
                    ),
                    for (final r in rules)
                      ListTile(
                        leading: const Icon(Icons.auto_awesome_outlined),
                        title: Text(
                            '"${r.pattern}" → ${byId[r.categoryId]?.name ?? '?'}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis),
                        subtitle: r.enabled
                            ? (r.priority == 0
                                ? null
                                : Text('Priority ${r.priority}'))
                            : const Text('Disabled'),
                        trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                          Switch(
                            value: r.enabled,
                            onChanged: (v) => ref
                                .read(rulesRepoProvider)
                                .setEnabled(r.id, v),
                          ),
                          IconButton(
                            tooltip: 'Edit',
                            icon: const Icon(Icons.edit_outlined),
                            onPressed: () =>
                                _showRuleEditor(context, ref, existing: r),
                          ),
                          IconButton(
                            tooltip: 'Delete',
                            icon: const Icon(Icons.delete_outline),
                            onPressed: () =>
                                ref.read(rulesRepoProvider).delete(r.id),
                          ),
                        ]),
                      ),
                  ],
                ),
    );
  }

  Future<void> _showRuleEditor(BuildContext context, WidgetRef ref,
      {Rule? existing}) async {
    final cats = (ref.read(allCategoriesProvider).value ?? [])
        .where((c) => c.type == CategoryType.expense && !c.archived)
        .toList();
    final patternCtrl = TextEditingController(text: existing?.pattern);
    final priorityCtrl =
        TextEditingController(text: '${existing?.priority ?? 0}');
    int? categoryId = existing?.categoryId;

    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(existing == null ? 'New rule' : 'Edit rule'),
        content: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            TextField(
              controller: patternCtrl,
              autofocus: true,
              maxLength: 80,
              decoration: const InputDecoration(
                labelText: 'Pattern in note',
                helperText: 'e.g. "netflix", "shell"',
              ),
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<int>(
              initialValue: categoryId,
              decoration: const InputDecoration(labelText: 'Category'),
              items: [
                for (final c in cats)
                  DropdownMenuItem(value: c.id, child: Text(c.name)),
              ],
              onChanged: (v) => categoryId = v,
            ),
            const SizedBox(height: 8),
            TextField(
              controller: priorityCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Priority',
                helperText: 'Bigger wins; ties go to the oldest rule',
              ),
            ),
          ]),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Save')),
        ],
      ),
    );

    final pattern = patternCtrl.text.trim();
    final priority = int.tryParse(priorityCtrl.text.trim()) ?? 0;
    patternCtrl.dispose();
    priorityCtrl.dispose();
    if (saved != true) return;
    if (pattern.isEmpty || categoryId == null) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('A rule needs a pattern and a category')));
      }
      return;
    }

    final repo = ref.read(rulesRepoProvider);
    if (existing == null) {
      await repo.create(RulesCompanion.insert(
        pattern: pattern,
        categoryId: categoryId!,
        priority: Value(priority),
      ));
    } else {
      await repo.update(Rule(
        id: existing.id,
        pattern: pattern,
        categoryId: categoryId!,
        priority: priority,
        enabled: existing.enabled,
        createdAt: existing.createdAt,
      ));
    }
  }
}
