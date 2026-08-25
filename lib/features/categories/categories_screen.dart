import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/enums.dart';
import '../../data/database.dart';
import '../../providers/providers.dart';
import '../widgets/common.dart';
import 'category_editor_sheet.dart';

/// Manage categories and tags: create, edit, archive/restore, delete.
class CategoriesScreen extends ConsumerStatefulWidget {
  const CategoriesScreen({super.key});

  @override
  ConsumerState<CategoriesScreen> createState() => _CategoriesScreenState();
}

class _CategoriesScreenState extends ConsumerState<CategoriesScreen> {
  int _tab = 0;

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Organize'),
          bottom: TabBar(
            onTap: (i) => setState(() => _tab = i),
            tabs: const [
              Tab(text: 'Expense'),
              Tab(text: 'Income'),
              Tab(text: 'Tags'),
            ],
          ),
        ),
        floatingActionButton: FloatingActionButton(
          onPressed: () =>
              _tab == 2 ? _promptTagName(context) : showCategoryEditor(context),
          child: Icon(_tab == 2 ? Icons.sell_outlined : Icons.add),
        ),
        body: TabBarView(
          children: [
            const _CategoryList(type: CategoryType.expense),
            const _CategoryList(type: CategoryType.income),
            _TagList(
              onRename: (t) => _promptTagName(context, t),
              onDelete: _confirmDeleteTag,
            ),
          ],
        ),
      ),
    );
  }

  /// Asks for a tag name and creates/renames it.
  Future<void> _promptTagName(BuildContext context, [Tag? existing]) async {
    final name = await promptForText(
      context,
      title: existing == null ? 'New tag' : 'Rename tag',
      label: 'Tag name',
      initial: existing?.name,
      confirmLabel: existing == null ? 'Add' : 'Save',
    );
    if (name == null) return;
    if (existing == null) {
      await ref.read(tagsRepoProvider).getOrCreate(name);
    } else {
      await ref.read(tagsRepoProvider).rename(existing.id, name);
    }
  }

  Future<void> _confirmDeleteTag(Tag t) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        icon: const Icon(Icons.delete_outline),
        title: const Text('Delete tag?'),
        content: Text(
            '"${t.name}" will be removed from all transactions that use it.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          FilledButton(
              style: FilledButton.styleFrom(
                  backgroundColor: Theme.of(ctx).colorScheme.error),
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Delete')),
        ],
      ),
    );
    if (ok == true) await ref.read(tagsRepoProvider).delete(t.id);
  }
}

class _CategoryList extends ConsumerWidget {
  const _CategoryList({required this.type});

  final CategoryType type;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cats = ref.watch(allCategoriesProvider).value ?? [];
    final rows = cats.where((c) => c.type == type).toList();
    if (rows.isEmpty) return const EmptyState('No categories yet');
    return ListView(
      children: [
        for (final c in rows)
          ListTile(
            leading:
                CategoryIcon(iconCode: c.iconCode, colorValue: c.colorValue),
            title: Text(c.name,
                style:
                    TextStyle(fontStyle: c.archived ? FontStyle.italic : null)),
            trailing: Row(mainAxisSize: MainAxisSize.min, children: [
              if (c.archived)
                Text('archived', style: Theme.of(context).textTheme.bodySmall),
              Switch(
                value: !c.archived,
                onChanged: (_) async {
                  final repo = ref.read(categoriesRepoProvider);
                  if (c.archived) {
                    await repo.restore(c.id);
                  } else {
                    await repo.archive(c);
                  }
                },
              ),
              IconButton(
                icon: const Icon(Icons.edit_outlined),
                onPressed: () => showCategoryEditor(context, existing: c),
              ),
            ]),
          ),
      ],
    );
  }
}

class _TagList extends ConsumerWidget {
  const _TagList({required this.onRename, required this.onDelete});

  final ValueChanged<Tag> onRename;
  final ValueChanged<Tag> onDelete;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tags = ref.watch(allTagsProvider).value ?? [];
    if (tags.isEmpty) {
      return const EmptyState('No tags yet — group spending your way',
          icon: Icons.sell_outlined);
    }
    return ListView(
      children: [
        for (final t in tags)
          ListTile(
            leading: const Icon(Icons.sell_outlined),
            title: Text(t.name),
            trailing: Row(mainAxisSize: MainAxisSize.min, children: [
              IconButton(
                tooltip: 'Rename',
                icon: const Icon(Icons.edit_outlined),
                onPressed: () => onRename(t),
              ),
              IconButton(
                tooltip: 'Delete',
                icon: const Icon(Icons.delete_outline),
                onPressed: () => onDelete(t),
              ),
            ]),
          ),
      ],
    );
  }
}
