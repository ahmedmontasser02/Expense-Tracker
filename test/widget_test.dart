import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:expense_tracker/data/database.dart';
import 'package:expense_tracker/features/dashboard/dashboard_screen.dart';
import 'package:expense_tracker/providers/providers.dart';

/// Smoke test: seeded DB drives the dashboard UI.
///
/// Mounting/unmounting happens inside [tester.runAsync] because drift
/// schedules a zero-duration housekeeping timer whenever a watched query is
/// cancelled; under fake_async that timer stays pending and would fail the
/// pending-timer invariant.
void main() {
  testWidgets('dashboard renders balance card and sections', (tester) async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);

    await tester.runAsync(() async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [databaseProvider.overrideWithValue(db)],
          child: const MaterialApp(home: DashboardScreen()),
        ),
      );
      // Give drift streams a real-time window to emit their first rows.
      await Future<void>.delayed(const Duration(milliseconds: 300));
    });
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.byType(DashboardScreen), findsOneWidget);
    expect(find.textContaining('TOTAL BALANCE'), findsWidgets);
    expect(find.text('Plan'), findsOneWidget);
    expect(find.text('Recent'), findsOneWidget);

    await tester.runAsync(() async {
      await tester.pumpWidget(const SizedBox.shrink());
      // Let the disposal-triggered drift timer fire in real time.
      await Future<void>.delayed(const Duration(milliseconds: 100));
    });
  });
}
