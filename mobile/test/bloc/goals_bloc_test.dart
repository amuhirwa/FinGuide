/// BLoC tests for GoalsBloc.
///
/// Covers every event/state transition using bloc_test + mocktail.
/// No network calls, no GetIt, no platform channels.
library;

import 'package:bloc_test/bloc_test.dart';
import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:finguide/features/goals/data/models/savings_goal_model.dart';
import 'package:finguide/features/goals/data/repositories/goals_repository.dart';
import 'package:finguide/features/goals/presentation/bloc/goals_bloc.dart';
import 'package:finguide/features/investments/data/models/rnit_model.dart';

// ── Mocks ─────────────────────────────────────────────────────────────────────

class MockGoalsRepository extends Mock implements GoalsRepository {}

// ── Test Factories ────────────────────────────────────────────────────────────

SavingsGoalModel _makeGoal({
  int id = 1,
  String name = 'Emergency Fund',
  GoalStatus status = GoalStatus.active,
  double current = 20000,
  double target = 100000,
}) =>
    SavingsGoalModel(
      id: id,
      name: name,
      targetAmount: target,
      currentAmount: current,
      priority: GoalPriority.medium,
      isFlexible: false,
      status: status,
      dailyTarget: 500,
      weeklyTarget: 3500,
      progressPercentage: (current / target) * 100,
      remainingAmount: target - current,
      createdAt: DateTime(2025, 1, 1),
    );

PiggyBankModel _makePiggybank({double balance = 15000}) => PiggyBankModel(
      balance: balance,
      totalContributed: balance,
      totalWithdrawn: 0,
      contributionCount: 3,
      withdrawalCount: 0,
      byParty: [],
      recentContributions: [],
    );

// ── Main ──────────────────────────────────────────────────────────────────────

void main() {
  late MockGoalsRepository mockRepo;

  setUp(() {
    mockRepo = MockGoalsRepository();
    registerFallbackValue(<String, dynamic>{});
  });

  GoalsBloc makeBloc() => GoalsBloc(mockRepo);

  // ── LoadGoals ─────────────────────────────────────────────────────────────

  group('LoadGoals', () {
    blocTest<GoalsBloc, GoalsState>(
      'emits [GoalsLoading, GoalsLoaded] with goals and piggybank on success',
      build: () {
        when(() => mockRepo.getGoals(status: any(named: 'status')))
            .thenAnswer((_) async => Right([_makeGoal()]));
        when(() => mockRepo.getPiggybank())
            .thenAnswer((_) async => Right(_makePiggybank()));
        return makeBloc();
      },
      act: (bloc) => bloc.add(LoadGoals()),
      expect: () => [isA<GoalsLoading>(), isA<GoalsLoaded>()],
      verify: (bloc) {
        final s = bloc.state as GoalsLoaded;
        expect(s.goals.length, 1);
        expect(s.goals.first.name, 'Emergency Fund');
        expect(s.piggybank?.balance, 15000);
      },
    );

    blocTest<GoalsBloc, GoalsState>(
      'GoalsLoaded piggybank is null when getPiggybank fails',
      build: () {
        when(() => mockRepo.getGoals(status: any(named: 'status')))
            .thenAnswer((_) async => Right([_makeGoal()]));
        when(() => mockRepo.getPiggybank())
            .thenAnswer((_) async => const Left('Network error'));
        return makeBloc();
      },
      act: (bloc) => bloc.add(LoadGoals()),
      expect: () => [isA<GoalsLoading>(), isA<GoalsLoaded>()],
      verify: (bloc) {
        expect((bloc.state as GoalsLoaded).piggybank, isNull);
      },
    );

    blocTest<GoalsBloc, GoalsState>(
      'passes status filter to repository',
      build: () {
        when(() => mockRepo.getGoals(status: 'active'))
            .thenAnswer((_) async => Right([_makeGoal()]));
        when(() => mockRepo.getPiggybank())
            .thenAnswer((_) async => const Left(''));
        return makeBloc();
      },
      act: (bloc) => bloc.add(LoadGoals(status: 'active')),
      verify: (_) =>
          verify(() => mockRepo.getGoals(status: 'active')).called(1),
    );

    blocTest<GoalsBloc, GoalsState>(
      'emits [GoalsLoading, GoalsError] when repository fails',
      build: () {
        when(() => mockRepo.getGoals(status: any(named: 'status')))
            .thenAnswer((_) async => const Left('Network error'));
        return makeBloc();
      },
      act: (bloc) => bloc.add(LoadGoals()),
      expect: () => [isA<GoalsLoading>(), isA<GoalsError>()],
      verify: (bloc) {
        expect((bloc.state as GoalsError).message, 'Network error');
      },
    );

    blocTest<GoalsBloc, GoalsState>(
      'returns empty list when no goals exist',
      build: () {
        when(() => mockRepo.getGoals(status: any(named: 'status')))
            .thenAnswer((_) async => const Right([]));
        when(() => mockRepo.getPiggybank())
            .thenAnswer((_) async => Right(_makePiggybank(balance: 0)));
        return makeBloc();
      },
      act: (bloc) => bloc.add(LoadGoals()),
      verify: (bloc) {
        expect((bloc.state as GoalsLoaded).goals, isEmpty);
      },
    );
  });

  // ── CreateGoal ───────────────────────────────────────────────────────────

  group('CreateGoal', () {
    final payload = {
      'name': 'Laptop',
      'target_amount': 500000,
      'priority': 'high',
    };

    blocTest<GoalsBloc, GoalsState>(
      'emits [GoalsLoading, GoalCreated] on success',
      build: () {
        when(() => mockRepo.createGoal(any()))
            .thenAnswer((_) async => Right(_makeGoal(name: 'Laptop')));
        return makeBloc();
      },
      act: (bloc) => bloc.add(CreateGoal(payload)),
      expect: () => [isA<GoalsLoading>(), isA<GoalCreated>()],
      verify: (bloc) {
        expect((bloc.state as GoalCreated).goal.name, 'Laptop');
      },
    );

    blocTest<GoalsBloc, GoalsState>(
      'emits [GoalsLoading, GoalsError] on validation failure',
      build: () {
        when(() => mockRepo.createGoal(any()))
            .thenAnswer((_) async => const Left('Validation error'));
        return makeBloc();
      },
      act: (bloc) => bloc.add(CreateGoal(payload)),
      expect: () => [isA<GoalsLoading>(), isA<GoalsError>()],
      verify: (bloc) {
        expect((bloc.state as GoalsError).message, 'Validation error');
      },
    );

    blocTest<GoalsBloc, GoalsState>(
      'passes data map to repository unchanged',
      build: () {
        when(() => mockRepo.createGoal(any()))
            .thenAnswer((_) async => Right(_makeGoal()));
        return makeBloc();
      },
      act: (bloc) => bloc.add(CreateGoal(payload)),
      verify: (_) => verify(() => mockRepo.createGoal(payload)).called(1),
    );
  });

  // ── UpdateGoal ───────────────────────────────────────────────────────────

  group('UpdateGoal', () {
    blocTest<GoalsBloc, GoalsState>(
      'emits [GoalsLoading, GoalUpdated] on success',
      build: () {
        when(() => mockRepo.updateGoal(1, any()))
            .thenAnswer((_) async => Right(_makeGoal(name: 'Updated Fund')));
        return makeBloc();
      },
      act: (bloc) => bloc.add(UpdateGoal(1, {'name': 'Updated Fund'})),
      expect: () => [isA<GoalsLoading>(), isA<GoalUpdated>()],
      verify: (bloc) {
        expect((bloc.state as GoalUpdated).goal.name, 'Updated Fund');
      },
    );

    blocTest<GoalsBloc, GoalsState>(
      'emits [GoalsLoading, GoalsError] when goal not found',
      build: () {
        when(() => mockRepo.updateGoal(any(), any()))
            .thenAnswer((_) async => const Left('Goal not found'));
        return makeBloc();
      },
      act: (bloc) => bloc.add(UpdateGoal(99, {'name': 'X'})),
      expect: () => [isA<GoalsLoading>(), isA<GoalsError>()],
    );
  });

  // ── DeleteGoal ───────────────────────────────────────────────────────────

  group('DeleteGoal', () {
    blocTest<GoalsBloc, GoalsState>(
      'emits [GoalsLoading, GoalDeleted] on success',
      build: () {
        when(() => mockRepo.deleteGoal(1))
            .thenAnswer((_) async => const Right(null));
        return makeBloc();
      },
      act: (bloc) => bloc.add(DeleteGoal(1)),
      expect: () => [isA<GoalsLoading>(), isA<GoalDeleted>()],
    );

    blocTest<GoalsBloc, GoalsState>(
      'emits [GoalsLoading, GoalsError] on server error',
      build: () {
        when(() => mockRepo.deleteGoal(any()))
            .thenAnswer((_) async => const Left('Server error'));
        return makeBloc();
      },
      act: (bloc) => bloc.add(DeleteGoal(99)),
      expect: () => [isA<GoalsLoading>(), isA<GoalsError>()],
      verify: (bloc) {
        expect((bloc.state as GoalsError).message, 'Server error');
      },
    );

    blocTest<GoalsBloc, GoalsState>(
      'calls repository with correct id',
      build: () {
        when(() => mockRepo.deleteGoal(42))
            .thenAnswer((_) async => const Right(null));
        return makeBloc();
      },
      act: (bloc) => bloc.add(DeleteGoal(42)),
      verify: (_) => verify(() => mockRepo.deleteGoal(42)).called(1),
    );
  });

  // ── ContributeToGoal ─────────────────────────────────────────────────────

  group('ContributeToGoal', () {
    blocTest<GoalsBloc, GoalsState>(
      'emits [GoalsLoading, ContributionSuccess] on success',
      build: () {
        when(() => mockRepo.contributeToGoal(
              1,
              10000,
              note: any(named: 'note'),
            )).thenAnswer((_) async => Right(_makeGoal(current: 30000)));
        return makeBloc();
      },
      act: (bloc) =>
          bloc.add(ContributeToGoal(1, 10000, note: 'Monthly savings')),
      expect: () => [isA<GoalsLoading>(), isA<ContributionSuccess>()],
      verify: (bloc) {
        expect((bloc.state as ContributionSuccess).goal.currentAmount, 30000);
      },
    );

    blocTest<GoalsBloc, GoalsState>(
      'emits [GoalsLoading, ContributionSuccess] without a note',
      build: () {
        when(() => mockRepo.contributeToGoal(
              2,
              5000,
              note: any(named: 'note'),
            )).thenAnswer((_) async => Right(_makeGoal(id: 2)));
        return makeBloc();
      },
      act: (bloc) => bloc.add(ContributeToGoal(2, 5000)),
      expect: () => [isA<GoalsLoading>(), isA<ContributionSuccess>()],
    );

    blocTest<GoalsBloc, GoalsState>(
      'emits [GoalsLoading, GoalsError] on failure',
      build: () {
        when(() => mockRepo.contributeToGoal(
              any(),
              any(),
              note: any(named: 'note'),
            )).thenAnswer((_) async => const Left('Insufficient funds'));
        return makeBloc();
      },
      act: (bloc) => bloc.add(ContributeToGoal(1, 1000000)),
      expect: () => [isA<GoalsLoading>(), isA<GoalsError>()],
      verify: (bloc) {
        expect((bloc.state as GoalsError).message, 'Insufficient funds');
      },
    );

    blocTest<GoalsBloc, GoalsState>(
      'passes amount and note to repository',
      build: () {
        when(() => mockRepo.contributeToGoal(
              3,
              7500,
              note: 'Bonus',
            )).thenAnswer((_) async => Right(_makeGoal(id: 3)));
        return makeBloc();
      },
      act: (bloc) => bloc.add(ContributeToGoal(3, 7500, note: 'Bonus')),
      verify: (_) =>
          verify(() => mockRepo.contributeToGoal(3, 7500, note: 'Bonus'))
              .called(1),
    );
  });

  // ── State helpers ─────────────────────────────────────────────────────────

  group('GoalsLoaded.copyWith', () {
    test('preserves goals when only piggybank is updated', () {
      final goal = _makeGoal();
      final state = GoalsLoaded([goal]);
      final updated = state.copyWith(piggybank: _makePiggybank());

      expect(updated.goals, [goal]);
      expect(updated.piggybank?.balance, 15000);
    });

    test('preserves piggybank when only goals are updated', () {
      final piggy = _makePiggybank(balance: 5000);
      final state = GoalsLoaded([_makeGoal()], piggybank: piggy);
      final updated = state.copyWith(goals: [_makeGoal(id: 2)]);

      expect(updated.goals.first.id, 2);
      expect(updated.piggybank?.balance, 5000);
    });

    test('two GoalsLoaded with same data are equal', () {
      final g = _makeGoal();
      final a = GoalsLoaded([g]);
      final b = GoalsLoaded([g]);
      expect(a, equals(b));
    });
  });

  // ── Initial state ────────────────────────────────────────────────────────

  test('initial state is GoalsInitial', () {
    expect(makeBloc().state, isA<GoalsInitial>());
  });
}
