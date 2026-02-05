/*
 * Insights Model
 * ==============
 * Data models for financial insights and predictions
 */

import 'package:equatable/equatable.dart';

// Financial Health
class FinancialHealth extends Equatable {
  final int overallScore;
  final String category;
  final BreakdownScores breakdown;
  final List<Recommendation> recommendations;

  const FinancialHealth({
    required this.overallScore,
    required this.category,
    required this.breakdown,
    required this.recommendations,
  });

  factory FinancialHealth.fromJson(Map<String, dynamic> json) {
    return FinancialHealth(
      overallScore: json['overall_score'],
      category: json['category'],
      breakdown: BreakdownScores.fromJson(json['breakdown']),
      recommendations: (json['recommendations'] as List?)
              ?.map((r) => Recommendation.fromJson(r))
              .toList() ??
          [],
    );
  }

  @override
  List<Object?> get props => [overallScore, category, breakdown];
}

class BreakdownScores extends Equatable {
  final int savingsRate;
  final int needsWantsBalance;
  final int incomeStability;
  final int goalProgress;

  const BreakdownScores({
    required this.savingsRate,
    required this.needsWantsBalance,
    required this.incomeStability,
    required this.goalProgress,
  });

  factory BreakdownScores.fromJson(Map<String, dynamic> json) {
    return BreakdownScores(
      savingsRate: json['savings_rate'] ?? 0,
      needsWantsBalance: json['needs_wants_balance'] ?? 0,
      incomeStability: json['income_stability'] ?? 0,
      goalProgress: json['goal_progress'] ?? 0,
    );
  }

  @override
  List<Object?> get props =>
      [savingsRate, needsWantsBalance, incomeStability, goalProgress];
}

class Recommendation {
  final String title;
  final String description;
  final String priority;
  final String? actionUrl;

  Recommendation({
    required this.title,
    required this.description,
    required this.priority,
    this.actionUrl,
  });

  factory Recommendation.fromJson(Map<String, dynamic> json) {
    return Recommendation(
      title: json['title'] ?? '',
      description: json['description'] ?? '',
      priority: json['priority'] ?? 'medium',
      actionUrl: json['action_url'],
    );
  }
}

// Predictions
class PredictionModel extends Equatable {
  final DateTime predictionDate;
  final double predictedIncome;
  final double predictedExpenses;
  final double predictedSavings;
  final double confidenceScore;
  final PredictionRisk riskLevel;

  const PredictionModel({
    required this.predictionDate,
    required this.predictedIncome,
    required this.predictedExpenses,
    required this.predictedSavings,
    required this.confidenceScore,
    required this.riskLevel,
  });

  factory PredictionModel.fromJson(Map<String, dynamic> json) {
    return PredictionModel(
      predictionDate: DateTime.parse(json['prediction_date']),
      predictedIncome: (json['predicted_income'] as num).toDouble(),
      predictedExpenses: (json['predicted_expenses'] as num).toDouble(),
      predictedSavings: (json['predicted_savings'] as num).toDouble(),
      confidenceScore: (json['confidence_score'] as num).toDouble(),
      riskLevel: PredictionRisk.values.firstWhere(
        (r) => r.name == json['risk_level'],
        orElse: () => PredictionRisk.medium,
      ),
    );
  }

  @override
  List<Object?> get props =>
      [predictionDate, predictedIncome, predictedExpenses];
}

enum PredictionRisk { low, medium, high }

// Spending Category Analysis
class SpendingCategory {
  final String name;
  final double amount;
  final double percentage;
  final double? change;

  SpendingCategory({
    required this.name,
    required this.amount,
    required this.percentage,
    this.change,
  });

  factory SpendingCategory.fromJson(Map<String, dynamic> json) {
    return SpendingCategory(
      name: json['name'],
      amount: (json['amount'] as num).toDouble(),
      percentage: (json['percentage'] as num).toDouble(),
      change: (json['change'] as num?)?.toDouble(),
    );
  }
}

// Investment Simulation Result
class SimulationResult {
  final double initialAmount;
  final double monthlyContribution;
  final int months;
  final double annualReturn;
  final double finalAmount;
  final double totalContributed;
  final double totalReturns;
  final List<SimulationPoint> projections;

  SimulationResult({
    required this.initialAmount,
    required this.monthlyContribution,
    required this.months,
    required this.annualReturn,
    required this.finalAmount,
    required this.totalContributed,
    required this.totalReturns,
    required this.projections,
  });

  factory SimulationResult.calculate({
    required double initial,
    required double monthly,
    required int months,
    required double annualReturn,
  }) {
    final monthlyRate = annualReturn / 12 / 100;
    double balance = initial;
    double totalContributed = initial;
    final projections = <SimulationPoint>[
      SimulationPoint(month: 0, value: initial),
    ];

    for (int i = 1; i <= months; i++) {
      balance = balance * (1 + monthlyRate) + monthly;
      totalContributed += monthly;
      if (i % 3 == 0 || i == months) {
        projections.add(SimulationPoint(month: i, value: balance));
      }
    }

    return SimulationResult(
      initialAmount: initial,
      monthlyContribution: monthly,
      months: months,
      annualReturn: annualReturn,
      finalAmount: balance,
      totalContributed: totalContributed,
      totalReturns: balance - totalContributed,
      projections: projections,
    );
  }
}

class SimulationPoint {
  final int month;
  final double value;

  SimulationPoint({required this.month, required this.value});
}
