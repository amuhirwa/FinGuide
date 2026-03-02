/*
 * RNIT Detail Page
 * ================
 * Detailed view of RNIT portfolio: NAV chart, purchases, projections
 */

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../../../../core/di/injection.dart';
import '../../../../../core/theme/app_theme.dart';
import '../../data/models/rnit_model.dart';
import '../bloc/rnit_bloc.dart';

class RnitDetailPage extends StatelessWidget {
  const RnitDetailPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => getIt<RnitBloc>()..add(LoadRnitPortfolio()),
      child: const _RnitDetailView(),
    );
  }
}

class _RnitDetailView extends StatelessWidget {
  const _RnitDetailView();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FD),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: Text(
          'RNIT Portfolio',
          style: GoogleFonts.poppins(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: const Color(0xFF1E293B),
          ),
        ),
        actions: [
          BlocBuilder<RnitBloc, RnitState>(
            builder: (context, state) {
              final isRefreshing = state is RnitLoaded && state.refreshing;
              return isRefreshing
                  ? const Padding(
                      padding: EdgeInsets.all(12),
                      child: SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    )
                  : IconButton(
                      icon: const Icon(Icons.refresh),
                      tooltip: 'Refresh NAV data',
                      onPressed: () =>
                          context.read<RnitBloc>().add(RefreshRnitNav()),
                    );
            },
          ),
        ],
      ),
      body: BlocBuilder<RnitBloc, RnitState>(
        builder: (context, state) {
          if (state is RnitLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          if (state is RnitError) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.error_outline, size: 64, color: Colors.red[300]),
                  const SizedBox(height: 16),
                  Text(state.message,
                      style: GoogleFonts.inter(color: Colors.grey[600])),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () =>
                        context.read<RnitBloc>().add(LoadRnitPortfolio()),
                    child: const Text('Retry'),
                  ),
                ],
              ),
            );
          }

          if (state is RnitEmpty) {
            return _buildEmpty(context);
          }

          if (state is RnitLoaded) {
            return RefreshIndicator(
              onRefresh: () async =>
                  context.read<RnitBloc>().add(RefreshRnitNav()),
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _PortfolioHeader(portfolio: state.portfolio),
                    const SizedBox(height: 24),
                    if (state.navHistory.length > 1) ...[
                      _NavChart(navHistory: state.navHistory),
                      const SizedBox(height: 24),
                    ],
                    _ProjectionCards(portfolio: state.portfolio),
                    const SizedBox(height: 24),
                    _PurchaseHistory(purchases: state.portfolio.purchases),
                    const SizedBox(height: 40),
                  ],
                ),
              ),
            );
          }

          return const SizedBox.shrink();
        },
      ),
    );
  }

  Widget _buildEmpty(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: const Color(0xFF1B4332).withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.account_balance_outlined,
                size: 64,
                color: Color(0xFF1B4332),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'No RNIT purchases yet',
              style: GoogleFonts.poppins(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF1E293B),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Your RNIT investments will appear here automatically when MoMo SMS messages are detected.',
              style: GoogleFonts.inter(fontSize: 14, color: Colors.grey[600]),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

// ── Portfolio Header ──────────────────────────────────────────────────────────

class _PortfolioHeader extends StatelessWidget {
  final RnitPortfolio portfolio;
  const _PortfolioHeader({required this.portfolio});

  @override
  Widget build(BuildContext context) {
    final fmt = NumberFormat('#,###', 'en_US');
    final gainPct = portfolio.totalGainPct ?? 0.0;
    final isPositive = gainPct >= 0;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF1B4332), Color(0xFF2D6A4F)],
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF1B4332).withOpacity(0.3),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.account_balance,
                  color: Colors.white70, size: 16),
              const SizedBox(width: 6),
              Text(
                'Rwanda National Investment Trust',
                style: GoogleFonts.inter(fontSize: 12, color: Colors.white70),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'RWF ${fmt.format(portfolio.currentValue ?? portfolio.totalInvestedRwf)}',
            style: GoogleFonts.poppins(
              fontSize: 34,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: isPositive
                      ? Colors.greenAccent.withOpacity(0.3)
                      : Colors.redAccent.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  children: [
                    Icon(
                      isPositive ? Icons.trending_up : Icons.trending_down,
                      size: 14,
                      color: isPositive ? Colors.greenAccent : Colors.redAccent,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '${isPositive ? '+' : ''}${gainPct.toStringAsFixed(2)}%',
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color:
                            isPositive ? Colors.greenAccent : Colors.redAccent,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Text(
                'total gain',
                style: GoogleFonts.inter(fontSize: 12, color: Colors.white54),
              ),
            ],
          ),
          const SizedBox(height: 20),
          const Divider(color: Colors.white24),
          const SizedBox(height: 16),
          Row(
            children: [
              _HeaderStat(
                label: 'Invested',
                value: 'RWF ${fmt.format(portfolio.totalInvestedRwf)}',
              ),
              const SizedBox(width: 24),
              _HeaderStat(
                label: 'Units',
                value: portfolio.totalUnits.toStringAsFixed(4),
              ),
              const SizedBox(width: 24),
              _HeaderStat(
                label: 'NAV',
                value: portfolio.currentNav != null
                    ? 'RWF ${fmt.format(portfolio.currentNav!.toInt())}'
                    : 'N/A',
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _HeaderStat extends StatelessWidget {
  final String label;
  final String value;
  const _HeaderStat({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: GoogleFonts.inter(fontSize: 11, color: Colors.white54)),
          const SizedBox(height: 4),
          Text(value,
              style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Colors.white)),
        ],
      ),
    );
  }
}

// ── NAV History Chart ─────────────────────────────────────────────────────────

class _NavChart extends StatelessWidget {
  final List<RnitNavPoint> navHistory;
  const _NavChart({required this.navHistory});

  @override
  Widget build(BuildContext context) {
    final spots = <FlSpot>[];
    for (int i = 0; i < navHistory.length; i++) {
      spots.add(FlSpot(i.toDouble(), navHistory[i].nav));
    }

    final minY = navHistory.map((p) => p.nav).reduce((a, b) => a < b ? a : b);
    final maxY = navHistory.map((p) => p.nav).reduce((a, b) => a > b ? a : b);
    final padding = (maxY - minY) * 0.1;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'NAV History (last ${navHistory.length} days)',
            style: GoogleFonts.poppins(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: const Color(0xFF1E293B),
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 180,
            child: LineChart(
              LineChartData(
                minY: minY - padding,
                maxY: maxY + padding,
                gridData: const FlGridData(show: false),
                borderData: FlBorderData(show: false),
                titlesData: FlTitlesData(
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 56,
                      getTitlesWidget: (v, _) => Text(
                        NumberFormat('#,###').format(v.toInt()),
                        style: GoogleFonts.inter(
                            fontSize: 10, color: Colors.grey[500]),
                      ),
                    ),
                  ),
                  bottomTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false)),
                  topTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false)),
                ),
                lineBarsData: [
                  LineChartBarData(
                    spots: spots,
                    isCurved: true,
                    color: const Color(0xFF1B4332),
                    barWidth: 2.5,
                    dotData: const FlDotData(show: false),
                    belowBarData: BarAreaData(
                      show: true,
                      color: const Color(0xFF1B4332).withOpacity(0.12),
                    ),
                  ),
                ],
                lineTouchData: LineTouchData(
                  touchTooltipData: LineTouchTooltipData(
                  getTooltipColor: (touchedSpot) => const Color(0xFF1B4332),                    getTooltipItems: (touchedSpots) {
                      return touchedSpots.map((s) {
                        final point = navHistory[s.spotIndex];
                        return LineTooltipItem(
                          '${DateFormat('MMM d').format(point.date)}\n',
                          GoogleFonts.inter(
                              fontSize: 11, color: Colors.white70),
                          children: [
                            TextSpan(
                              text:
                                  'RWF ${NumberFormat('#,###').format(point.nav.toInt())}',
                              style: GoogleFonts.inter(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        );
                      }).toList();
                    },
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Projection Cards ──────────────────────────────────────────────────────────

class _ProjectionCards extends StatelessWidget {
  final RnitPortfolio portfolio;
  const _ProjectionCards({required this.portfolio});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Projections (${portfolio.annualGrowthPct.toStringAsFixed(0)}% p.a.)',
          style: GoogleFonts.poppins(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: const Color(0xFF1E293B),
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 110,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: portfolio.projections.length,
            separatorBuilder: (_, __) => const SizedBox(width: 12),
            itemBuilder: (_, i) {
              final proj = portfolio.projections[i];
              return _ProjectionCard(projection: proj);
            },
          ),
        ),
      ],
    );
  }
}

class _ProjectionCard extends StatelessWidget {
  final RnitProjection projection;
  const _ProjectionCard({required this.projection});

  @override
  Widget build(BuildContext context) {
    final fmt = NumberFormat('#,###', 'en_US');
    final years = projection.years.toInt();

    return Container(
      width: 140,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFF1B4332).withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              '$years ${years == 1 ? 'year' : 'years'}',
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF1B4332),
              ),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'RWF ${fmt.format(projection.projectedValue.toInt())}',
                style: GoogleFonts.poppins(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF1E293B),
                ),
              ),
              Text(
                'projected',
                style: GoogleFonts.inter(fontSize: 11, color: Colors.grey[500]),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Purchase History ──────────────────────────────────────────────────────────

class _PurchaseHistory extends StatelessWidget {
  final List<RnitPurchaseModel> purchases;
  const _PurchaseHistory({required this.purchases});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Purchase History',
          style: GoogleFonts.poppins(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: const Color(0xFF1E293B),
          ),
        ),
        const SizedBox(height: 12),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.06),
                blurRadius: 8,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Column(
            children: purchases.asMap().entries.map((entry) {
              final i = entry.key;
              final purchase = entry.value;
              return _PurchaseTile(
                purchase: purchase,
                isLast: i == purchases.length - 1,
              );
            }).toList(),
          ),
        ),
      ],
    );
  }
}

class _PurchaseTile extends StatelessWidget {
  final RnitPurchaseModel purchase;
  final bool isLast;
  const _PurchaseTile({required this.purchase, required this.isLast});

  @override
  Widget build(BuildContext context) {
    final fmt = NumberFormat('#,###', 'en_US');
    final gainPct = purchase.gainPct ?? 0.0;
    final isPositive = gainPct >= 0;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: const Color(0xFF1B4332).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.bar_chart_rounded,
                  color: Color(0xFF1B4332),
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      DateFormat('d MMM yyyy').format(purchase.purchaseDate),
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF1E293B),
                      ),
                    ),
                    Text(
                      '${purchase.units?.toStringAsFixed(4) ?? '-'} units @ RWF ${fmt.format((purchase.navAtPurchase ?? 0).toInt())}',
                      style: GoogleFonts.inter(
                          fontSize: 12, color: Colors.grey[600]),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    'RWF ${fmt.format(purchase.amountRwf.toInt())}',
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF1E293B),
                    ),
                  ),
                  if (purchase.gainPct != null)
                    Text(
                      '${isPositive ? '+' : ''}${gainPct.toStringAsFixed(1)}%',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: isPositive
                            ? const Color(0xFF22C55E)
                            : Colors.red[400],
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
        if (!isLast) const Divider(height: 1, indent: 70, endIndent: 16),
      ],
    );
  }
}
