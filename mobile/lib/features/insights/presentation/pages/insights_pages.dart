/*
 * Insights Pages
 * ==============
 * Financial health, predictions, and investment simulator
 */

import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_theme.dart';
import '../../data/models/insights_model.dart';
import '../bloc/insights_bloc.dart';

// ==================== Financial Health Page ====================

class FinancialHealthPage extends StatefulWidget {
  const FinancialHealthPage({super.key});

  @override
  State<FinancialHealthPage> createState() => _FinancialHealthPageState();
}

class _FinancialHealthPageState extends State<FinancialHealthPage> {
  @override
  void initState() {
    super.initState();
    context.read<InsightsBloc>().add(LoadHealthScore());
  }

  @override
  Widget build(BuildContext context) {
    final format = NumberFormat('#,###', 'en_US');

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FD),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: Text(
          'Financial Health',
          style: GoogleFonts.poppins(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: const Color(0xFF1E293B),
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: AppColors.primary),
            onPressed: () {
              context.read<InsightsBloc>().add(LoadHealthScore());
            },
          ),
        ],
      ),
      body: BlocBuilder<InsightsBloc, InsightsState>(
        builder: (context, state) {
          if (state is InsightsLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          if (state is InsightsError) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.error_outline, size: 64, color: Colors.grey[300]),
                  const SizedBox(height: 16),
                  Text('Failed to load health score',
                      style: GoogleFonts.inter(color: Colors.grey[600])),
                  Text(state.message,
                      style: GoogleFonts.inter(
                          fontSize: 12, color: Colors.grey[500])),
                  const SizedBox(height: 8),
                  ElevatedButton(
                    onPressed: () =>
                        context.read<InsightsBloc>().add(LoadHealthScore()),
                    child: const Text('Retry'),
                  ),
                ],
              ),
            );
          }

          if (state is HealthScoreLoaded) {
            final score = state.healthScore;
            final overallScore = (score['overall_score'] as num?)?.toInt() ?? 0;
            final grade = score['grade'] as String? ?? 'N/A';
            final summary = score['summary'] as String? ?? '';

            return SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Main Score Card
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(32),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          AppColors.primary,
                          AppColors.primary.withOpacity(0.8),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.primary.withOpacity(0.3),
                          blurRadius: 20,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        Text(
                          'Your Financial Health',
                          style: GoogleFonts.poppins(
                            fontSize: 16,
                            color: Colors.white70,
                          ),
                        ),
                        const SizedBox(height: 16),
                        // Score Circle
                        Stack(
                          alignment: Alignment.center,
                          children: [
                            SizedBox(
                              width: 180,
                              height: 180,
                              child: CircularProgressIndicator(
                                value: overallScore / 100,
                                strokeWidth: 12,
                                backgroundColor: Colors.white.withOpacity(0.2),
                                valueColor: const AlwaysStoppedAnimation(
                                  Colors.white,
                                ),
                              ),
                            ),
                            Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  overallScore.toString(),
                                  style: GoogleFonts.poppins(
                                    fontSize: 56,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                                Text(
                                  'of 100',
                                  style: GoogleFonts.inter(
                                    fontSize: 16,
                                    color: Colors.white70,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),
                        // Grade Badge
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 24,
                            vertical: 12,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                'Grade: ',
                                style: GoogleFonts.inter(
                                  fontSize: 16,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                              Text(
                                grade,
                                style: GoogleFonts.poppins(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: _getGradeColor(grade),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          summary,
                          textAlign: TextAlign.center,
                          style: GoogleFonts.inter(
                            fontSize: 14,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Score Breakdown
                  Text(
                    'Component Scores',
                    style: GoogleFonts.poppins(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 16),
                  _ScoreComponentCard(
                    icon: Icons.trending_up,
                    label: 'Income Stability',
                    score:
                        (score['income_stability_score'] as num?)?.toInt() ?? 0,
                    color: AppColors.primary,
                  ),
                  const SizedBox(height: 12),
                  _ScoreComponentCard(
                    icon: Icons.savings,
                    label: 'Savings Rate',
                    score: (score['savings_rate_score'] as num?)?.toInt() ?? 0,
                    color: AppColors.success,
                    subtitle:
                        '${score['savings_rate']?.toStringAsFixed(1) ?? '0'}% of income saved',
                  ),
                  const SizedBox(height: 12),
                  _ScoreComponentCard(
                    icon: Icons.security,
                    label: 'Emergency Buffer',
                    score:
                        (score['emergency_buffer_score'] as num?)?.toInt() ?? 0,
                    color: AppColors.warning,
                    subtitle:
                        '${score['emergency_buffer_days'] ?? 0} days of expenses covered',
                  ),
                  const SizedBox(height: 12),
                  _ScoreComponentCard(
                    icon: Icons.flag,
                    label: 'Goal Progress',
                    score: (score['goal_progress_score'] as num?)?.toInt() ?? 0,
                    color: AppColors.secondary,
                  ),
                  const SizedBox(height: 12),
                  _ScoreComponentCard(
                    icon: Icons.account_balance_wallet,
                    label: 'Spending Discipline',
                    score:
                        (score['spending_discipline_score'] as num?)?.toInt() ??
                            0,
                    color: AppColors.info,
                  ),
                  const SizedBox(height: 24),

                  // Financial Summary
                  Text(
                    'Monthly Summary',
                    style: GoogleFonts.poppins(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: AppShadows.small,
                    ),
                    child: Column(
                      children: [
                        _SummaryRow(
                          icon: Icons.arrow_downward,
                          label: 'Average Income',
                          value:
                              '${format.format((score['monthly_income_avg'] as num?)?.toInt() ?? 0)} RWF',
                          color: AppColors.success,
                        ),
                        const Divider(height: 24),
                        _SummaryRow(
                          icon: Icons.arrow_upward,
                          label: 'Average Expenses',
                          value:
                              '${format.format((score['monthly_expense_avg'] as num?)?.toInt() ?? 0)} RWF',
                          color: AppColors.error,
                        ),
                        const Divider(height: 24),
                        _SummaryRow(
                          icon: Icons.timeline,
                          label: 'Score Change',
                          value:
                              '${((score['score_change'] as num?)?.toInt() ?? 0) > 0 ? '+' : ''}${score['score_change']} points',
                          color:
                              ((score['score_change'] as num?)?.toInt() ?? 0) >
                                      0
                                  ? AppColors.success
                                  : AppColors.error,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          }

          return const SizedBox();
        },
      ),
    );
  }

  Color _getGradeColor(String grade) {
    switch (grade) {
      case 'A':
        return AppColors.success;
      case 'B':
        return AppColors.primary;
      case 'C':
        return AppColors.warning;
      case 'D':
      case 'F':
        return AppColors.error;
      default:
        return AppColors.textSecondary;
    }
  }
}

class _ScoreComponentCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final int score;
  final Color color;
  final String? subtitle;

  const _ScoreComponentCard({
    required this.icon,
    required this.label,
    required this.score,
    required this.color,
    this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: AppShadows.small,
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color, size: 24),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        subtitle!,
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              Text(
                '$score',
                style: GoogleFonts.poppins(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: score / 100,
              minHeight: 8,
              backgroundColor: color.withOpacity(0.1),
              valueColor: AlwaysStoppedAnimation(color),
            ),
          ),
        ],
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _SummaryRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 14,
              color: AppColors.textSecondary,
            ),
          ),
        ),
        Text(
          value,
          style: GoogleFonts.inter(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
        ),
      ],
    );
  }
}

class _ScoreArcPainter extends CustomPainter {
  final double score;
  final Color color;

  _ScoreArcPainter({required this.score, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 10;

    // Background arc
    final bgPaint = Paint()
      ..color = Colors.grey[200]!
      ..style = PaintingStyle.stroke
      ..strokeWidth = 12
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi * 0.75,
      math.pi * 1.5,
      false,
      bgPaint,
    );

    // Progress arc
    final progressPaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 12
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi * 0.75,
      math.pi * 1.5 * score,
      false,
      progressPaint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

class _ScoreRow extends StatelessWidget {
  final String label;
  final int score;

  const _ScoreRow({required this.label, required this.score});

  @override
  Widget build(BuildContext context) {
    final color = score >= 70
        ? Colors.green
        : score >= 50
            ? Colors.orange
            : Colors.red;

    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 14,
              color: Colors.grey[700],
            ),
          ),
        ),
        SizedBox(
          width: 100,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: score / 100,
              minHeight: 8,
              backgroundColor: Colors.grey[200],
              valueColor: AlwaysStoppedAnimation(color),
            ),
          ),
        ),
        const SizedBox(width: 12),
        SizedBox(
          width: 32,
          child: Text(
            score.toString(),
            style: GoogleFonts.poppins(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: color,
            ),
            textAlign: TextAlign.right,
          ),
        ),
      ],
    );
  }
}

class _RecommendationCard extends StatelessWidget {
  final Recommendation rec;

  const _RecommendationCard({required this.rec});

  @override
  Widget build(BuildContext context) {
    final color = rec.priority == 'high'
        ? Colors.red
        : rec.priority == 'medium'
            ? Colors.orange
            : Colors.blue;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(Icons.lightbulb_outline, color: color, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  rec.title,
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF1E293B),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  rec.description,
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ==================== Predictions Page ====================

class PredictionsPage extends StatefulWidget {
  const PredictionsPage({super.key});

  @override
  State<PredictionsPage> createState() => _PredictionsPageState();
}

class _PredictionsPageState extends State<PredictionsPage> {
  @override
  void initState() {
    super.initState();
    context.read<InsightsBloc>().add(Load7DayForecast());
  }

  @override
  Widget build(BuildContext context) {
    final format = NumberFormat('#,###', 'en_US');

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FD),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: Text(
          'AI Expense Forecast',
          style: GoogleFonts.poppins(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: const Color(0xFF1E293B),
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: AppColors.primary),
            onPressed: () {
              context.read<InsightsBloc>().add(Load7DayForecast());
            },
          ),
        ],
      ),
      body: BlocBuilder<InsightsBloc, InsightsState>(
        builder: (context, state) {
          if (state is InsightsLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          if (state is InsightsError) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.error_outline, size: 64, color: Colors.grey[300]),
                  const SizedBox(height: 16),
                  Text('Failed to load forecast',
                      style: GoogleFonts.inter(color: Colors.grey[600])),
                  Text(state.message,
                      style: GoogleFonts.inter(
                          fontSize: 12, color: Colors.grey[500])),
                  const SizedBox(height: 8),
                  ElevatedButton(
                    onPressed: () =>
                        context.read<InsightsBloc>().add(Load7DayForecast()),
                    child: const Text('Retry'),
                  ),
                ],
              ),
            );
          }

          if (state is Forecast7DayLoaded) {
            final status = state.forecast['status'] as String?;

            if (status == 'insufficient_data') {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.insights, size: 64, color: Colors.grey[300]),
                      const SizedBox(height: 16),
                      Text(
                        'Not Enough Data Yet',
                        style: GoogleFonts.poppins(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey[700],
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        state.forecast['message'] as String? ??
                            'Add more transactions to enable AI predictions',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          color: Colors.grey[500],
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        state.forecast['nudge'] as String? ?? '',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          color: AppColors.primary,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }

            if (status != 'success' || state.forecast['forecast'] == null) {
              return Center(
                child: Text(
                  'Unable to generate forecast',
                  style: GoogleFonts.inter(color: Colors.grey[600]),
                ),
              );
            }

            final forecast = state.forecast['forecast'] as Map<String, dynamic>;
            final amount = forecast['total_amount_rwf'] as num? ?? 0;
            final category =
                forecast['likely_top_expense'] as String? ?? 'Other';
            final confidence = forecast['confidence_score'] as num? ?? 0;
            final isHighRisk = forecast['is_high_risk'] as bool? ?? false;
            final nudge = state.forecast['nudge'] as String? ?? '';

            return SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // AI Header Card
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          AppColors.primary,
                          AppColors.primary.withOpacity(0.8)
                        ],
                      ),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(
                            Icons.auto_awesome,
                            color: Colors.white,
                            size: 32,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '7-Day Forecast',
                                style: GoogleFonts.poppins(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Powered by BiLSTM Neural Network',
                                style: GoogleFonts.inter(
                                  fontSize: 12,
                                  color: Colors.white70,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Main Prediction Card
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.05),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Expected Expenses',
                          style: GoogleFonts.inter(
                            fontSize: 14,
                            color: Colors.grey[600],
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '${format.format(amount.round())} RWF',
                          style: GoogleFonts.poppins(
                            fontSize: 36,
                            fontWeight: FontWeight.bold,
                            color: isHighRisk
                                ? AppColors.error
                                : AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            _InfoChip(
                              icon: Icons.category,
                              label: category,
                              color: AppColors.secondary,
                            ),
                            const SizedBox(width: 8),
                            _InfoChip(
                              icon: Icons.speed,
                              label: '${confidence.toInt()}% Confident',
                              color: confidence > 70
                                  ? AppColors.success
                                  : AppColors.warning,
                            ),
                          ],
                        ),
                        if (isHighRisk) ...[
                          const SizedBox(height: 16),
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: AppColors.errorSurface,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.warning,
                                  color: AppColors.error,
                                  size: 20,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'High volatility detected - expenses may vary significantly',
                                    style: GoogleFonts.inter(
                                      fontSize: 12,
                                      color: AppColors.error,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Insight Explanation
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: AppColors.primarySurface,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: AppColors.primary.withOpacity(0.2),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(
                              Icons.lightbulb_outline,
                              color: AppColors.primary,
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Why am I seeing this?',
                              style: GoogleFonts.poppins(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: AppColors.primary,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          nudge,
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            color: AppColors.textSecondary,
                            height: 1.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Model Info
                  Text(
                    'About This Forecast',
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Column(
                      children: [
                        _ModelInfoRow(
                          icon: Icons.psychology,
                          title: 'Model Type',
                          value: 'Bidirectional LSTM',
                        ),
                        const Divider(height: 24),
                        _ModelInfoRow(
                          icon: Icons.timelapse,
                          title: 'Training Window',
                          value: 'Last 30 days',
                        ),
                        const Divider(height: 24),
                        _ModelInfoRow(
                          icon: Icons.update,
                          title: 'Updates',
                          value: 'Real-time with new transactions',
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          }

          return const SizedBox();
        },
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;

  const _InfoChip({
    required this.icon,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 6),
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

class _ModelInfoRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String value;

  const _ModelInfoRow({
    required this.icon,
    required this.title,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 20, color: AppColors.primary),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: GoogleFonts.inter(
                  fontSize: 12,
                  color: Colors.grey[600],
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _PredictionCard extends StatelessWidget {
  final PredictionModel prediction;
  final NumberFormat format;

  const _PredictionCard({required this.prediction, required this.format});

  @override
  Widget build(BuildContext context) {
    final riskColor = prediction.riskLevel == PredictionRisk.high
        ? Colors.red
        : prediction.riskLevel == PredictionRisk.medium
            ? Colors.orange
            : Colors.green;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                DateFormat('EEEE, MMM d').format(prediction.predictionDate),
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF1E293B),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: riskColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '${(prediction.confidenceScore * 100).toStringAsFixed(0)}% confidence',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: riskColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _PredictionValue(
                  label: 'Expected Income',
                  value: 'RWF ${format.format(prediction.predictedIncome)}',
                  color: Colors.green,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _PredictionValue(
                  label: 'Expected Expenses',
                  value: 'RWF ${format.format(prediction.predictedExpenses)}',
                  color: Colors.red,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.secondary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.savings_outlined,
                    color: AppColors.secondary, size: 20),
                const SizedBox(width: 8),
                Text(
                  'Potential Savings: RWF ${format.format(prediction.predictedSavings)}',
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.secondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PredictionValue extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _PredictionValue({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 12,
            color: Colors.grey[600],
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: GoogleFonts.poppins(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: color,
          ),
        ),
      ],
    );
  }
}

// ==================== Investment Simulator Page ====================

class InvestmentSimulatorPage extends StatefulWidget {
  const InvestmentSimulatorPage({super.key});

  @override
  State<InvestmentSimulatorPage> createState() =>
      _InvestmentSimulatorPageState();
}

class _InvestmentSimulatorPageState extends State<InvestmentSimulatorPage> {
  final _initialController = TextEditingController(text: '0');
  final _monthlyController = TextEditingController(text: '50000');

  double _months = 24;
  double _returnRate = 8;
  SimulationResult? _result;

  @override
  void initState() {
    super.initState();
    _runSimulation();
  }

  @override
  void dispose() {
    _initialController.dispose();
    _monthlyController.dispose();
    super.dispose();
  }

  void _runSimulation() {
    final initial = double.tryParse(_initialController.text) ?? 0;
    final monthly = double.tryParse(_monthlyController.text) ?? 0;

    setState(() {
      _result = SimulationResult.calculate(
        initial: initial,
        monthly: monthly,
        months: _months.toInt(),
        annualReturn: _returnRate,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final format = NumberFormat('#,###', 'en_US');

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FD),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: Text(
          'Investment Simulator',
          style: GoogleFonts.poppins(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: const Color(0xFF1E293B),
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Info Card
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, color: AppColors.primary),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'See how your savings can grow with compound interest',
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Inputs
            _buildLabel('Initial Investment (RWF)'),
            TextField(
              controller: _initialController,
              keyboardType: TextInputType.number,
              onChanged: (_) => _runSimulation(),
              decoration: _inputDecoration(),
            ),
            const SizedBox(height: 16),

            _buildLabel('Monthly Contribution (RWF)'),
            TextField(
              controller: _monthlyController,
              keyboardType: TextInputType.number,
              onChanged: (_) => _runSimulation(),
              decoration: _inputDecoration(),
            ),
            const SizedBox(height: 24),

            // Duration Slider
            _buildLabel('Investment Duration: ${_months.toInt()} months'),
            Slider(
              value: _months,
              min: 6,
              max: 120,
              divisions: 19,
              activeColor: AppColors.primary,
              onChanged: (value) {
                setState(() => _months = value);
                _runSimulation();
              },
            ),
            const SizedBox(height: 16),

            // Return Rate Slider
            _buildLabel(
                'Expected Annual Return: ${_returnRate.toStringAsFixed(1)}%'),
            Slider(
              value: _returnRate,
              min: 1,
              max: 20,
              divisions: 38,
              activeColor: AppColors.secondary,
              onChanged: (value) {
                setState(() => _returnRate = value);
                _runSimulation();
              },
            ),
            const SizedBox(height: 32),

            // Results
            if (_result != null) ...[
              Text(
                'Projection Results',
                style: GoogleFonts.poppins(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF1E293B),
                ),
              ),
              const SizedBox(height: 16),

              // Final Amount Card
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      AppColors.secondary,
                      AppColors.secondary.withOpacity(0.8)
                    ],
                  ),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Column(
                  children: [
                    Text(
                      'Final Amount',
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        color: Colors.white70,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'RWF ${format.format(_result!.finalAmount)}',
                      style: GoogleFonts.poppins(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Breakdown
              Row(
                children: [
                  Expanded(
                    child: _ResultCard(
                      label: 'Total Contributed',
                      value: 'RWF ${format.format(_result!.totalContributed)}',
                      icon: Icons.payments_outlined,
                      color: Colors.blue,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _ResultCard(
                      label: 'Interest Earned',
                      value: 'RWF ${format.format(_result!.totalReturns)}',
                      icon: Icons.trending_up,
                      color: Colors.green,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Growth Chart
              Container(
                height: 200,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: CustomPaint(
                  size: const Size(double.infinity, 168),
                  painter: _GrowthChartPainter(
                    projections: _result!.projections,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        text,
        style: GoogleFonts.inter(
          fontWeight: FontWeight.w500,
          color: Colors.grey[700],
        ),
      ),
    );
  }

  InputDecoration _inputDecoration() {
    return InputDecoration(
      filled: true,
      fillColor: Colors.white,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
    );
  }
}

class _ResultCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _ResultCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 8),
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 12,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: GoogleFonts.poppins(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: const Color(0xFF1E293B),
            ),
          ),
        ],
      ),
    );
  }
}

class _GrowthChartPainter extends CustomPainter {
  final List<SimulationPoint> projections;

  _GrowthChartPainter({required this.projections});

  @override
  void paint(Canvas canvas, Size size) {
    if (projections.isEmpty) return;

    final maxValue = projections.map((p) => p.value).reduce(math.max);
    final minValue = projections.first.value;
    final valueRange = maxValue - minValue;

    // Draw grid lines
    final gridPaint = Paint()
      ..color = Colors.grey[200]!
      ..strokeWidth = 1;

    for (int i = 0; i <= 4; i++) {
      final y = size.height * i / 4;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    // Draw area fill
    final fillPath = Path();
    final linePath = Path();

    for (int i = 0; i < projections.length; i++) {
      final x = size.width * i / (projections.length - 1);
      final y = valueRange > 0
          ? size.height -
              (projections[i].value - minValue) / valueRange * size.height
          : size.height / 2;

      if (i == 0) {
        fillPath.moveTo(x, size.height);
        fillPath.lineTo(x, y);
        linePath.moveTo(x, y);
      } else {
        fillPath.lineTo(x, y);
        linePath.lineTo(x, y);
      }
    }

    fillPath.lineTo(size.width, size.height);
    fillPath.close();

    // Fill gradient
    final fillPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          AppColors.primary.withOpacity(0.3),
          AppColors.primary.withOpacity(0.05),
        ],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));

    canvas.drawPath(fillPath, fillPaint);

    // Draw line
    final linePaint = Paint()
      ..color = AppColors.primary
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    canvas.drawPath(linePath, linePaint);

    // Draw points
    final pointPaint = Paint()..color = AppColors.primary;

    for (int i = 0; i < projections.length; i++) {
      final x = size.width * i / (projections.length - 1);
      final y = valueRange > 0
          ? size.height -
              (projections[i].value - minValue) / valueRange * size.height
          : size.height / 2;

      canvas.drawCircle(Offset(x, y), 4, pointPaint);
      canvas.drawCircle(Offset(x, y), 2, Paint()..color = Colors.white);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
