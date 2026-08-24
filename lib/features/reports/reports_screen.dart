import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/enums.dart';
import '../../core/format.dart';
import '../../core/theme.dart';
import '../../data/database.dart';
import '../../providers/providers.dart';
import '../widgets/common.dart';

enum _Granularity { day, month, year }

extension on _Granularity {
  String get label => switch (this) {
        _Granularity.day => 'Day',
        _Granularity.month => 'Month',
        _Granularity.year => 'Year',
      };
}

/// Daily / monthly / yearly spending reports with charts.
class ReportsScreen extends ConsumerStatefulWidget {
  const ReportsScreen({super.key});

  @override
  ConsumerState<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends ConsumerState<ReportsScreen> {
  _Granularity _gran = _Granularity.month;
  DateTime _anchor = DateTime.now();

  @override
  Widget build(BuildContext context) {
    final sym = ref.watch(currencySymbolProvider);
    final cats = ref.watch(allCategoriesProvider).value ?? [];
    final byId = {for (final c in cats) c.id: c};

    final bounds = _boundsFor(_anchor);
    final repo = ref.watch(transactionsRepoProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Reports')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: SegmentedButton<_Granularity>(
              segments: [
                for (final g in _Granularity.values)
                  ButtonSegment(value: g, label: Text(g.label)),
              ],
              selected: {_gran},
              onSelectionChanged: (s) => setState(() => _gran = s.first),
            ),
          ),
          _PeriodSelector(
            label: _periodLabel(),
            onStep: (dir) => setState(() => _anchor = _shift(_anchor, dir)),
            onPick: _pickPeriod,
          ),
          Expanded(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 250),
              child: StreamBuilder<List<Tx>>(
                key: ValueKey('$_gran-$_anchor'),
                stream: repo.watchFiltered(from: bounds.$1, to: bounds.$2),
                builder: (context, snap) {
                  if (!snap.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  final rows = snap.data!;
                  if (rows.isEmpty) {
                    return EmptyState(
                        'No transactions in this ${_gran.label.toLowerCase()}',
                        icon: Icons.query_stats_outlined);
                  }
                  final hasExpense =
                      rows.any((r) => r.type == TxType.expense);

                  return ListView(
                    key: ValueKey('content-$_gran-$_anchor'),
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
                    children: [
                      _TotalsRow(rows: rows, symbol: sym),
                      const SizedBox(height: 16),
                      if (_gran != _Granularity.day && hasExpense) ...[
                        _BarChartCard(rows: rows, gran: _gran, symbol: sym),
                        const SizedBox(height: 16),
                      ],
                      if (hasExpense) ...[
                        _CategoryPieCard(
                          rows: rows,
                          byId: byId,
                          symbol: sym,
                          title: 'Spending by category',
                        ),
                        const SizedBox(height: 16),
                      ],
                      _TopCategories(rows: rows, byId: byId, symbol: sym),
                    ],
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Opens a picker matching the granularity: calendar for a day,
  /// month grid for a month, year grid for a year.
  Future<void> _pickPeriod() async {
    switch (_gran) {
      case _Granularity.day:
        final d = await showDatePicker(
          context: context,
          initialDate: _anchor,
          firstDate: DateTime(2000),
          lastDate: DateTime(2100),
        );
        if (d != null) setState(() => _anchor = d);
      case _Granularity.month:
        final m = await showDialog<DateTime>(
          context: context,
          builder: (_) => _MonthPickerDialog(initial: _anchor),
        );
        if (m != null) setState(() => _anchor = m);
      case _Granularity.year:
        final y = await showDialog<DateTime>(
          context: context,
          builder: (_) => _YearPickerDialog(initial: _anchor),
        );
        if (y != null) setState(() => _anchor = y);
    }
  }

  String _periodLabel() => switch (_gran) {
        _Granularity.day => DateX.prettyDate(_anchor),
        _Granularity.month =>
          '${DateX.monthName(_anchor.month)} ${_anchor.year}',
        _Granularity.year => '${_anchor.year}',
      };

  DateTime _shift(DateTime a, int dir) => switch (_gran) {
        _Granularity.day => DateTime(a.year, a.month, a.day + dir),
        _Granularity.month => DateTime(a.year, a.month + dir),
        _Granularity.year => DateTime(a.year + dir),
      };

  (DateTime?, DateTime?) _boundsFor(DateTime a) => switch (_gran) {
        _Granularity.day => (DateX.startOfDay(a), DateX.endOfDay(a)),
        _Granularity.month => (DateX.startOfMonth(a), DateX.endOfMonth(a)),
        _Granularity.year =>
          (DateX.startOfYear(a.year), DateX.endOfYear(a.year)),
      };
}

/// Chevron stepper + tappable period pill that opens the matching picker.
class _PeriodSelector extends StatelessWidget {
  const _PeriodSelector({
    required this.label,
    required this.onStep,
    required this.onPick,
  });

  final String label;
  final ValueChanged<int> onStep;
  final VoidCallback onPick;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          IconButton(
            tooltip: 'Previous',
            onPressed: () => onStep(-1),
            icon: const Icon(Icons.chevron_left),
          ),
          Expanded(
            child: Center(
              child: InkWell(
                borderRadius: BorderRadius.circular(24),
                onTap: onPick,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.secondaryContainer,
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.calendar_month_outlined,
                          size: 18,
                          color: Theme.of(context)
                              .colorScheme
                              .onSecondaryContainer),
                      const SizedBox(width: 8),
                      Text(label,
                          style: Theme.of(context)
                              .textTheme
                              .titleSmall
                              ?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onSecondaryContainer)),
                      const SizedBox(width: 4),
                      Icon(Icons.arrow_drop_down,
                          color: Theme.of(context)
                              .colorScheme
                              .onSecondaryContainer),
                    ],
                  ),
                ),
              ),
            ),
          ),
          IconButton(
            tooltip: 'Next',
            onPressed: () => onStep(1),
            icon: const Icon(Icons.chevron_right),
          ),
        ],
      ),
    );
  }
}

/// Year stepper + month grid.
class _MonthPickerDialog extends StatefulWidget {
  const _MonthPickerDialog({required this.initial});

  final DateTime initial;

  @override
  State<_MonthPickerDialog> createState() => _MonthPickerDialogState();
}

class _MonthPickerDialogState extends State<_MonthPickerDialog> {
  late int _year = widget.initial.year;
  late final int _month = widget.initial.month;

  static const _short = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Row(
        children: [
          IconButton(
            onPressed: () => setState(() => _year--),
            icon: const Icon(Icons.chevron_left),
          ),
          Expanded(
            child: Center(
              child: Text('$_year',
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(fontWeight: FontWeight.bold)),
            ),
          ),
          IconButton(
            onPressed: () => setState(() => _year++),
            icon: const Icon(Icons.chevron_right),
          ),
        ],
      ),
      content: SizedBox(
        width: 280,
        child: GridView.count(
          crossAxisCount: 3,
          shrinkWrap: true,
          childAspectRatio: 1.6,
          mainAxisSpacing: 8,
          crossAxisSpacing: 8,
          children: [
            for (var m = 1; m <= 12; m++)
              InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: () =>
                    Navigator.pop(context, DateTime(_year, m)),
                child: Container(
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: m == _month
                        ? Theme.of(context).colorScheme.primaryContainer
                        : Theme.of(context).colorScheme.surfaceContainerHigh,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(_short[m - 1],
                      style: const TextStyle(fontWeight: FontWeight.w600)),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Scrollable year grid (last 15 years through next year).
class _YearPickerDialog extends StatelessWidget {
  const _YearPickerDialog({required this.initial});

  final DateTime initial;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now().year;
    final years = [for (var y = now - 14; y <= now + 1; y++) y];

    return AlertDialog(
      title: const Text('Select year'),
      content: SizedBox(
        width: 280,
        height: 320,
        child: GridView.count(
          crossAxisCount: 3,
          childAspectRatio: 1.6,
          mainAxisSpacing: 8,
          crossAxisSpacing: 8,
          children: [
            for (final y in years)
              InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: () => Navigator.pop(context, DateTime(y)),
                child: Container(
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: y == initial.year
                        ? Theme.of(context).colorScheme.primaryContainer
                        : Theme.of(context).colorScheme.surfaceContainerHigh,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text('$y',
                      style: const TextStyle(fontWeight: FontWeight.w600)),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _TotalsRow extends StatelessWidget {
  const _TotalsRow({required this.rows, required this.symbol});

  final List<Tx> rows;
  final String symbol;

  @override
  Widget build(BuildContext context) {
    var income = 0, expense = 0;
    for (final r in rows) {
      if (r.type == TxType.income) income += r.amountMinor;
      if (r.type == TxType.expense) expense += r.amountMinor;
    }
    final net = income - expense;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            Expanded(
              child: _total(context, 'Income', fmtAmount(symbol, income),
                  AppTheme.incomeColor(context)),
            ),
            Expanded(
              child: _total(context, 'Spent', fmtAmount(symbol, expense),
                  AppTheme.expenseColor(context)),
            ),
            Expanded(
              child: _total(
                  context,
                  'Net',
                  fmtAmount(symbol, net),
                  net >= 0
                      ? AppTheme.incomeColor(context)
                      : Colors.red),
            ),
          ],
        ),
      ),
    );
  }

  Widget _total(BuildContext c, String label, String value, Color color) =>
      Column(children: [
        Text(label, style: Theme.of(c).textTheme.bodySmall),
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(value,
              maxLines: 1,
              style: Theme.of(c)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.bold, color: color)),
        ),
      ]);
}

/// Bars over the period's natural buckets (Month shows per-day;
/// Year shows per-month).
class _BarChartCard extends StatelessWidget {
  const _BarChartCard({
    required this.rows,
    required this.gran,
    required this.symbol,
  });

  final List<Tx> rows;
  final _Granularity gran;
  final String symbol;

  @override
  Widget build(BuildContext context) {
    final buckets = <int, int>{}; // bucket index -> expense minor
    final count = gran == _Granularity.month ? _daysInMonth : 12;
    for (final r in rows.where((r) => r.type == TxType.expense)) {
      final idx = gran == _Granularity.month
          ? r.occurredAt.day - 1
          : r.occurredAt.month - 1;
      buckets[idx] = (buckets[idx] ?? 0) + r.amountMinor;
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Spending trend',
                style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 12),
            SizedBox(
              height: 200,
              child: BarChart(
                BarChartData(
                  alignment: BarChartAlignment.spaceAround,
                  maxY: _maxY(buckets, count),
                  barTouchData: BarTouchData(
                    touchTooltipData: BarTouchTooltipData(
                      getTooltipItem: (group, _, _, _) => BarTooltipItem(
                        fmtAmount(symbol, group.barRods.first.toY.round()),
                        const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                  titlesData: FlTitlesData(
                    topTitles: const AxisTitles(),
                    rightTitles: const AxisTitles(),
                    leftTitles: const AxisTitles(),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 24,
                        getTitlesWidget: (v, _) => Text(_bucketLabel(v.toInt()),
                            style: const TextStyle(fontSize: 9)),
                      ),
                    ),
                  ),
                  gridData: const FlGridData(show: false),
                  borderData: FlBorderData(show: false),
                  barGroups: [
                    for (var i = 0; i < count; i++)
                      BarChartGroupData(x: i, barRods: [
                        BarChartRodData(
                          toY: (buckets[i] ?? 0).toDouble(),
                          width: gran == _Granularity.year ? 14 : 6,
                          borderRadius: BorderRadius.circular(3),
                          color: AppTheme.expenseColor(context),
                        )
                      ]),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  static int get _daysInMonth {
    final now = DateTime.now();
    return DateTime(now.year, now.month + 1, 0).day;
  }

  double _maxY(Map<int, int> buckets, int count) {
    var max = 0;
    for (var i = 0; i < count; i++) {
      max = (buckets[i] ?? 0) > max ? buckets[i]! : max;
    }
    return max <= 0 ? 10 : max * 1.15;
  }

  String _bucketLabel(int i) =>
      gran == _Granularity.month ? '${i + 1}' : _shortMonths[i];

  static const _shortMonths = [
    'J', 'F', 'M', 'A', 'M', 'J', 'J', 'A', 'S', 'O', 'N', 'D'
  ];
}

/// Category donut with total in the center and % labels on larger slices.
class _CategoryPieCard extends StatelessWidget {
  const _CategoryPieCard({
    required this.rows,
    required this.byId,
    required this.symbol,
    required this.title,
  });

  final List<Tx> rows;
  final Map<int, Category> byId;
  final String symbol;
  final String title;

  @override
  Widget build(BuildContext context) {
    final spend = <int, int>{};
    for (final r in rows.where((r) => r.type == TxType.expense)) {
      if (r.categoryId != null) {
        spend[r.categoryId!] = (spend[r.categoryId!] ?? 0) + r.amountMinor;
      }
    }
    if (spend.isEmpty) return const SizedBox.shrink();
    final total = spend.values.fold(0, (a, b) => a + b);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 12),
            SizedBox(
              height: 200,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  PieChart(
                    PieChartData(
                      sectionsSpace: 2,
                      centerSpaceRadius: 52,
                      sections: [
                        for (final e in spend.entries)
                          PieChartSectionData(
                            value: e.value.toDouble(),
                            radius: 44,
                            color: Color(byId[e.key]?.colorValue ?? 0xFF546E7A),
                            title: e.value * 100 ~/ total >= 8
                                ? '${e.value * 100 ~/ total}%'
                                : '',
                            titleStyle: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                      ],
                    ),
                  ),
                  IgnorePointer(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('Spent',
                            style: Theme.of(context).textTheme.bodySmall),
                        Text(fmtAmount(symbol, total),
                            style: Theme.of(context)
                                .textTheme
                                .titleSmall
                                ?.copyWith(fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TopCategories extends StatelessWidget {
  const _TopCategories({
    required this.rows,
    required this.byId,
    required this.symbol,
  });

  final List<Tx> rows;
  final Map<int, Category> byId;
  final String symbol;

  @override
  Widget build(BuildContext context) {
    final spend = <int, int>{};
    for (final r in rows.where((r) => r.type == TxType.expense)) {
      if (r.categoryId != null) {
        spend[r.categoryId!] = (spend[r.categoryId!] ?? 0) + r.amountMinor;
      }
    }
    if (spend.isEmpty) return const SizedBox.shrink();
    final total = spend.values.fold(0, (a, b) => a + b);
    final sorted = spend.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
              child: Text('Where the money went',
                  style: Theme.of(context).textTheme.titleSmall),
            ),
            for (final e in sorted.take(10))
              ListTile(
                dense: true,
                leading: CategoryIcon(
                  iconCode: byId[e.key]?.iconCode ?? 'more_horiz',
                  colorValue: byId[e.key]?.colorValue,
                  size: 32,
                ),
                title: Text(byId[e.key]?.name ?? 'Unknown'),
                subtitle: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: e.value / (total == 0 ? 1 : total),
                    minHeight: 4,
                    backgroundColor: Theme.of(context)
                        .colorScheme
                        .surfaceContainerHighest,
                    color: Color(byId[e.key]?.colorValue ?? 0xFF546E7A),
                  ),
                ),
                trailing: Text(
                  '${fmtAmount(symbol, e.value)}  '
                  '${e.value * 100 ~/ (total == 0 ? 1 : total)}%',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
          ],
        ),
      ),
    );
  }
}


