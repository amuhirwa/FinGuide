/*
 * Investment Repository
 * =====================
 * Repository for investment data operations
 */

import 'package:dartz/dartz.dart';

import '../../../../core/network/api_client.dart';
import '../models/investment_model.dart';

class InvestmentRepository {
  final ApiClient _apiClient;

  InvestmentRepository(this._apiClient);

  Future<Either<String, List<InvestmentModel>>> getInvestments({
    String? status,
    String? investmentType,
  }) async {
    try {
      final response = await _apiClient.getInvestments(
        status: status,
        investmentType: investmentType,
      );

      final investments = (response as List)
          .map((i) => InvestmentModel.fromJson(i))
          .toList();

      return Right(investments);
    } catch (e) {
      return Left(e.toString());
    }
  }

  Future<Either<String, InvestmentModel>> createInvestment(
      Map<String, dynamic> data) async {
    try {
      final response = await _apiClient.createInvestment(data);
      return Right(InvestmentModel.fromJson(response));
    } catch (e) {
      return Left(e.toString());
    }
  }

  Future<Either<String, InvestmentSummary>> getInvestmentSummary() async {
    try {
      final response = await _apiClient.getInvestmentSummary();
      return Right(InvestmentSummary.fromJson(response));
    } catch (e) {
      return Left(e.toString());
    }
  }

  Future<Either<String, List<InvestmentAdvice>>> getInvestmentAdvice() async {
    try {
      final response = await _apiClient.getInvestmentAdvice();
      final advice = (response as List)
          .map((a) => InvestmentAdvice.fromJson(a))
          .toList();
      return Right(advice);
    } catch (e) {
      return Left(e.toString());
    }
  }

  Future<Either<String, InvestmentModel>> getInvestmentDetail(int id) async {
    try {
      final response = await _apiClient.getInvestmentDetail(id);
      return Right(InvestmentModel.fromJson(response));
    } catch (e) {
      return Left(e.toString());
    }
  }

  Future<Either<String, InvestmentModel>> updateInvestment(
      int id, Map<String, dynamic> data) async {
    try {
      final response = await _apiClient.updateInvestment(id, data);
      return Right(InvestmentModel.fromJson(response));
    } catch (e) {
      return Left(e.toString());
    }
  }

  Future<Either<String, void>> deleteInvestment(int id) async {
    try {
      await _apiClient.deleteInvestment(id);
      return const Right(null);
    } catch (e) {
      return Left(e.toString());
    }
  }

  Future<Either<String, ContributionModel>> addContribution(
      int investmentId, Map<String, dynamic> data) async {
    try {
      final response =
          await _apiClient.addInvestmentContribution(investmentId, data);
      return Right(ContributionModel.fromJson(response));
    } catch (e) {
      return Left(e.toString());
    }
  }

  Future<Either<String, List<ContributionModel>>> getContributions(
      int investmentId) async {
    try {
      final response =
          await _apiClient.getInvestmentContributions(investmentId);
      final contributions = (response as List)
          .map((c) => ContributionModel.fromJson(c))
          .toList();
      return Right(contributions);
    } catch (e) {
      return Left(e.toString());
    }
  }
}
