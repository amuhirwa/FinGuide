/*
 * Goals Repository
 * ================
 * Repository for savings goals data operations
 */

import 'package:dartz/dartz.dart';

import '../../../../core/network/api_client.dart';
import '../models/savings_goal_model.dart';
import '../../../investments/data/models/rnit_model.dart';
import '../../../transactions/data/datasources/transaction_local_datasource.dart';

class GoalsRepository {
  final ApiClient _apiClient;
  final TransactionLocalDataSource _localDs;

  GoalsRepository(this._apiClient, this._localDs);

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

  Future<Either<String, PiggyBankModel>> getPiggybank() async {
    try {
      // Computed from the local DB — savings transactions no longer reach
      // the backend, so the server-side piggybank would always read zero.
      final response = await _localDs.computePiggybank();
      return Right(PiggyBankModel.fromJson(response));
    } catch (e) {
      return Left(e.toString());
    }
  }
}
