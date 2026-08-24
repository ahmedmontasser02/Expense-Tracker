import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/enums.dart';
import '../../core/format.dart';
import '../../data/database.dart';
import '../../providers/providers.dart';
import '../widgets/common.dart';

/// Chronological activity log: every create/update/delete, generated
/// recurring entries and fired alerts.
class LogsScreen extends ConsumerStatefulWidget {
  const LogsScreen({super.key});

  @override
  ConsumerState<LogsScreen> createState() => _LogsScreenState();
}

class _LogsScreenState extends ConsumerState<LogsScreen> {
  LogAction? _filter;

  @override
  Widget build(BuildContext context) {
    final logs = ref.watch(activityLogProvider).value ?? [];
    final rows =
        _filter == null ? logs : logs.where((l) => l.action == _filter).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Activity Log'),
        actions: [
          IconButton(
            tooltip: 'Clear log',
            icon: const Icon(Icons.delete_sweep_outlined),
            onPressed: () async {
              final ok = await showDialog<bool>(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: const Text('Clear the log?'),
                  content: const Text('Entries cannot be recovered.'),
                  actions: [
                    TextButton(
                        onPressed: () => Navigator.pop(ctx, false),
                        child: const Text('Cancel')),
                    FilledButton(
                        onPressed: () => Navigator.pop(ctx, true),
                        child: const Text('Clear')),
                  ],
                ),
              );
              if (ok == true) await ref.read(logsRepoProvider).clear();
            },
          ),
        ],
      ),
      body: Column(
        children: [
          SizedBox(
            height: 48,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: ChoiceChip(
                    label: const Text('All'),
                    selected: _filter == null,
                    onSelected: (_) => setState(() => _filter = null),
                  ),
                ),
                for (final a in LogAction.values)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: ChoiceChip(
                      label: Text(a.name),
                      selected: _filter == a,
                      onSelected: (sel) =>
                          setState(() => _filter = sel ? a : null),
                    ),
                  ),
              ],
            ),
          ),
          Expanded(
            child: rows.isEmpty
                ? const EmptyState('No activity yet')
                : ListView.separated(
                    padding: const EdgeInsets.only(bottom: 96),
                    itemCount: rows.length,
                    separatorBuilder: (_, _) =>
                        const Divider(height: 1, indent: 56),
                    itemBuilder: (context, i) {
                      final l = rows[i];
                      return ListTile(
                        leading:
                            Icon(_iconFor(l.action), color: _colorFor(l.action)),
                        title: Text(_title(l)),
                        subtitle: Text(DateX.prettyDateTime(l.at)),
                        isThreeLine: false,
                        dense: true,
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  String _title(ActivityLog l) {
    switch (l.action) {
      case LogAction.created:
        return 'Created ${l.entityType} ${l.details}';
      case LogAction.updated:
        return 'Updated ${l.entityType} ${l.details}';
      case LogAction.deleted:
        return 'Deleted ${l.entityType}';
      case LogAction.generated:
        return 'Auto-generated ${l.entityType} ${l.details} (recurring)';
      case LogAction.alert:
        return 'Alert — ${l.details}';
    }
  }

  IconData _iconFor(LogAction a) => switch (a) {
        LogAction.created => Icons.add_circle_outline,
        LogAction.updated => Icons.edit_outlined,
        LogAction.deleted => Icons.remove_circle_outline,
        LogAction.generated => Icons.autorenew,
        LogAction.alert => Icons.notifications_active_outlined,
      };

  Color? _colorFor(LogAction a) => switch (a) {
        LogAction.created => Colors.green,
        LogAction.updated => null,
        LogAction.deleted => Colors.red,
        LogAction.generated => Colors.blue,
        LogAction.alert => Colors.orange,
      };
}
