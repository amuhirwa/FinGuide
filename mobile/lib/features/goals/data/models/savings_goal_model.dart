/*
 * Savings Goal Model
 * ==================
 * Data model for savings goals
 */

import 'package:equatable/equatable.dart';

enum GoalPriority { low, medium, high, critical }

enum GoalStatus { active, paused, completed, cancelled }

class SavingsGoalModel extends Equatable {
  final int id;
  final String name;
  final String? description;
  final double targetAmount;
  final double currentAmount;
  final GoalPriority priority;
  final DateTime? deadline;
  final bool isFlexible;
  final GoalStatus status;
  final double dailyTarget;
  final double weeklyTarget;
  final double progressPercentage;
  final double remainingAmount;
  final DateTime createdAt;
  final DateTime? completedAt;

  const SavingsGoalModel({
    required this.id,
    required this.name,
    this.description,
    required this.targetAmount,
    required this.currentAmount,
    required this.priority,
    this.deadline,
    required this.isFlexible,
    required this.status,
    required this.dailyTarget,
    required this.weeklyTarget,
    required this.progressPercentage,
    required this.remainingAmount,
    required this.createdAt,
    this.completedAt,
  });

  factory SavingsGoalModel.fromJson(Map<String, dynamic> json) {
    return SavingsGoalModel(
      id: json['id'],
      name: json['name'],
      description: json['description'],
      targetAmount: (json['target_amount'] as num).toDouble(),
      currentAmount: (json['current_amount'] as num).toDouble(),
      priority: GoalPriority.values.firstWhere(
        (e) => e.name == json['priority'],
        orElse: () => GoalPriority.medium,
      ),
      deadline:
          json['deadline'] != null ? DateTime.parse(json['deadline']) : null,
      isFlexible: json['is_flexible'] ?? false,
      status: GoalStatus.values.firstWhere(
        (e) => e.name == json['status'],
        orElse: () => GoalStatus.active,
      ),
      dailyTarget: (json['daily_target'] as num?)?.toDouble() ?? 0,
      weeklyTarget: (json['weekly_target'] as num?)?.toDouble() ?? 0,
      progressPercentage:
          (json['progress_percentage'] as num?)?.toDouble() ?? 0,
      remainingAmount: (json['remaining_amount'] as num?)?.toDouble() ?? 0,
      createdAt: DateTime.parse(json['created_at']),
      completedAt: json['completed_at'] != null
          ? DateTime.parse(json['completed_at'])
          : null,
    );
  }

  Map<String, dynamic> toJson() => {
        'name': name,
        'description': description,
        'target_amount': targetAmount,
        'priority': priority.name,
        'deadline': deadline?.toIso8601String(),
        'is_flexible': isFlexible,
      };

  String get priorityDisplay {
    switch (priority) {
      case GoalPriority.low:
        return 'Low Priority';
      case GoalPriority.medium:
        return 'Medium Priority';
      case GoalPriority.high:
        return 'High Priority';
      case GoalPriority.critical:
        return 'Critical';
    }
  }

  String get statusDisplay {
    switch (status) {
      case GoalStatus.active:
        return 'Active';
      case GoalStatus.paused:
        return 'Paused';
      case GoalStatus.completed:
        return 'Completed';
      case GoalStatus.cancelled:
        return 'Cancelled';
    }
  }

  @override
  List<Object?> get props => [id, name, targetAmount, currentAmount, status];
}

class GoalContribution {
  final int id;
  final int goalId;
  final double amount;
  final String? note;
  final DateTime createdAt;

  GoalContribution({
    required this.id,
    required this.goalId,
    required this.amount,
    this.note,
    required this.createdAt,
  });

  factory GoalContribution.fromJson(Map<String, dynamic> json) {
    return GoalContribution(
      id: json['id'],
      goalId: json['goal_id'],
      amount: (json['amount'] as num).toDouble(),
      note: json['note'],
      createdAt: DateTime.parse(json['created_at']),
    );
  }
}
