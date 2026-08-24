/// Domain enums shared across layers. Stored in Drift via intEnum indexes.
enum CategoryType { expense, income }

enum TxType { expense, income, savingsDeposit, savingsWithdrawal }

enum Frequency { daily, weekly, monthly, yearly }

enum LogAction { created, updated, deleted, generated, alert }

extension TxTypeX on TxType {
  bool get isExpense => this == TxType.expense;
  bool get isIncome => this == TxType.income;
  bool get isSavings =>
      this == TxType.savingsDeposit || this == TxType.savingsWithdrawal;

  String get label => switch (this) {
        TxType.expense => 'Expense',
        TxType.income => 'Income',
        TxType.savingsDeposit => 'Savings Deposit',
        TxType.savingsWithdrawal => 'Savings Withdrawal',
      };
}

extension FrequencyX on Frequency {
  String get label => switch (this) {
        Frequency.daily => 'Daily',
        Frequency.weekly => 'Weekly',
        Frequency.monthly => 'Monthly',
        Frequency.yearly => 'Yearly',
      };
}
