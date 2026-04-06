/*
 * Financial Context
 * =================
 * Pre-computed financial summary assembled on-device from the local DB.
 * Sent to the backend for AI nudge generation and 7-day forecasting
 * without ever persisting raw transaction data server-side.
 */

class FinancialContext {
  final int contextWindowDays;
  final double income30d;
  final double expenses30d;
  final double estimatedBalance;
  final double savingsThisMonth;
  final List<Map<String, dynamic>> topExpenseCategories;
  final List<Map<String, dynamic>> activeGoals;
  final List<Map<String, dynamic>> investments;
  final Map<String, dynamic>? healthScore;

  const FinancialContext({
    required this.contextWindowDays,
    required this.income30d,
    required this.expenses30d,
    required this.estimatedBalance,
    required this.savingsThisMonth,
    required this.topExpenseCategories,
    required this.activeGoals,
    required this.investments,
    this.healthScore,
  });

  FinancialContext copyWith({
    List<Map<String, dynamic>>? activeGoals,
    List<Map<String, dynamic>>? investments,
    Map<String, dynamic>? healthScore,
  }) {
    return FinancialContext(
      contextWindowDays: contextWindowDays,
      income30d: income30d,
      expenses30d: expenses30d,
      estimatedBalance: estimatedBalance,
      savingsThisMonth: savingsThisMonth,
      topExpenseCategories: topExpenseCategories,
      activeGoals: activeGoals ?? this.activeGoals,
      investments: investments ?? this.investments,
      healthScore: healthScore ?? this.healthScore,
    );
  }

  Map<String, dynamic> toJson() => {
        'context_window_days': contextWindowDays,
        'income_30d': income30d,
        'expenses_30d': expenses30d,
        'estimated_balance': estimatedBalance,
        'savings_this_month': savingsThisMonth,
        'top_expense_categories': topExpenseCategories,
        'active_goals': activeGoals,
        'investments': investments,
        if (healthScore != null) 'health_score': healthScore,
      };
}
