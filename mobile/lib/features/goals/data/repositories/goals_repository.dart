/*
 * Goals Repository
 * ================
 * Repository for savings goals data operations
 */

import 'package:dartz/dartz.dart';

import '../../../../core/network/api_client.dart';
import '../models/savings_goal_model.dart';

class GoalsRepository {
  final ApiClient _apiClient;

  GoalsRepository(this._apiClient);

  Future<Either<String, List<SavingsGoalModel>>> getGoals(
      {String? status}) async {
    try {
      final response = await _apiClient.getSavingsGoals(status: status);
      final goals =
          (response as List).map((g) => SavingsGoalModel.fromJson(g)).toList();
      return Right(goals);
    } catch (e) {
      return Left(e.toString());
    }
  }

  Future<Either<String, SavingsGoalModel>> createGoal(
      Map<String, dynamic> data) async {
    try {
      final response = await _apiClient.createSavingsGoal(data);
      return Right(SavingsGoalModel.fromJson(response));
    } catch (e) {
      return Left(e.toString());
    }
  }

  Future<Either<String, SavingsGoalModel>> getGoalDetail(int id) async {
    try {
      final response = await _apiClient.getSavingsGoal(id);
      return Right(SavingsGoalModel.fromJson(response));
    } catch (e) {
      return Left(e.toString());
    }
  }

  Future<Either<String, SavingsGoalModel>> updateGoal(
      int id, Map<String, dynamic> data) async {
    try {
      final response = await _apiClient.updateSavingsGoal(id, data);
      return Right(SavingsGoalModel.fromJson(response));
    } catch (e) {
      return Left(e.toString());
    }
  }

  Future<Either<String, void>> deleteGoal(int id) async {
    try {
      await _apiClient.deleteSavingsGoal(id);
      return const Right(null);
    } catch (e) {
      return Left(e.toString());
    }
  }

  Future<Either<String, SavingsGoalModel>> contributeToGoal(
    int goalId,
    double amount, {
    String? note,
  }) async {
    try {
      final response =
          await _apiClient.contributeToGoal(goalId, amount, note: note);
      return Right(SavingsGoalModel.fromJson(response));
    } catch (e) {
      return Left(e.toString());
    }
  }
}
