import 'package:flutter_test/flutter_test.dart';
import 'package:expense_tracker/core/countries.dart';
import 'package:expense_tracker/core/enums.dart';
import 'package:expense_tracker/core/format.dart';
import 'package:expense_tracker/services/alert_engine.dart';

void main() {
  group('countries catalog', () {
    test('lookup is case-insensitive and returns currency data', () {
      final eg = findCountry('eg');
      expect(eg, isNotNull);
      expect(eg!.currencyCode, 'EGP');
      expect(findCountry('US')!.currencyCode, 'USD');
      expect(findCountry('ZZ'), isNull);
    });

    test('every entry has non-empty fields', () {
      for (final c in kCountries) {
        expect(c.code.length, 2, reason: c.name);
        expect(c.name, isNotEmpty);
        expect(c.flag, isNotEmpty);
        expect(c.currencyCode.length, 3, reason: c.name);
        expect(c.symbol, isNotEmpty, reason: c.name);
      }
    });

    test('search matches name and currency code', () {
      expect(searchCountries('saudi').map((c) => c.code), contains('SA'));
      expect(searchCountries('EGP').map((c) => c.code), contains('EG'));
      expect(searchCountries('zzzz'), isEmpty);
    });
  });

  group('DateX.addPeriods', () {
    test('daily adds N days', () {
      final d = DateTime(2026, 1, 10);
      expect(DateX.addPeriods(d, Frequency.daily, 5), DateTime(2026, 1, 15));
    });

    test('weekly adds 7*N days', () {
      final d = DateTime(2026, 1, 10);
      expect(DateX.addPeriods(d, Frequency.weekly, 2), DateTime(2026, 1, 24));
    });

    test('monthly clamps day-of-month at month end', () {
      final jan31 = DateTime(2026, 1, 31);
      expect(DateX.addPeriods(jan31, Frequency.monthly, 1), DateTime(2026, 2, 28));
    });

    test('monthly keeps normal days', () {
      final d = DateTime(2026, 1, 15);
      expect(DateX.addPeriods(d, Frequency.monthly, 1), DateTime(2026, 2, 15));
      expect(DateX.addPeriods(d, Frequency.monthly, 14), DateTime(2027, 3, 15));
    });

    test('yearly clamps Feb 29 leap years', () {
      final feb29 = DateTime(2024, 2, 29);
      expect(DateX.addPeriods(feb29, Frequency.yearly, 1), DateTime(2025, 2, 28));
      expect(DateX.addPeriods(feb29, Frequency.yearly, 4), DateTime(2028, 2, 29));
    });
  });

  group('MoneyFmt.parseToMinorUnits', () {
    test('parses plain numbers', () {
      expect(MoneyFmt.parseToMinorUnits('12.34'), 1234);
      expect(MoneyFmt.parseToMinorUnits('12'), 1200);
    });

    test('ignores junk characters', () {
      expect(MoneyFmt.parseToMinorUnits(''), 0);
      expect(MoneyFmt.parseToMinorUnits('abc'), 0);
    });
  });

  group('evaluateAlerts', () {
    AlertThresholds thresholds() => const AlertThresholds(
          lowBalancePct: 20,
          lowBalanceFloorMinor: 5000,
          savingsFloorMinor: 10000,
          budgetWarnPct: 80,
          monthCapWarnPct: 90,
          monthlyCapMinor: 0,
        );

    AlertSnapshot snap({
      int balance = 100000,
      int pot = 50000,
      int income = 200000,
      int expense = 30000,
      List<BudgetSnapshot> budgets = const [],
      List<GoalSnapshot> goals = const [],
      String monthKey = '2026-08',
    }) =>
        AlertSnapshot(
          balanceMinor: balance,
          savingsPotMinor: pot,
          monthIncomeMinor: income,
          monthExpenseMinor: expense,
          budgets: budgets,
          goals: goals,
          thresholds: thresholds(),
          monthKey: monthKey,
        );

    test('healthy finances produce no alerts', () {
      expect(evaluateAlerts(snap()), isEmpty);
    });

    test('low balance fires below absolute floor', () {
      final alerts = evaluateAlerts(snap(balance: 4000));
      expect(alerts.map((a) => a.scope), contains('lowBalance'));
    });

    test('low balance fires below % of income', () {
      // 20% of 200000 = 40000 > balance
      final alerts = evaluateAlerts(snap(balance: 30000));
      expect(alerts.any((a) => a.scope == 'lowBalance'), isTrue);
    });

    test('no low-balance alert when above floor and pct', () {
      expect(evaluateAlerts(snap(balance: 150000)), isEmpty);
    });

    test('low savings fires under floor', () {
      final alerts = evaluateAlerts(snap(pot: 9000));
      expect(alerts.any((a) => a.scope == 'lowSavings'), isTrue);
    });

    test('budget warning fires at warn pct', () {
      final alerts = evaluateAlerts(snap(budgets: [
        BudgetSnapshot('Food', 10000, 8500), // 85% >= 80%
      ]));
      expect(alerts.any((a) => a.scope.contains('budget')), isTrue);
    });

    test('budget warning silent under pct', () {
      final alerts = evaluateAlerts(snap(budgets: [
        BudgetSnapshot('Food', 10000, 5000),
      ]));
      expect(alerts, isEmpty);
    });

    test('monthly cap rule fires when enabled', () {
      final s = AlertSnapshot(
        balanceMinor: 100000,
        savingsPotMinor: 50000,
        monthIncomeMinor: 200000,
        monthExpenseMinor: 95000, // >= 90% of 100000 cap
        budgets: const [],
        goals: const [],
        thresholds: const AlertThresholds(
          lowBalancePct: 20,
          lowBalanceFloorMinor: 5000,
          savingsFloorMinor: 10000,
          budgetWarnPct: 80,
          monthCapWarnPct: 90,
          monthlyCapMinor: 100000,
        ),
        monthKey: '2026-08',
      );
      expect(evaluateAlerts(s).any((a) => a.scope == 'monthCap'), isTrue);
    });

    test('goal behind schedule detected near deadline', () {
      final created = DateTime.now().subtract(const Duration(days: 60));
      final soon = DateTime.now().add(const Duration(days: 30)); // 90-day span, 67% elapsed
      final g = GoalSnapshot(1, 'Car', 100000, 1000, soon, createdAt: created);
      final alerts = evaluateAlerts(snap(goals: [g]));
      expect(alerts.any((a) => a.scope == 'goalPace.1'), isTrue);
    });

    test('goal on pace is silent', () {
      final created = DateTime.now().subtract(const Duration(days: 45));
      final dl = DateTime.now().add(const Duration(days: 45)); // 50% elapsed
      final g = GoalSnapshot(2, 'Trip', 100000, 60000, dl, createdAt: created);
      expect(evaluateAlerts(snap(goals: [g])), isEmpty);
    });
  });
}
