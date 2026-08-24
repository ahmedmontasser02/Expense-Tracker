import '../core/enums.dart';
import '../data/repositories/budgets_repo.dart';
import '../data/repositories/goals_repo.dart';
import '../data/repositories/logs_repo.dart';
import '../data/repositories/settings_repo.dart';
import '../data/repositories/transactions_repo.dart';
import 'alert_engine.dart';
import 'notification_service.dart';

/// Pulls a financial snapshot, evaluates rules, fires deduped notifications
/// and writes alert entries to the activity log.
class AlertService {
  AlertService({
    required TransactionsRepo transactions,
    required BudgetsRepo budgets,
    required GoalsRepo goals,
    required SettingsRepo settings,
    required LogsRepo logs,
  })  : _tx = transactions,
        _budgets = budgets,
        _goals = goals,
        _settings = settings,
        _logs = logs;

  final TransactionsRepo _tx;
  final BudgetsRepo _budgets;
  final GoalsRepo _goals;
  final SettingsRepo _settings;
  final LogsRepo _logs;

  Future<void> runChecks({DateTime? now}) async {
    if (!await _settings.getBool(SettingsRepo.notificationsEnabled)) return;
    final at = now ?? DateTime.now();
    final monthKey = _monthKey(at);

    final thresholds = await _loadThresholds();
    final balance = await _tx.currentBalance();
    final pot = await _tx.savingsPot();
    final from = DateTime(at.year, at.month);
    final to = DateTime(at.year, at.month + 1);
    final summary = await _tx.monthSummary(at);
    final spendByCat = await _tx.expenseByCategory(from, to);

    final budgetRows = await _budgets.forMonth(monthKey);
    final budgets = <BudgetSnapshot>[];
    for (final b in budgetRows) {
      try {
        final cat =
            await (_tx.db.select(_tx.db.categories)
                  ..where((c) => c.id.equals(b.categoryId)))
                .getSingle();
        budgets.add(BudgetSnapshot(
            cat.name, b.limitMinor, spendByCat[b.categoryId] ?? 0));
      } on StateError {
        continue; // category deleted since budget was set
      }
    }

    final goalRows = await _goals.watchGoalsWithProgress().first;
    final goals = [
      for (final g in goalRows)
        GoalSnapshot(g.goal.id, g.goal.name, g.goal.targetMinor, g.savedMinor,
            g.goal.deadline,
            createdAt: g.goal.createdAt),
    ];

    final snapshot = AlertSnapshot(
      balanceMinor: balance,
      savingsPotMinor: pot,
      monthIncomeMinor: summary.incomeMinor,
      monthExpenseMinor: summary.expenseMinor,
      budgets: budgets,
      goals: goals,
      thresholds: thresholds,
      monthKey: monthKey,
    );

    for (final alert in evaluateAlerts(snapshot)) {
      final token = alert.scope.startsWith('budget.') ? monthKey : _dayKey(at);
      final fresh = await _settings.shouldFire(alert.scope, token);
      if (!fresh) continue;
      await NotificationService.instance.showAlert(
        alert.scope.hashCode & 0x7fffffff,
        alert.title,
        alert.body,
      );
      await _logs.add(LogAction.alert, 'alert', null,
          '${alert.title} — ${alert.body}');
    }
  }

  Future<AlertThresholds> _loadThresholds() async => AlertThresholds(
        lowBalancePct: await _settings.getInt(SettingsRepo.lowBalancePct),
        lowBalanceFloorMinor:
            await _settings.getInt(SettingsRepo.lowBalanceFloorMinor),
        savingsFloorMinor:
            await _settings.getInt(SettingsRepo.savingsFloorMinor),
        budgetWarnPct: await _settings.getInt(SettingsRepo.budgetWarnPct),
        monthCapWarnPct: await _settings.getInt(SettingsRepo.monthCapWarnPct),
        monthlyCapMinor: await _settings.getInt(SettingsRepo.monthlyCapMinor),
      );

  static String _monthKey(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}';

  static String _dayKey(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
}
