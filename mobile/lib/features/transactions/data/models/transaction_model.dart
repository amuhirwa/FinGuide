/*
 * Transaction Model
 * =================
 * Data model for transactions
 */

import 'package:equatable/equatable.dart';

enum TransactionType { income, expense, transfer }

enum TransactionCategory {
  // Income
  salary,
  freelance,
  business,
  gift_received,
  refund,
  other_income,
  // Expense - Needs
  food_groceries,
  transport,
  utilities,
  rent,
  healthcare,
  education,
  // Expense - Wants
  entertainment,
  shopping,
  dining_out,
  airtime_data,
  subscriptions,
  // Savings
  savings,
  ejo_heza,
  investment,
  // Other
  transfer_out,
  fees,
  other,
}

enum NeedWantCategory { need, want, savings, uncategorized }

class TransactionModel extends Equatable {
  final int id;
  final TransactionType transactionType;
  final TransactionCategory category;
  final NeedWantCategory needWant;
  final double amount;
  final String? description;
  final String? counterparty;
  final String? counterpartyName;
  final String? reference;
  final DateTime transactionDate;
  final double? confidenceScore;
  final bool isVerified;
  final DateTime createdAt;

  const TransactionModel({
    required this.id,
    required this.transactionType,
    required this.category,
    required this.needWant,
    required this.amount,
    this.description,
    this.counterparty,
    this.counterpartyName,
    this.reference,
    required this.transactionDate,
    this.confidenceScore,
    required this.isVerified,
    required this.createdAt,
  });

  factory TransactionModel.fromJson(Map<String, dynamic> json) {
    return TransactionModel(
      id: json['id'],
      transactionType: TransactionType.values.firstWhere(
        (e) => e.name == json['transaction_type'],
        orElse: () => TransactionType.expense,
      ),
      category: TransactionCategory.values.firstWhere(
        (e) => e.name == json['category'],
        orElse: () => TransactionCategory.other,
      ),
      needWant: NeedWantCategory.values.firstWhere(
        (e) => e.name == json['need_want'],
        orElse: () => NeedWantCategory.uncategorized,
      ),
      amount: (json['amount'] as num).toDouble(),
      description: json['description'],
      counterparty: json['counterparty'],
      counterpartyName: json['counterparty_name'],
      reference: json['reference'],
      transactionDate: DateTime.parse(json['transaction_date']),
      confidenceScore: json['confidence_score']?.toDouble(),
      isVerified: json['is_verified'] ?? false,
      createdAt: DateTime.parse(json['created_at']),
    );
  }

  Map<String, dynamic> toJson() => {
        'transaction_type': transactionType.name,
        'category': category.name,
        'need_want': needWant.name,
        'amount': amount,
        'description': description,
        'counterparty': counterparty,
        'counterparty_name': counterpartyName,
        'reference': reference,
        'transaction_date': transactionDate.toIso8601String(),
      };

  String get categoryDisplay {
    switch (category) {
      case TransactionCategory.salary:
        return 'Salary';
      case TransactionCategory.freelance:
        return 'Freelance';
      case TransactionCategory.business:
        return 'Business';
      case TransactionCategory.gift_received:
        return 'Gift';
      case TransactionCategory.refund:
        return 'Refund';
      case TransactionCategory.other_income:
        return 'Other Income';
      case TransactionCategory.food_groceries:
        return 'Food & Groceries';
      case TransactionCategory.transport:
        return 'Transport';
      case TransactionCategory.utilities:
        return 'Utilities';
      case TransactionCategory.rent:
        return 'Rent';
      case TransactionCategory.healthcare:
        return 'Healthcare';
      case TransactionCategory.education:
        return 'Education';
      case TransactionCategory.entertainment:
        return 'Entertainment';
      case TransactionCategory.shopping:
        return 'Shopping';
      case TransactionCategory.dining_out:
        return 'Dining Out';
      case TransactionCategory.airtime_data:
        return 'Airtime/Data';
      case TransactionCategory.subscriptions:
        return 'Subscriptions';
      case TransactionCategory.savings:
        return 'Savings';
      case TransactionCategory.ejo_heza:
        return 'Ejo Heza';
      case TransactionCategory.investment:
        return 'Investment';
      case TransactionCategory.transfer_out:
        return 'Transfer';
      case TransactionCategory.fees:
        return 'Fees';
      case TransactionCategory.other:
        return 'Other';
    }
  }

  @override
  List<Object?> get props =>
      [id, transactionType, category, amount, transactionDate];
}

class TransactionSummary {
  final double totalIncome;
  final double totalExpenses;
  final double netFlow;
  final int transactionCount;
  final Map<String, double> categoryBreakdown;
  final Map<String, double> needWantBreakdown;

  TransactionSummary({
    required this.totalIncome,
    required this.totalExpenses,
    required this.netFlow,
    required this.transactionCount,
    required this.categoryBreakdown,
    required this.needWantBreakdown,
  });

  factory TransactionSummary.fromJson(Map<String, dynamic> json) {
    return TransactionSummary(
      totalIncome: (json['total_income'] as num).toDouble(),
      totalExpenses: (json['total_expenses'] as num).toDouble(),
      netFlow: (json['net_flow'] as num).toDouble(),
      transactionCount: json['transaction_count'],
      categoryBreakdown: Map<String, double>.from(
        (json['category_breakdown'] as Map).map(
          (k, v) => MapEntry(k.toString(), (v as num).toDouble()),
        ),
      ),
      needWantBreakdown: Map<String, double>.from(
        (json['need_want_breakdown'] as Map).map(
          (k, v) => MapEntry(k.toString(), (v as num).toDouble()),
        ),
      ),
    );
  }
}
