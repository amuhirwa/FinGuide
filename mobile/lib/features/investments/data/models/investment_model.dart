/*
 * Investment Model
 * ================
 * Data model for investments
 */

import 'package:equatable/equatable.dart';

enum InvestmentType {
  ejo_heza,
  rnit,
  savings_account,
  fixed_deposit,
  sacco,
  stocks,
  bonds,
  mutual_fund,
  real_estate,
  business,
  other,
}

enum InvestmentStatus {
  active,
  matured,
  withdrawn,
  paused,
}

class InvestmentModel extends Equatable {
  final int id;
  final String name;
  final InvestmentType investmentType;
  final String? description;
  final double initialAmount;
  final double currentValue;
  final double totalContributions;
  final double totalWithdrawals;
  final double expectedAnnualReturn;
  final double actualReturnToDate;
  final double monthlyContribution;
  final int contributionDay;
  final bool autoContribute;
  final DateTime startDate;
  final DateTime? maturityDate;
  final InvestmentStatus status;
  final String? institutionName;
  final String? accountNumber;
  final DateTime createdAt;
  final double? totalGain;
  final double? gainPercentage;

  const InvestmentModel({
    required this.id,
    required this.name,
    required this.investmentType,
    this.description,
    required this.initialAmount,
    required this.currentValue,
    required this.totalContributions,
    required this.totalWithdrawals,
    required this.expectedAnnualReturn,
    required this.actualReturnToDate,
    required this.monthlyContribution,
    required this.contributionDay,
    required this.autoContribute,
    required this.startDate,
    this.maturityDate,
    required this.status,
    this.institutionName,
    this.accountNumber,
    required this.createdAt,
    this.totalGain,
    this.gainPercentage,
  });

  factory InvestmentModel.fromJson(Map<String, dynamic> json) {
    return InvestmentModel(
      id: json['id'],
      name: json['name'],
      investmentType: InvestmentType.values.firstWhere(
        (e) => e.name == json['investment_type'],
        orElse: () => InvestmentType.other,
      ),
      description: json['description'],
      initialAmount: (json['initial_amount'] as num).toDouble(),
      currentValue: (json['current_value'] as num).toDouble(),
      totalContributions: (json['total_contributions'] as num).toDouble(),
      totalWithdrawals: (json['total_withdrawals'] as num).toDouble(),
      expectedAnnualReturn: (json['expected_annual_return'] as num).toDouble(),
      actualReturnToDate: (json['actual_return_to_date'] as num).toDouble(),
      monthlyContribution: (json['monthly_contribution'] as num).toDouble(),
      contributionDay: json['contribution_day'] ?? 1,
      autoContribute: json['auto_contribute'] ?? false,
      startDate: DateTime.parse(json['start_date']),
      maturityDate: json['maturity_date'] != null
          ? DateTime.parse(json['maturity_date'])
          : null,
      status: InvestmentStatus.values.firstWhere(
        (e) => e.name == json['status'],
        orElse: () => InvestmentStatus.active,
      ),
      institutionName: json['institution_name'],
      accountNumber: json['account_number'],
      createdAt: DateTime.parse(json['created_at']),
      totalGain: json['total_gain']?.toDouble(),
      gainPercentage: json['gain_percentage']?.toDouble(),
    );
  }

  Map<String, dynamic> toJson() => {
        'name': name,
        'investment_type': investmentType.name,
        'description': description,
        'initial_amount': initialAmount,
        'expected_annual_return': expectedAnnualReturn,
        'monthly_contribution': monthlyContribution,
        'contribution_day': contributionDay,
        'auto_contribute': autoContribute,
        'start_date': startDate.toIso8601String(),
        'maturity_date': maturityDate?.toIso8601String(),
        'institution_name': institutionName,
        'account_number': accountNumber,
      };

  String get typeDisplay {
    switch (investmentType) {
      case InvestmentType.ejo_heza:
        return 'Ejo Heza Pension';
      case InvestmentType.rnit:
        return 'RNIT';
      case InvestmentType.savings_account:
        return 'Savings Account';
      case InvestmentType.fixed_deposit:
        return 'Fixed Deposit';
      case InvestmentType.sacco:
        return 'SACCO';
      case InvestmentType.stocks:
        return 'Stocks';
      case InvestmentType.bonds:
        return 'Bonds';
      case InvestmentType.mutual_fund:
        return 'Mutual Fund';
      case InvestmentType.real_estate:
        return 'Real Estate';
      case InvestmentType.business:
        return 'Business';
      case InvestmentType.other:
        return 'Other';
    }
  }

  String get statusDisplay {
    switch (status) {
      case InvestmentStatus.active:
        return 'Active';
      case InvestmentStatus.matured:
        return 'Matured';
      case InvestmentStatus.withdrawn:
        return 'Withdrawn';
      case InvestmentStatus.paused:
        return 'Paused';
    }
  }

  @override
  List<Object?> get props => [id, name, investmentType, currentValue];
}

class InvestmentSummary {
  final double totalInvested;
  final double totalValue;
  final double totalGain;
  final double totalGainPercentage;
  final double monthlyContribution;
  final int investmentsCount;
  final int activeCount;
  final Map<String, dynamic> byType;

  InvestmentSummary({
    required this.totalInvested,
    required this.totalValue,
    required this.totalGain,
    required this.totalGainPercentage,
    required this.monthlyContribution,
    required this.investmentsCount,
    required this.activeCount,
    required this.byType,
  });

  factory InvestmentSummary.fromJson(Map<String, dynamic> json) {
    return InvestmentSummary(
      totalInvested: (json['total_invested'] as num?)?.toDouble() ?? 0,
      totalValue: (json['total_current_value'] as num?)?.toDouble() ?? 0,
      totalGain: (json['total_gain'] as num?)?.toDouble() ?? 0,
      totalGainPercentage:
          (json['overall_return_percentage'] as num?)?.toDouble() ?? 0,
      monthlyContribution:
          (json['monthly_contribution'] as num?)?.toDouble() ?? 0,
      investmentsCount: json['investments_count'] ?? 0,
      activeCount: json['active_investments'] ?? 0,
      byType: json['by_type'] ?? {},
    );
  }
}

class InvestmentAdvice {
  final String title;
  final String description;
  final String type;
  final String priority;
  final String? actionLabel;
  final String? actionUrl;

  InvestmentAdvice({
    required this.title,
    required this.description,
    required this.type,
    required this.priority,
    this.actionLabel,
    this.actionUrl,
  });

  factory InvestmentAdvice.fromJson(Map<String, dynamic> json) {
    return InvestmentAdvice(
      title: json['title'] ?? '',
      description: json['message'] ?? json['description'] ?? '',
      type: json['advice_type'] ?? json['type'] ?? 'info',
      priority: json['priority'] ?? 'low',
      actionLabel: json['action_label'],
      actionUrl: json['action_url'],
    );
  }
}

class ContributionModel {
  final int id;
  final int investmentId;
  final double amount;
  final bool isWithdrawal;
  final String? note;
  final DateTime contributionDate;
  final DateTime createdAt;

  ContributionModel({
    required this.id,
    required this.investmentId,
    required this.amount,
    required this.isWithdrawal,
    this.note,
    required this.contributionDate,
    required this.createdAt,
  });

  factory ContributionModel.fromJson(Map<String, dynamic> json) {
    return ContributionModel(
      id: json['id'],
      investmentId: json['investment_id'],
      amount: (json['amount'] as num).toDouble(),
      isWithdrawal: json['is_withdrawal'] ?? false,
      note: json['note'],
      contributionDate: DateTime.parse(json['contribution_date']),
      createdAt: DateTime.parse(json['created_at']),
    );
  }
}
