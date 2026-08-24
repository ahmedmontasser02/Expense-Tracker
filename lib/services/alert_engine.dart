// Pure, testable alert-rule evaluation. No Flutter or IO dependencies.

class AlertThresholds {
  const AlertThresholds({
    required this.lowBalancePct,
    required this.lowBalanceFloorMinor,
    required this.savingsFloorMinor,
    required this.budgetWarnPct,
    required this.monthCapWarnPct,
    required this.monthlyCapMinor,
  });

  final int lowBalancePct; // % of month income considered "low balance"
  final int lowBalanceFloorMinor;
  final int savingsFloorMinor;
  final int budgetWarnPct; // % of category limit that triggers a warning
  final int monthCapWarnPct;
  final int monthlyCapMinor; // 0 disables the cap rule
}

class BudgetSnapshot {
  const BudgetSnapshot(this.categoryName, this.limitMinor, this.spentMinor);

  final String categoryName;
  final int limitMinor;
  final int spentMinor;
}

class GoalSnapshot {
  const GoalSnapshot(this.id, this.name, this.targetMinor, this.savedMinor,
      this.deadline, {this.createdAt});

  final int id;
  final String name;
  final int targetMinor;
  final int savedMinor;
  final DateTime? deadline;
  final DateTime? createdAt;

  /// Behind schedule when actual savings are well under the linear pace
  /// expected between creation and the deadline.
  bool get isBehindSchedule {
    final dl = deadline;
    if (dl == null || targetMinor <= 0) return false;
    if (!dl.isAfter(DateTime.now())) return savedMinor < targetMinor;
    final start = createdAt;
    if (start == null || !start.isBefore(dl)) return false;
    final spanDays = dl.difference(start).inDays;
    if (spanDays <= 0) return false;
    final elapsedDays =
        DateTime.now().difference(start).inDays.clamp(0, spanDays);
    final fraction = elapsedDays / spanDays;
    if (fraction < 0.05) return false; // too early to judge
    final expected = targetMinor * fraction;
    return savedMinor < expected * 0.5;
  }
}

class AlertSnapshot {
  const AlertSnapshot({
    required this.balanceMinor,
    required this.savingsPotMinor,
    required this.monthIncomeMinor,
    required this.monthExpenseMinor,
    required this.budgets,
    required this.goals,
    required this.thresholds,
    required this.monthKey,
  });

  final int balanceMinor;
  final int savingsPotMinor;
  final int monthIncomeMinor;
  final int monthExpenseMinor;
  final List<BudgetSnapshot> budgets;
  final List<GoalSnapshot> goals;
  final AlertThresholds thresholds;
  final String monthKey;
}

class FiredAlert {
  const FiredAlert(this.scope, this.title, this.body);

  /// Stable dedup key; period token appended by caller.
  final String scope;
  final String title;
  final String body;
}

List<FiredAlert> evaluateAlerts(AlertSnapshot s) {
  final alerts = <FiredAlert>[];
  final t = s.thresholds;

  // 1. Low balance: below fixed floor OR below % of this month's income.
  final pctFloor = s.monthIncomeMinor * t.lowBalancePct ~/ 100;
  if (s.balanceMinor <= t.lowBalanceFloorMinor ||
      (s.monthIncomeMinor > 0 && s.balanceMinor < pctFloor)) {
    alerts.add(FiredAlert(
      'lowBalance',
      'Low balance',
      'Your available balance has dropped below your safety level.',
    ));
  }

  // 2. Low savings pot.
  if (s.savingsPotMinor < t.savingsFloorMinor) {
    alerts.add(FiredAlert(
      'lowSavings',
      'Savings running low',
      'Total savings are under your configured floor.',
    ));
  }

  // 3. Goals behind schedule.
  for (final g in s.goals) {
    if (g.isBehindSchedule) {
      alerts.add(FiredAlert(
        'goalPace.${g.id}',
        'Goal behind schedule: ${g.name}',
        'You may not reach this goal before its deadline at the current pace.',
      ));
    }
  }

  // 4. Category budgets nearing their limits.
  for (final b in s.budgets) {
    if (b.limitMinor > 0 &&
        b.spentMinor >= b.limitMinor * t.budgetWarnPct ~/ 100) {
      final pct = b.limitMinor > 0 ? b.spentMinor * 100 ~/ b.limitMinor : 100;
      alerts.add(FiredAlert(
        'budget.${s.monthKey}.${b.categoryName}',
        'Budget warning: ${b.categoryName}',
        'Spent $pct% of the ${s.monthKey} budget for ${b.categoryName}.',
      ));
    }
  }

  // 5. Monthly spending cap.
  if (t.monthlyCapMinor > 0) {
    final warnAt = t.monthlyCapMinor * t.monthCapWarnPct ~/ 100;
    if (s.monthExpenseMinor >= warnAt) {
      final pct = s.monthExpenseMinor * 100 ~/ t.monthlyCapMinor;
      alerts.add(FiredAlert(
        'monthCap',
        'Monthly spending cap warning',
        'You have used $pct% of your monthly spending cap.',
      ));
    }
  }

  return alerts;
}

