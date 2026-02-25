/*
 * RNIT Repository
 * ===============
 * Repository for Rwanda National Investment Trust data operations
 */

import 'package:dartz/dartz.dart';

import '../../../../core/network/api_client.dart';
import '../models/rnit_model.dart';

class RnitRepository {
  final ApiClient _apiClient;

  RnitRepository(this._apiClient);

  Future<Either<String, RnitPortfolio>> getPortfolio() async {
    try {
      final response = await _apiClient.getRnitPortfolio();
      return Right(RnitPortfolio.fromJson(response));
    } catch (e) {
      return Left(e.toString());
    }
  }

  Future<Either<String, List<RnitNavPoint>>> getNavHistory(
      {int limit = 90}) async {
    try {
      final response = await _apiClient.getRnitNavHistory(limit: limit);
      final points = (response).map((p) => RnitNavPoint.fromJson(p)).toList();
      return Right(points);
    } catch (e) {
      return Left(e.toString());
    }
  }

  Future<Either<String, Map<String, dynamic>>> refreshNav() async {
    try {
      final response = await _apiClient.refreshRnitNav();
      return Right(response);
    } catch (e) {
      return Left(e.toString());
    }
  }
}
