/*
 * Transaction Repository
 * ======================
 * Repository for transaction data operations
 */

import 'package:dartz/dartz.dart';

import '../../../../core/network/api_client.dart';
import '../models/transaction_model.dart';

class TransactionRepository {
  final ApiClient _apiClient;

  TransactionRepository(this._apiClient);

  Future<Either<String, List<TransactionModel>>> getTransactions({
    int page = 1,
    int pageSize = 20,
    String? transactionType,
    String? category,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    try {
      final response = await _apiClient.getTransactions(
        page: page,
        pageSize: pageSize,
        transactionType: transactionType,
        category: category,
        startDate: startDate,
        endDate: endDate,
      );

      final transactions = (response['transactions'] as List)
          .map((t) => TransactionModel.fromJson(t))
          .toList();

      return Right(transactions);
    } catch (e) {
      return Left(e.toString());
    }
  }

  Future<Either<String, TransactionModel>> createTransaction(
      Map<String, dynamic> data) async {
    try {
      final response = await _apiClient.createTransaction(data);
      return Right(TransactionModel.fromJson(response));
    } catch (e) {
      return Left(e.toString());
    }
  }

  Future<Either<String, TransactionModel>> updateTransaction(
      int id, Map<String, dynamic> data) async {
    try {
      final response = await _apiClient.updateTransaction(id, data);
      return Right(TransactionModel.fromJson(response));
    } catch (e) {
      return Left(e.toString());
    }
  }

  Future<Either<String, TransactionSummary>> getTransactionSummary({
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    try {
      final response = await _apiClient.getTransactionSummary(
        startDate: startDate,
        endDate: endDate,
      );
      return Right(TransactionSummary.fromJson(response));
    } catch (e) {
      return Left(e.toString());
    }
  }

  Future<Either<String, List<TransactionModel>>> parseSmsMessages(
      List<String> messages) async {
    try {
      final response = await _apiClient.parseSmsMessages(messages);
      final transactions = (response['transactions'] as List)
          .map((t) => TransactionModel.fromJson(t))
          .toList();
      return Right(transactions);
    } catch (e) {
      return Left(e.toString());
    }
  }
}
