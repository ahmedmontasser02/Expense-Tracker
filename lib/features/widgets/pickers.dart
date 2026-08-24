import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/enums.dart';
import '../../providers/providers.dart';
import '../categories/category_editor_sheet.dart';
import '../savings/goal_editor_sheet.dart';

/// Category dropdown with a "Create new category…" entry that opens the
/// editor sheet and selects the freshly created category.
class CategoryPickerField extends ConsumerWidget {
  const CategoryPickerField({
    super.key,
    required this.type,
    required this.value,
    required this.onChanged,
  });

  final CategoryType type;
  final int? value;
  final ValueChanged<int?> onChanged;

  static const _createNew = -1;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cats = ref.watch(categoriesByTypeProvider(type)).value ?? [];
    final selected = cats.where((c) => c.id == value).toList();

    return DropdownButtonFormField<int>(
      initialValue: value,
      decoration: InputDecoration(
        labelText: 'Category',
        prefixIcon: selected.isNotEmpty
            ? Padding(
                padding: const EdgeInsets.all(12),
                child: CircleAvatar(
                    radius: 10,
                    backgroundColor: Color(selected.first.colorValue)),
              )
            : const Icon(Icons.category_outlined),
      ),
      items: [
        for (final c in cats)
          DropdownMenuItem(value: c.id, child: Text(c.name)),
        const DropdownMenuItem(
          value: _createNew,
          enabled: true,
          child: Row(children: [
            Icon(Icons.add, size: 18),
            SizedBox(width: 6),
            Text('Create new category…'),
          ]),
        ),
      ],
      onChanged: (v) async {
        if (v == _createNew) {
          final id = await showCategoryEditor(context, initialType: type);
          if (id != null) onChanged(id);
          return;
        }
        onChanged(v);
      },
    );
  }
}

/// Goal dropdown with a "Create new goal…" entry; empty state still allows
/// creating one inline so the field never feels disabled.
class GoalPickerField extends ConsumerWidget {
  const GoalPickerField({
    super.key,
    required this.value,
    required this.onChanged,
  });

  final int? value;
  final ValueChanged<int?> onChanged;

  static const _createNew = -1;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final goals = ref.watch(goalsWithProgressProvider).value ?? [];

    return DropdownButtonFormField<int>(
      initialValue: value,
      decoration: const InputDecoration(labelText: 'Goal (optional)'),
      items: [
        for (final g in goals)
          DropdownMenuItem(
            value: g.goal.id,
            child: Row(children: [
              const Icon(Icons.savings, size: 18),
              const SizedBox(width: 8),
              Expanded(
                  child: Text(g.goal.name, overflow: TextOverflow.ellipsis)),
            ]),
          ),
        const DropdownMenuItem(
          value: _createNew,
          child: Row(children: [
            Icon(Icons.add, size: 18),
            SizedBox(width: 6),
            Text('Create new goal…'),
          ]),
        ),
      ],
      onChanged: (v) async {
        if (v == _createNew) {
          final id = await showGoalEditor(context);
          if (id != null) onChanged(id);
          return;
        }
        onChanged(v);
      },
    );
  }
}

