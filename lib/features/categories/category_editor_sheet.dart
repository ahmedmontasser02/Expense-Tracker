import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/category_presets.dart';
import '../../core/enums.dart';
import '../../data/database.dart';
import '../../providers/providers.dart';

/// Bottom-sheet editor used for creating AND editing categories.
/// Pops with the saved category id, or null when cancelled.
Future<int?> showCategoryEditor(BuildContext context,
    {Category? existing, CategoryType initialType = CategoryType.expense}) {
  return showModalBottomSheet<int>(
    context: context,
    isScrollControlled: true,
    builder: (_) => CategoryEditorSheet(
      existing: existing,
      initialType: initialType,
    ),
  );
}

class CategoryEditorSheet extends ConsumerStatefulWidget {
  const CategoryEditorSheet(
      {super.key, this.existing, this.initialType = CategoryType.expense});

  final Category? existing;
  final CategoryType initialType;

  @override
  ConsumerState<CategoryEditorSheet> createState() => _CategoryEditorSheetState();
}

class _CategoryEditorSheetState extends ConsumerState<CategoryEditorSheet> {
  late final TextEditingController _nameCtrl =
      TextEditingController(text: widget.existing?.name ?? '');
  late CategoryType _type =
      widget.existing?.type ?? widget.initialType;
  late String _icon = widget.existing?.iconCode ?? IconPresets.defaultCode;
  late int _color =
      widget.existing?.colorValue ?? IconPresets.palette.first.toARGB32();

  @override
  void dispose() {
    _nameCtrl.dispose();
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
          Text(widget.existing == null ? 'New Category' : 'Edit Category',
              style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 12),
          SegmentedButton<CategoryType>(
            segments: const [
              ButtonSegment(
                  value: CategoryType.expense, label: Text('Expense')),
              ButtonSegment(value: CategoryType.income, label: Text('Income')),
            ],
            selected: {_type},
            onSelectionChanged: (s) => setState(() => _type = s.first),
          ),
          const SizedBox(height: 12),
          TextField(
            autofocus: true,
            controller: _nameCtrl,
            decoration: const InputDecoration(labelText: 'Name'),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 96,
            child: GridView.count(
              crossAxisCount: 7,
              shrinkWrap: true,
              children: [
                for (final e in IconPresets.icons.entries)
                  InkWell(
                    borderRadius: BorderRadius.circular(20),
                    onTap: () => setState(() => _icon = e.key),
                    child: CircleAvatar(
                      radius: 18,
                      backgroundColor: _icon == e.key
                          ? Theme.of(context).colorScheme.primary
                          : Theme.of(context).colorScheme.surfaceContainerHigh,
                      child: Icon(e.value,
                          size: 18,
                          color: _icon == e.key
                              ? Theme.of(context).colorScheme.onPrimary
                              : null),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 10,
            children: [
              for (final color in IconPresets.palette)
                GestureDetector(
                  onTap: () => setState(() => _color = color.toARGB32()),
                  child: Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: color,
                      shape: BoxShape.circle,
                      border: Border.all(
                        width: _color == color.toARGB32() ? 3 : 0,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            icon: const Icon(Icons.check),
            label: Text(widget.existing == null ? 'Create' : 'Save'),
            onPressed: () async {
              final name = _nameCtrl.text.trim();
              if (name.isEmpty) return;
              final repo = ref.read(categoriesRepoProvider);
              int id;
              if (widget.existing == null) {
                id = await repo.create(CategoriesCompanion.insert(
                  name: name,
                  type: _type,
                  iconCode: Value(_icon),
                  colorValue: Value(_color),
                ));
              } else {
                id = widget.existing!.id;
                await repo.update(Category(
                  id: id,
                  name: name,
                  type: _type,
                  iconCode: _icon,
                  colorValue: _color,
                  archived: widget.existing!.archived,
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
