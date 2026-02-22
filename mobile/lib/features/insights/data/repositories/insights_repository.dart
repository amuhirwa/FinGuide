/*
 * Insights Repository
 * ===================
 * Repository for financial insights data
 */

import 'package:dartz/dartz.dart';

import '../../../../core/network/api_client.dart';
import '../models/insights_model.dart';

class InsightsRepository {
  final ApiClient _apiClient;

  InsightsRepository(this._apiClient);

  Future<Either<String, Map<String, dynamic>>> get7DayForecast() async {
    try {
      final response = await _apiClient.get7DayForecast();
      return Right(response);
    } catch (e) {
      return Left(e.toString());
    }
  }

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

  Future<Either<String, List<SpendingCategory>>> getSpendingByCategory({
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    try {
      final response = await _apiClient.getSpendingByCategory(
        startDate: startDate,
        endDate: endDate,
      );
      final categories =
          (response as List).map((c) => SpendingCategory.fromJson(c)).toList();
      return Right(categories);
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
}
