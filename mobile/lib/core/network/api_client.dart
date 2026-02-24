/*
 * API Client
 * ==========
 * Centralized HTTP client for API communication
 */

import 'package:dio/dio.dart';

import '../../features/auth/data/models/user_model.dart';
import '../../features/auth/data/models/auth_response_model.dart';

/// API Client for FinGuide backend
class ApiClient {
  final Dio _dio;

  ApiClient(this._dio);

  // Base URL - Update with your actual backend URL
  // static const String baseUrl =
  // 'http://10.0.2.2:8000/api/v1'; // Android emulator
  // static const String baseUrl = 'http://localhost:8000/api/v1'; // iOS simulator
  static const String baseUrl =
      'http://192.168.1.73:8000/api/v1'; // iOS simulator

  // ==================== Auth Endpoints ====================

  /// Register a new user
  Future<AuthResponseModel> register({
    required String phoneNumber,
    required String fullName,
    required String password,
    required String ubudeheCategory,
    required String incomeFrequency,
  }) async {
    final response = await _dio.post(
      '/auth/register',
      data: {
        'phone_number': phoneNumber,
        'full_name': fullName,
        'password': password,
        'ubudehe_category': ubudeheCategory,
        'income_frequency': incomeFrequency,
      },
    );

    return AuthResponseModel.fromJson(response.data);
  }

  /// Login user
  Future<AuthResponseModel> login({
    required String phoneNumber,
    required String password,
  }) async {
    final response = await _dio.post(
      '/auth/login',
      data: {'phone_number': phoneNumber, 'password': password},
    );

    return AuthResponseModel.fromJson(response.data);
  }

  /// Get current user profile
  Future<UserModel> getCurrentUser() async {
    final response = await _dio.get('/users/me');
    return UserModel.fromJson(response.data);
  }

  // ==================== Transactions ====================

  /// Get transactions list
  Future<Map<String, dynamic>> getTransactions({
    int page = 1,
    int pageSize = 20,
    String? transactionType,
    String? category,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    final queryParams = <String, dynamic>{
      'page': page,
      'page_size': pageSize,
    };
    if (transactionType != null)
      queryParams['transaction_type'] = transactionType;
    if (category != null) queryParams['category'] = category;
    if (startDate != null)
      queryParams['start_date'] = startDate.toIso8601String();
    if (endDate != null) queryParams['end_date'] = endDate.toIso8601String();

    final response =
        await _dio.get('/transactions', queryParameters: queryParams);
    return response.data;
  }

  /// Create a transaction
  Future<Map<String, dynamic>> createTransaction(
      Map<String, dynamic> data) async {
    final response = await _dio.post('/transactions', data: data);
    return response.data;
  }

  /// Get transaction summary
  Future<Map<String, dynamic>> getTransactionSummary({
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    final queryParams = <String, dynamic>{};
    if (startDate != null)
      queryParams['start_date'] = startDate.toIso8601String();
    if (endDate != null) queryParams['end_date'] = endDate.toIso8601String();

    final response =
        await _dio.get('/transactions/summary', queryParameters: queryParams);
    return response.data;
  }

  /// Parse SMS messages
  Future<Map<String, dynamic>> parseSmsMessages(List<String> messages) async {
    final response = await _dio.post(
      '/transactions/parse-sms',
      data: {'messages': messages},
    );
    return response.data;
  }

  /// Update transaction
  Future<Map<String, dynamic>> updateTransaction(
      int id, Map<String, dynamic> data) async {
    final response = await _dio.patch('/transactions/$id', data: data);
    return response.data;
  }

  // ==================== Savings Goals ====================

  /// Get all savings goals
  Future<List<dynamic>> getSavingsGoals({String? status}) async {
    final queryParams = <String, dynamic>{};
    if (status != null) queryParams['status'] = status;

    final response = await _dio.get('/goals', queryParameters: queryParams);
    return response.data;
  }

  /// Create a savings goal
  Future<Map<String, dynamic>> createSavingsGoal(
      Map<String, dynamic> data) async {
    final response = await _dio.post('/goals', data: data);
    return response.data;
  }

  /// Get a specific savings goal
  Future<Map<String, dynamic>> getSavingsGoal(int id) async {
    final response = await _dio.get('/goals/$id');
    return response.data;
  }

  /// Update a savings goal
  Future<Map<String, dynamic>> updateSavingsGoal(
      int id, Map<String, dynamic> data) async {
    final response = await _dio.patch('/goals/$id', data: data);
    return response.data;
  }

  /// Delete a savings goal
  Future<void> deleteSavingsGoal(int id) async {
    await _dio.delete('/goals/$id');
  }

  /// Contribute to a savings goal
  Future<Map<String, dynamic>> contributeToGoal(int goalId, double amount,
      {String? note}) async {
    final response = await _dio.post(
      '/goals/$goalId/contribute',
      data: {'amount': amount, 'note': note},
    );
    return response.data;
  }

  // ==================== Predictions & Insights ====================

  /// Get 7-day expense forecast (AI BiLSTM model)
  Future<Map<String, dynamic>> get7DayForecast() async {
    final response = await _dio.get('/predictions/forecast-7day');
    return response.data;
  }

  /// Get income predictions
  Future<List<dynamic>> getIncomePredictions() async {
    final response = await _dio.get('/predictions/income');
    return response.data;
  }

  /// Get expense predictions
  Future<List<dynamic>> getExpensePredictions() async {
    final response = await _dio.get('/predictions/expenses');
    return response.data;
  }

  /// Get financial health score
  Future<Map<String, dynamic>> getHealthScore() async {
    final response = await _dio.get('/predictions/health-score');
    return response.data;
  }

  /// Get safe-to-spend calculation
  Future<Map<String, dynamic>> getSafeToSpend() async {
    final response = await _dio.get('/predictions/safe-to-spend');
    return response.data;
  }

  /// Get financial health (comprehensive)
  Future<Map<String, dynamic>> getFinancialHealth() async {
    final response = await _dio.get('/insights/financial-health');
    return response.data;
  }

  /// Get predictions (general)
  Future<List<dynamic>> getPredictions({int? days}) async {
    final queryParams = <String, dynamic>{};
    if (days != null) queryParams['days'] = days;

    final response =
        await _dio.get('/insights/predictions', queryParameters: queryParams);
    return response.data;
  }

  /// Get spending by category
  Future<List<dynamic>> getSpendingByCategory({
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    final queryParams = <String, dynamic>{};
    if (startDate != null)
      queryParams['start_date'] = startDate.toIso8601String();
    if (endDate != null) queryParams['end_date'] = endDate.toIso8601String();

    final response = await _dio.get('/insights/spending-by-category',
        queryParameters: queryParams);
    return response.data;
  }

  /// Get recommendations
  Future<List<dynamic>> getRecommendations() async {
    final response = await _dio.get('/insights/recommendations');
    return response.data;
  }

  /// Update recommendation interaction
  Future<Map<String, dynamic>> updateRecommendation(
      int id, String action) async {
    final response = await _dio.patch(
      '/insights/recommendations/$id',
      data: {'action': action},
    );
    return response.data;
  }

  /// Simulate investment
  Future<Map<String, dynamic>> simulateInvestment({
    required String investmentType,
    required double principal,
    required double monthlyContribution,
    required int durationMonths,
  }) async {
    final response = await _dio.post(
      '/insights/simulate-investment',
      data: {
        'investment_type': investmentType,
        'principal': principal,
        'monthly_contribution': monthlyContribution,
        'duration_months': durationMonths,
      },
    );
    return response.data;
  }

  /// Get dashboard summary
  Future<Map<String, dynamic>> getDashboardSummary() async {
    final response = await _dio.get('/insights/dashboard');
    return response.data;
  }

  /// Get irregularity alerts
  Future<List<dynamic>> getIrregularities() async {
    final response = await _dio.get('/insights/irregularities');
    return response.data;
  }

  // ==================== Investments ====================

  /// Get all investments
  Future<List<dynamic>> getInvestments({
    String? status,
    String? investmentType,
  }) async {
    final queryParams = <String, dynamic>{};
    if (status != null) queryParams['status'] = status;
    if (investmentType != null) queryParams['investment_type'] = investmentType;

    final response =
        await _dio.get('/investments', queryParameters: queryParams);
    return response.data;
  }

  /// Create an investment
  Future<Map<String, dynamic>> createInvestment(
      Map<String, dynamic> data) async {
    final response = await _dio.post('/investments', data: data);
    return response.data;
  }

  /// Get investment summary
  Future<Map<String, dynamic>> getInvestmentSummary() async {
    final response = await _dio.get('/investments/summary');
    return response.data;
  }

  /// Get investment advice
  Future<List<dynamic>> getInvestmentAdvice() async {
    final response = await _dio.get('/investments/advice');
    return response.data;
  }

  /// Get investment detail
  Future<Map<String, dynamic>> getInvestmentDetail(int id) async {
    final response = await _dio.get('/investments/$id');
    return response.data;
  }

  /// Update investment
  Future<Map<String, dynamic>> updateInvestment(
      int id, Map<String, dynamic> data) async {
    final response = await _dio.patch('/investments/$id', data: data);
    return response.data;
  }

  /// Delete investment
  Future<void> deleteInvestment(int id) async {
    await _dio.delete('/investments/$id');
  }

  /// Add contribution to investment
  Future<Map<String, dynamic>> addInvestmentContribution(
      int investmentId, Map<String, dynamic> data) async {
    final response =
        await _dio.post('/investments/$investmentId/contribute', data: data);
    return response.data;
  }

  /// Get investment contributions
  Future<List<dynamic>> getInvestmentContributions(int investmentId) async {
    final response = await _dio.get('/investments/$investmentId/contributions');
    return response.data;
  }

  // ==================== Health Check ====================

  /// Check API health
  Future<bool> healthCheck() async {
    try {
      final response = await _dio.get('/health');
      return response.data['status'] == 'healthy';
    } catch (e) {
      return false;
    }
  }

  // ==================== Reports / Export ====================

  /// Export transactions report
  Future<Map<String, dynamic>> exportTransactions({
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    final queryParams = <String, dynamic>{};
    if (startDate != null)
      queryParams['start_date'] = startDate.toIso8601String();
    if (endDate != null) queryParams['end_date'] = endDate.toIso8601String();

    final response =
        await _dio.get('/reports/transactions', queryParameters: queryParams);
    return response.data;
  }

  /// Export goals report
  Future<Map<String, dynamic>> exportGoals() async {
    final response = await _dio.get('/reports/goals');
    return response.data;
  }

  /// Export investments report
  Future<Map<String, dynamic>> exportInvestments() async {
    final response = await _dio.get('/reports/investments');
    return response.data;
  }

  // ==================== Profile ====================

  /// Update user profile
  Future<Map<String, dynamic>> updateProfile(Map<String, dynamic> data) async {
    final response = await _dio.patch('/users/me', data: data);
    return response.data;
  }
}
