/*
 * RNIT Models
 * ===========
 * Data models for Rwanda National Investment Trust tracking
 */

class RnitPurchaseModel {
  final int id;
  final DateTime purchaseDate;
  final double amountRwf;
  final double? navAtPurchase;
  final double? units;
  final double? currentValue;
  final double? gainRwf;
  final double? gainPct;
  final String? rawSms;

  RnitPurchaseModel({
    required this.id,
    required this.purchaseDate,
    required this.amountRwf,
    this.navAtPurchase,
    this.units,
    this.currentValue,
    this.gainRwf,
    this.gainPct,
    this.rawSms,
  });

  factory RnitPurchaseModel.fromJson(Map<String, dynamic> json) {
    return RnitPurchaseModel(
      id: json['id'],
      purchaseDate: DateTime.parse(json['purchase_date']),
      amountRwf: (json['amount_rwf'] as num).toDouble(),
      navAtPurchase: json['nav_at_purchase'] != null
          ? (json['nav_at_purchase'] as num).toDouble()
          : null,
      units: json['units'] != null ? (json['units'] as num).toDouble() : null,
      currentValue: json['current_value'] != null
          ? (json['current_value'] as num).toDouble()
          : null,
      gainRwf: json['gain_rwf'] != null
          ? (json['gain_rwf'] as num).toDouble()
          : null,
      gainPct: json['gain_pct'] != null
          ? (json['gain_pct'] as num).toDouble()
          : null,
      rawSms: json['raw_sms'],
    );
  }
}

class RnitProjection {
  final double years;
  final double projectedValue;

  RnitProjection({required this.years, required this.projectedValue});

  factory RnitProjection.fromJson(Map<String, dynamic> json) {
    return RnitProjection(
      years: (json['years'] as num).toDouble(),
      projectedValue: (json['projected_value'] as num).toDouble(),
    );
  }
}

class RnitNavPoint {
  final DateTime date;
  final double nav;

  RnitNavPoint({required this.date, required this.nav});

  factory RnitNavPoint.fromJson(Map<String, dynamic> json) {
    return RnitNavPoint(
      date: DateTime.parse(json['date']),
      nav: (json['nav'] as num).toDouble(),
    );
  }
}

class RnitPortfolio {
  final double totalUnits;
  final double totalInvestedRwf;
  final double? currentNav;
  final double? currentValue;
  final double? totalGainRwf;
  final double? totalGainPct;
  final DateTime? firstPurchaseDate;
  final int purchaseCount;
  final double annualGrowthPct;
  final List<RnitProjection> projections;
  final List<RnitPurchaseModel> purchases;

  RnitPortfolio({
    required this.totalUnits,
    required this.totalInvestedRwf,
    this.currentNav,
    this.currentValue,
    this.totalGainRwf,
    this.totalGainPct,
    this.firstPurchaseDate,
    required this.purchaseCount,
    required this.annualGrowthPct,
    required this.projections,
    required this.purchases,
  });

  factory RnitPortfolio.fromJson(Map<String, dynamic> json) {
    return RnitPortfolio(
      totalUnits: (json['total_units'] as num).toDouble(),
      totalInvestedRwf: (json['total_invested_rwf'] as num).toDouble(),
      currentNav: json['current_nav'] != null
          ? (json['current_nav'] as num).toDouble()
          : null,
      currentValue: json['current_value'] != null
          ? (json['current_value'] as num).toDouble()
          : null,
      totalGainRwf: json['total_gain_rwf'] != null
          ? (json['total_gain_rwf'] as num).toDouble()
          : null,
      totalGainPct: json['total_gain_pct'] != null
          ? (json['total_gain_pct'] as num).toDouble()
          : null,
      firstPurchaseDate: json['first_purchase_date'] != null
          ? DateTime.parse(json['first_purchase_date'])
          : null,
      purchaseCount: json['purchase_count'],
      annualGrowthPct: (json['annual_growth_pct'] as num).toDouble(),
      projections: (json['projections'] as List)
          .map((p) => RnitProjection.fromJson(p))
          .toList(),
      purchases: (json['purchases'] as List)
          .map((p) => RnitPurchaseModel.fromJson(p))
          .toList(),
    );
  }
}

class PiggyBankModel {
  final double balance;
  final double totalContributed;
  final double totalWithdrawn;
  final int contributionCount;
  final int withdrawalCount;
  final List<PiggyBankParty> byParty;
  final List<PiggyBankContribution> recentContributions;

  PiggyBankModel({
    required this.balance,
    required this.totalContributed,
    required this.totalWithdrawn,
    required this.contributionCount,
    required this.withdrawalCount,
    required this.byParty,
    required this.recentContributions,
  });

  factory PiggyBankModel.fromJson(Map<String, dynamic> json) {
    return PiggyBankModel(
      balance: (json['balance'] as num).toDouble(),
      totalContributed: (json['total_contributed'] as num).toDouble(),
      totalWithdrawn: (json['total_withdrawn'] as num).toDouble(),
      contributionCount: json['contribution_count'],
      withdrawalCount: json['withdrawal_count'],
      byParty: (json['by_party'] as List)
          .map((p) => PiggyBankParty.fromJson(p))
          .toList(),
      recentContributions: (json['recent_contributions'] as List)
          .map((c) => PiggyBankContribution.fromJson(c))
          .toList(),
    );
  }
}

class PiggyBankParty {
  final String name;
  final double totalIn;
  final double totalOut;
  final int txCount;

  PiggyBankParty({
    required this.name,
    required this.totalIn,
    required this.totalOut,
    required this.txCount,
  });

  double get balance => totalIn - totalOut;

  factory PiggyBankParty.fromJson(Map<String, dynamic> json) {
    return PiggyBankParty(
      name: json['name'],
      totalIn: (json['total_in'] as num).toDouble(),
      totalOut: (json['total_out'] as num? ?? 0).toDouble(),
      txCount: json['tx_count'],
    );
  }
}

class PiggyBankContribution {
  final DateTime date;
  final double amount;
  final String party;

  PiggyBankContribution({
    required this.date,
    required this.amount,
    required this.party,
  });

  factory PiggyBankContribution.fromJson(Map<String, dynamic> json) {
    return PiggyBankContribution(
      date: DateTime.parse(json['date']),
      amount: (json['amount'] as num).toDouble(),
      party: json['party'],
    );
  }
}
