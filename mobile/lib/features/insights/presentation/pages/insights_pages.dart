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
    context.read<InsightsBloc>().add(LoadFinancialHealth());
  }

  @override
  Widget build(BuildContext context) {
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
                  const SizedBox(height: 8),
                  ElevatedButton(
                    onPressed: () =>
                        context.read<InsightsBloc>().add(LoadFinancialHealth()),
                    child: const Text('Retry'),
                  ),
                ],
              ),
            );
          }

          if (state is FinancialHealthLoaded) {
            return _buildHealthContent(state.health);
          }

          return const SizedBox();
        },
      ),
    );
  }

  Widget _buildHealthContent(FinancialHealth health) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Score Card
          _buildScoreCard(health),
          const SizedBox(height: 24),

          // Breakdown
          Text(
            'Score Breakdown',
            style: GoogleFonts.poppins(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: const Color(0xFF1E293B),
            ),
          ),
          const SizedBox(height: 16),
          _buildBreakdownCard(health.breakdown),
          const SizedBox(height: 24),

          // Recommendations
          if (health.recommendations.isNotEmpty) ...[
            Text(
              'Recommendations',
              style: GoogleFonts.poppins(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF1E293B),
              ),
            ),
            const SizedBox(height: 16),
            ...health.recommendations.map((r) => _RecommendationCard(rec: r)),
          ],
        ],
      ),
    );
  }

  Widget _buildScoreCard(FinancialHealth health) {
    final color = _getScoreColor(health.overallScore);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          // Circular Score
          SizedBox(
            width: 160,
            height: 160,
            child: Stack(
              alignment: Alignment.center,
              children: [
                SizedBox(
                  width: 160,
                  height: 160,
                  child: CustomPaint(
                    painter: _ScoreArcPainter(
                      score: health.overallScore / 100,
                      color: color,
                    ),
                  ),
                ),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      health.overallScore.toString(),
                      style: GoogleFonts.poppins(
                        fontSize: 48,
                        fontWeight: FontWeight.bold,
                        color: color,
                      ),
                    ),
                    Text(
                      'of 100',
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        color: Colors.grey[500],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              health.category,
              style: GoogleFonts.inter(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBreakdownCard(BreakdownScores breakdown) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          _ScoreRow(label: 'Savings Rate', score: breakdown.savingsRate),
          const Divider(height: 24),
          _ScoreRow(
              label: 'Needs/Wants Balance', score: breakdown.needsWantsBalance),
          const Divider(height: 24),
          _ScoreRow(
              label: 'Income Stability', score: breakdown.incomeStability),
          const Divider(height: 24),
          _ScoreRow(label: 'Goal Progress', score: breakdown.goalProgress),
        ],
      ),
    );
  }

  Color _getScoreColor(int score) {
    if (score >= 80) return Colors.green;
    if (score >= 60) return AppColors.secondary;
    if (score >= 40) return Colors.orange;
    return Colors.red;
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
    context.read<InsightsBloc>().add(LoadPredictions(days: 30));
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
          'AI Predictions',
          style: GoogleFonts.poppins(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: const Color(0xFF1E293B),
          ),
        ),
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
                  Text('Failed to load predictions',
                      style: GoogleFonts.inter(color: Colors.grey[600])),
                  const SizedBox(height: 8),
                  ElevatedButton(
                    onPressed: () => context
                        .read<InsightsBloc>()
                        .add(LoadPredictions(days: 30)),
                    child: const Text('Retry'),
                  ),
                ],
              ),
            );
          }

          if (state is PredictionsLoaded) {
            if (state.predictions.isEmpty) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.insights, size: 64, color: Colors.grey[300]),
                    const SizedBox(height: 16),
                    Text(
                      'Not enough data for predictions',
                      style: GoogleFonts.inter(
                          fontSize: 16, color: Colors.grey[600]),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Add more transactions to enable AI predictions',
                      style: GoogleFonts.inter(
                          fontSize: 14, color: Colors.grey[500]),
                    ),
                  ],
                ),
              );
            }

            return ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: state.predictions.length + 1,
              itemBuilder: (context, index) {
                if (index == 0) {
                  // Header
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: Container(
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
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.auto_awesome,
                                  color: Colors.white),
                              const SizedBox(width: 8),
                              Text(
                                'AI-Powered Forecasts',
                                style: GoogleFonts.poppins(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Based on your spending patterns and income history',
                            style: GoogleFonts.inter(
                              fontSize: 14,
                              color: Colors.white70,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }

                final prediction = state.predictions[index - 1];
                return _PredictionCard(prediction: prediction, format: format);
              },
            );
          }

          return const SizedBox();
        },
      ),
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
