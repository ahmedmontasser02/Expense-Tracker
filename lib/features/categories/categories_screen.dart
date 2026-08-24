import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/enums.dart';
import '../../providers/providers.dart';
import '../widgets/common.dart';
import 'category_editor_sheet.dart';

/// Manage categories: create, edit, archive/restore.
class CategoriesScreen extends ConsumerWidget {
  const CategoriesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Categories'),
          bottom:
              const TabBar(tabs: [Tab(text: 'Expense'), Tab(text: 'Income')]),
        ),
        floatingActionButton: FloatingActionButton(
          onPressed: () => showCategoryEditor(context),
          child: const Icon(Icons.add),
        ),
        body: const TabBarView(
          children: [
            _CategoryList(type: CategoryType.expense),
            _CategoryList(type: CategoryType.income),
          ],
        ),
      ),
    );
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

