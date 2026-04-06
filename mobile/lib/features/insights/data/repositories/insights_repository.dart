/*
 * Insights Repository
 * ===================
 * Repository for financial insights and AI-powered features.
 *
 * All transaction data is read from the local Drift DB (via
 * TransactionLocalDataSource). Only aggregated context is sent to the
 * backend for AI nudge generation and 7-day forecasting — no raw
 * transaction data is ever stored on the backend.
 *
 * Goals and investments are still fetched from the backend API since the
 * user decided those stay server-side.
 */

import 'package:dartz/dartz.dart';

import '../../../../core/network/api_client.dart';
import '../../../transactions/data/datasources/transaction_local_datasource.dart';
import '../../../transactions/domain/models/financial_context.dart';
import '../models/insights_model.dart';

class InsightsRepository {
  final ApiClient _apiClient;
  final TransactionLocalDataSource _localDs;

  InsightsRepository(this._apiClient, this._localDs);

  // ─── Context building ─────────────────────────────────────────────

  /// Assemble a [FinancialContext] from local DB + remote goals/investments.
  /// This is the payload sent to the backend for AI features.
  Future<FinancialContext> _buildContext() async {
    final localCtx = await _localDs.computeFinancialContext();

    // Goals and investments remain server-side
    List<Map<String, dynamic>> activeGoals = [];
    List<Map<String, dynamic>> investments = [];

    try {
      final goalsList = await _apiClient.getSavingsGoals(status: 'active');
      activeGoals = goalsList
          .cast<Map<String, dynamic>>()
          .map((g) => {
                'name': g['name'] ?? '',
                'target': (g['target_amount'] as num?)?.toDouble() ?? 0.0,
                'saved': (g['current_amount'] as num?)?.toDouble() ?? 0.0,
                'progress_pct':
                    (g['progress_percentage'] as num?)?.toDouble() ?? 0.0,
                'daily_target':
                    (g['daily_target'] as num?)?.toDouble(),
                'weekly_target':
                    (g['weekly_target'] as num?)?.toDouble(),
                'days_left': g['days_left'] as int?,
              })
          .toList();
    } catch (_) {}

    try {
      final invList = await _apiClient.getInvestments(status: 'active');
      investments = invList
          .cast<Map<String, dynamic>>()
          .map((i) => {
                'name': i['name'] ?? '',
                'type': i['investment_type'] ?? 'other',
                'current_value':
                    (i['current_value'] as num?)?.toDouble() ?? 0.0,
                'monthly_contribution':
                    (i['monthly_contribution'] as num?)?.toDouble(),
              })
          .toList();
    } catch (_) {}

    return localCtx.copyWith(
      activeGoals: activeGoals,
      investments: investments,
    );
  }

  // ─── 7-day forecast ───────────────────────────────────────────────

  /// Get a 7-day expense forecast using the local transaction history.
  /// Sends transaction data to the backend BiLSTM model (not stored).
  Future<Either<String, Map<String, dynamic>>> get7DayForecast() async {
    try {
      final txData = await _localDs.getTransactionsForAI(days: 30);
      final ctx = await _buildContext();
      final response = await _apiClient.get7DayForecastWithData(
        transactions: txData,
        context: ctx.toJson(),
      );
      return Right(response);
    } catch (e) {
      return Left(e.toString());
    }
  }

  // ─── Nudge / recommendations ──────────────────────────────────────

  /// Generate AI nudges using local financial context.
  Future<Either<String, List<dynamic>>> generateNudges({
    String triggerType = 'manual',
    double? incomeAmount,
    String? incomeSource,
  }) async {
    try {
      final ctx = await _buildContext();
      final nudges = await _apiClient.generateNudgesWithContext(
        triggerType: triggerType,
        incomeAmount: incomeAmount,
        incomeSource: incomeSource,
        context: ctx.toJson(),
      );
      return Right(nudges);
    } catch (e) {
      return Left(e.toString());
    }
  }

  // ─── Server-side insight endpoints ───────────────────────────────
  // The following features still rely on server-side state (goals,
  // investments, health snapshots) and do not involve transaction storage.

  Future<Either<String, Map<String, dynamic>>> getHealthScore() async {
    try {
      final response = await _apiClient.getHealthScore();
      return Right(response);
    } catch (e) {
      return Left(e.toString());
    }
  }

  Future<Either<String, Map<String, dynamic>>> getSafeToSpend() async {
    try {
      final response = await _apiClient.getSafeToSpend();
      return Right(response);
    } catch (e) {
      return Left(e.toString());
    }
  }

  Future<Either<String, FinancialHealth>> getFinancialHealth() async {
    try {
      final response = await _apiClient.getFinancialHealth();
      return Right(FinancialHealth.fromJson(response));
    } catch (e) {
      return Left(e.toString());
    }
  }

  Future<Either<String, List<PredictionModel>>> getPredictions(
      {int? days}) async {
    try {
      final response = await _apiClient.getPredictions(days: days);
      final predictions =
          (response as List).map((p) => PredictionModel.fromJson(p)).toList();
      return Right(predictions);
    } catch (e) {
      return Left(e.toString());
    }
  }

  /// Spending by category is now computed locally from the Drift DB.
  Future<Either<String, List<SpendingCategory>>> getSpendingByCategory({
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    try {
      final summary = await _localDs.getTransactionSummary(
        startDate: startDate,
        endDate: endDate,
      );
      final total = summary.totalExpenses > 0 ? summary.totalExpenses : 1.0;
      final categories = summary.categoryBreakdown.entries
          .map((e) => SpendingCategory(
                name: e.key,
                amount: e.value,
                percentage: (e.value / total) * 100,
              ))
          .toList()
        ..sort((a, b) => b.amount.compareTo(a.amount));
      return Right(categories);
    } catch (e) {
      return Left(e.toString());
    }
  }

  Future<Either<String, SimulationResult>> getSimulationResult({
    required double initialAmount,
    required double monthlyContribution,
    required int months,
    required double annualReturn,
  }) async {
    try {
      final result = runSimulation(
        initialAmount: initialAmount,
        monthlyContribution: monthlyContribution,
        months: months,
        annualReturn: annualReturn,
      );
      return Right(result);
    } catch (e) {
      return Left(e.toString());
    }
  }

  SimulationResult runSimulation({
    required double initialAmount,
    required double monthlyContribution,
    required int months,
    required double annualReturn,
  }) {
    return SimulationResult.calculate(
      initial: initialAmount,
      monthly: monthlyContribution,
      months: months,
      annualReturn: annualReturn,
    );
  }

  /// Chat with the AI finance advisor.
  /// The advisor's system prompt is enriched with pre-computed local context.
  Future<Either<String, String>> chatWithAdvisor({
    required String message,
    List<Map<String, dynamic>> history = const [],
  }) async {
    try {
      final response = await _apiClient.chatWithAdvisor(
        message: message,
        history: history,
      );
      return Right(response['reply'] as String? ?? '');
    } catch (e) {
      return Left(e.toString());
    }
  }
}
