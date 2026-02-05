/*
 * Application Router Configuration
 * =================================
 * GoRouter setup for declarative navigation
 */

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../di/injection.dart';
import '../../features/splash/presentation/pages/splash_page.dart';
import '../../features/onboarding/presentation/pages/onboarding_page.dart';
import '../../features/auth/presentation/pages/login_page.dart';
import '../../features/auth/presentation/pages/register_page.dart';
import '../../features/dashboard/presentation/pages/dashboard_page.dart';

// Transactions
import '../../features/transactions/presentation/bloc/transaction_bloc.dart';
import '../../features/transactions/presentation/pages/transactions_page.dart';

// Goals
import '../../features/goals/presentation/bloc/goals_bloc.dart';
import '../../features/goals/presentation/pages/goals_page.dart';

// Insights
import '../../features/insights/presentation/bloc/insights_bloc.dart';
import '../../features/insights/presentation/pages/insights_pages.dart';

/// Application route names
class Routes {
  Routes._();

  static const String splash = '/';
  static const String onboarding = '/onboarding';
  static const String login = '/login';
  static const String register = '/register';
  static const String dashboard = '/dashboard';

  // Transactions
  static const String transactions = '/transactions';
  static const String addTransaction = '/transactions/add';
  static const String smsImport = '/transactions/sms-import';

  // Goals
  static const String goals = '/goals';
  static const String createGoal = '/goals/create';

  // Insights
  static const String financialHealth = '/insights/health';
  static const String predictions = '/insights/predictions';
  static const String investmentSimulator = '/insights/simulator';
}

/// GoRouter configuration
class AppRouter {
  AppRouter._();

  static final GoRouter router = GoRouter(
    initialLocation: Routes.splash,
    debugLogDiagnostics: true,
    routes: [
      // Splash Screen
      GoRoute(
        path: Routes.splash,
        name: 'splash',
        builder: (context, state) => const SplashPage(),
      ),

      // Onboarding
      GoRoute(
        path: Routes.onboarding,
        name: 'onboarding',
        builder: (context, state) => const OnboardingPage(),
      ),

      // Authentication
      GoRoute(
        path: Routes.login,
        name: 'login',
        builder: (context, state) => const LoginPage(),
      ),
      GoRoute(
        path: Routes.register,
        name: 'register',
        builder: (context, state) => const RegisterPage(),
      ),

      // Dashboard
      GoRoute(
        path: Routes.dashboard,
        name: 'dashboard',
        builder: (context, state) => const DashboardPage(),
      ),

      // ==================== Transactions ====================
      GoRoute(
        path: Routes.transactions,
        name: 'transactions',
        builder: (context, state) => BlocProvider(
          create: (_) => getIt<TransactionBloc>(),
          child: const TransactionsPage(),
        ),
      ),
      GoRoute(
        path: Routes.addTransaction,
        name: 'addTransaction',
        builder: (context, state) => BlocProvider(
          create: (_) => getIt<TransactionBloc>(),
          child: const AddTransactionPage(),
        ),
      ),
      GoRoute(
        path: Routes.smsImport,
        name: 'smsImport',
        builder: (context, state) => BlocProvider(
          create: (_) => getIt<TransactionBloc>(),
          child: const SmsImportPage(),
        ),
      ),

      // ==================== Goals ====================
      GoRoute(
        path: Routes.goals,
        name: 'goals',
        builder: (context, state) => BlocProvider(
          create: (_) => getIt<GoalsBloc>(),
          child: const GoalsPage(),
        ),
      ),
      GoRoute(
        path: Routes.createGoal,
        name: 'createGoal',
        builder: (context, state) => BlocProvider(
          create: (_) => getIt<GoalsBloc>(),
          child: const CreateGoalPage(),
        ),
      ),

      // ==================== Insights ====================
      GoRoute(
        path: Routes.financialHealth,
        name: 'financialHealth',
        builder: (context, state) => BlocProvider(
          create: (_) => getIt<InsightsBloc>(),
          child: const FinancialHealthPage(),
        ),
      ),
      GoRoute(
        path: Routes.predictions,
        name: 'predictions',
        builder: (context, state) => BlocProvider(
          create: (_) => getIt<InsightsBloc>(),
          child: const PredictionsPage(),
        ),
      ),
      GoRoute(
        path: Routes.investmentSimulator,
        name: 'investmentSimulator',
        builder: (context, state) => BlocProvider(
          create: (_) => getIt<InsightsBloc>(),
          child: const InvestmentSimulatorPage(),
        ),
      ),
    ],

    // Error page
    errorBuilder: (context, state) =>
        Scaffold(body: Center(child: Text('Page not found: ${state.uri}'))),
  );
}
