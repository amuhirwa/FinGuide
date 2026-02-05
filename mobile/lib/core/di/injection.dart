/*
 * Dependency Injection Configuration
 * ===================================
 * GetIt service locator setup with Injectable
 */

import 'package:get_it/get_it.dart';
import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../network/api_client.dart';
import '../network/api_interceptor.dart';
import '../../features/auth/data/datasources/auth_local_datasource.dart';
import '../../features/auth/data/datasources/auth_remote_datasource.dart';
import '../../features/auth/data/repositories/auth_repository_impl.dart';
import '../../features/auth/domain/repositories/auth_repository.dart';
import '../../features/auth/domain/usecases/login_usecase.dart';
import '../../features/auth/domain/usecases/register_usecase.dart';
import '../../features/auth/domain/usecases/check_auth_usecase.dart';
import '../../features/auth/presentation/bloc/auth_bloc.dart';

// Transactions
import '../../features/transactions/data/repositories/transaction_repository.dart';
import '../../features/transactions/presentation/bloc/transaction_bloc.dart';

// Goals
import '../../features/goals/data/repositories/goals_repository.dart';
import '../../features/goals/presentation/bloc/goals_bloc.dart';

// Insights
import '../../features/insights/data/repositories/insights_repository.dart';
import '../../features/insights/presentation/bloc/insights_bloc.dart';

final GetIt getIt = GetIt.instance;

/// Initialize all dependencies
Future<void> configureDependencies() async {
  // External Dependencies
  final sharedPreferences = await SharedPreferences.getInstance();
  getIt.registerSingleton<SharedPreferences>(sharedPreferences);

  const secureStorage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );
  getIt.registerSingleton<FlutterSecureStorage>(secureStorage);

  // Network
  getIt.registerLazySingleton<Dio>(() {
    final dio = Dio(
      BaseOptions(
        baseUrl: ApiClient.baseUrl,
        connectTimeout: const Duration(seconds: 30),
        receiveTimeout: const Duration(seconds: 30),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      ),
    );
    dio.interceptors.add(ApiInterceptor(getIt<FlutterSecureStorage>()));
    return dio;
  });

  getIt.registerLazySingleton<ApiClient>(() => ApiClient(getIt<Dio>()));

  // ==================== Auth Feature ====================
  // Data Sources
  getIt.registerLazySingleton<AuthLocalDataSource>(
    () => AuthLocalDataSourceImpl(
      secureStorage: getIt<FlutterSecureStorage>(),
      sharedPreferences: getIt<SharedPreferences>(),
    ),
  );

  getIt.registerLazySingleton<AuthRemoteDataSource>(
    () => AuthRemoteDataSourceImpl(apiClient: getIt<ApiClient>()),
  );

  // Repositories
  getIt.registerLazySingleton<AuthRepository>(
    () => AuthRepositoryImpl(
      remoteDataSource: getIt<AuthRemoteDataSource>(),
      localDataSource: getIt<AuthLocalDataSource>(),
    ),
  );

  // Use Cases
  getIt.registerLazySingleton(() => LoginUseCase(getIt<AuthRepository>()));
  getIt.registerLazySingleton(() => RegisterUseCase(getIt<AuthRepository>()));
  getIt.registerLazySingleton(() => CheckAuthUseCase(getIt<AuthRepository>()));

  // BLoC
  getIt.registerFactory<AuthBloc>(
    () => AuthBloc(
      loginUseCase: getIt<LoginUseCase>(),
      registerUseCase: getIt<RegisterUseCase>(),
      checkAuthUseCase: getIt<CheckAuthUseCase>(),
      localDataSource: getIt<AuthLocalDataSource>(),
    ),
  );

  // ==================== Transactions Feature ====================
  getIt.registerLazySingleton<TransactionRepository>(
    () => TransactionRepository(getIt<ApiClient>()),
  );

  getIt.registerFactory<TransactionBloc>(
    () => TransactionBloc(getIt<TransactionRepository>()),
  );

  // ==================== Goals Feature ====================
  getIt.registerLazySingleton<GoalsRepository>(
    () => GoalsRepository(getIt<ApiClient>()),
  );

  getIt.registerFactory<GoalsBloc>(
    () => GoalsBloc(getIt<GoalsRepository>()),
  );

  // ==================== Insights Feature ====================
  getIt.registerLazySingleton<InsightsRepository>(
    () => InsightsRepository(getIt<ApiClient>()),
  );

  getIt.registerFactory<InsightsBloc>(
    () => InsightsBloc(getIt<InsightsRepository>()),
  );
}
