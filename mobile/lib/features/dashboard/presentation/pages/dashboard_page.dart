/*
 * Dashboard Page
 * ==============
 * Main dashboard after authentication - Modern Rwandan-style design
 */

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../../../core/di/injection.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/router/app_router.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../auth/presentation/bloc/auth_bloc.dart';
import '../../../transactions/presentation/bloc/transaction_bloc.dart';
import '../../../transactions/presentation/pages/transactions_page.dart';
import '../../../goals/presentation/bloc/goals_bloc.dart';
import '../../../goals/presentation/pages/goals_page.dart';
import '../../../insights/presentation/bloc/insights_bloc.dart';
import '../../../profile/presentation/pages/profile_page.dart';

/// Dashboard page widget
class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  int _currentIndex = 0;

  @override
  Widget build(BuildContext context) {
    return BlocListener<AuthBloc, AuthState>(
      listener: (context, state) {
        if (state is AuthUnauthenticated) {
          context.go(Routes.login);
        }
      },
      child: Scaffold(
        backgroundColor: const Color(0xFFF8F9FD),
        body: _buildBody(),
        bottomNavigationBar: _buildBottomNav(),
      ),
    );
  }

  Widget _buildBody() {
    switch (_currentIndex) {
      case 0:
        return const _HomeContent();
      case 1:
        return BlocProvider(
          create: (_) => getIt<TransactionBloc>(),
          child: const TransactionsPage(),
        );
      case 2:
        return BlocProvider(
          create: (_) => getIt<GoalsBloc>(),
          child: const GoalsPage(),
        );
      case 3:
        return const _InsightsContent();
      case 4:
        return const ProfilePage();
      default:
        return const _HomeContent();
    }
  }

  Widget _buildBottomNav() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _NavItem(
                icon: Icons.home_outlined,
                activeIcon: Icons.home,
                label: 'Home',
                isActive: _currentIndex == 0,
                onTap: () => setState(() => _currentIndex = 0),
              ),
              _NavItem(
                icon: Icons.swap_horiz_outlined,
                activeIcon: Icons.swap_horiz,
                label: 'Transactions',
                isActive: _currentIndex == 1,
                onTap: () => setState(() => _currentIndex = 1),
              ),
              _NavItem(
                icon: Icons.flag_outlined,
                activeIcon: Icons.flag,
                label: 'Goals',
                isActive: _currentIndex == 2,
                onTap: () => setState(() => _currentIndex = 2),
              ),
              _NavItem(
                icon: Icons.insights_outlined,
                activeIcon: Icons.insights,
                label: 'Insights',
                isActive: _currentIndex == 3,
                onTap: () => setState(() => _currentIndex = 3),
              ),
              _NavItem(
                icon: Icons.person_outline,
                activeIcon: Icons.person,
                label: 'Profile',
                isActive: _currentIndex == 4,
                onTap: () => setState(() => _currentIndex = 4),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Home content - main dashboard view
class _HomeContent extends StatelessWidget {
  const _HomeContent();

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        children: [
          // Top Section with White Background
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: const BorderRadius.only(
                bottomLeft: Radius.circular(30),
                bottomRight: Radius.circular(30),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header Row
                    BlocBuilder<AuthBloc, AuthState>(
                      builder: (context, state) {
                        String name = 'User';
                        if (state is AuthAuthenticated) {
                          name = state.user.fullName.split(' ').first;
                        }
                        return Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Mwaramutse,',
                                  style: GoogleFonts.inter(
                                    fontSize: 14,
                                    color: Colors.grey[600],
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                Text(
                                  name,
                                  style: GoogleFonts.poppins(
                                    fontSize: 22,
                                    fontWeight: FontWeight.bold,
                                    color: const Color(0xFF1E293B),
                                  ),
                                ),
                              ],
                            ),
                            // Logo
                            Container(
                              width: 48,
                              height: 48,
                              decoration: BoxDecoration(
                                color: Colors.white,
                                shape: BoxShape.circle,
                                border: Border.all(
                                    color: Colors.grey[200]!, width: 2),
                              ),
                              child: ClipOval(
                                child: Image.asset(
                                  'assets/images/logo.png',
                                  fit: BoxFit.cover,
                                  errorBuilder: (context, error, stackTrace) {
                                    return Icon(
                                      Icons.account_balance_wallet,
                                      color: AppColors.primary,
                                      size: 24,
                                    );
                                  },
                                ),
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                    const SizedBox(height: 28),

                    // Main Balance Card
                    const _BalanceCard(),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
          ),

          const SizedBox(height: 16),

          // Quick Actions
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Quick Actions',
                  style: GoogleFonts.poppins(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF1E293B),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _ActionButton(
                      icon: Icons.add,
                      label: 'Add Income',
                      color: AppColors.primary,
                      onTap: () => context.push(Routes.addTransaction),
                    ),
                    _ActionButton(
                      icon: Icons.trending_up,
                      label: 'Forecast',
                      color: const Color(0xFF7C3AED),
                      onTap: () => context.push(Routes.predictions),
                    ),
                    _ActionButton(
                      icon: Icons.savings_outlined,
                      label: 'Save Now',
                      color: AppColors.secondary,
                      onTap: () => context.push(Routes.goals),
                    ),
                    _ActionButton(
                      icon: Icons.history,
                      label: 'History',
                      color: Colors.orange,
                      onTap: () => context.push(Routes.transactions),
                    ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 32),

          // Safe to Spend Section
          const _SafeToSpendSection(),

          const SizedBox(height: 32),

          // AI Insights Section
          const _AIInsightsSection(),

          const SizedBox(height: 32),

          // Recent Transactions
          const _RecentTransactionsSection(),
        ],
      ),
    );
  }
}

/// Balance Card Widget — loads live safe-to-spend data
class _BalanceCard extends StatefulWidget {
  const _BalanceCard();

  @override
  State<_BalanceCard> createState() => _BalanceCardState();
}

class _BalanceCardState extends State<_BalanceCard> {
  final ApiClient _api = getIt<ApiClient>();
  Map<String, dynamic>? _data;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final data = await _api.getSafeToSpend();
      if (mounted) setState(() => _data = data);
    } catch (_) {}
  }

  String _fmt(double v) {
    if (v >= 1000000) return '${(v / 1000000).toStringAsFixed(1)}M';
    if (v >= 1000) return '${(v / 1000).toStringAsFixed(0)}k';
    return v.toStringAsFixed(0);
  }

  @override
  Widget build(BuildContext context) {
    final balance = (_data?['total_balance'] as num?)?.toDouble() ?? 0.0;
    final safeToSpend = (_data?['safe_to_spend'] as num?)?.toDouble() ?? 0.0;
    final safePerDay = (_data?['safe_per_day'] as num?)?.toDouble() ?? 0.0;

    return Container(
      width: double.infinity,
      height: 200,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF00A3AD),
            Color(0xFF007A82),
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF00A3AD).withOpacity(0.4),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Stack(
        children: [
          // Decorative Circles
          Positioned(
            top: -20,
            right: -20,
            child: Container(
              width: 150,
              height: 150,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
            ),
          ),
          Positioned(
            bottom: -40,
            left: -10,
            child: Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
            ),
          ),

          // Content
          Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.account_balance_wallet_outlined,
                          color: Colors.white.withOpacity(0.8),
                          size: 18,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Total Liquidity',
                          style: GoogleFonts.inter(
                            color: Colors.white.withOpacity(0.9),
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    _data == null
                        ? Container(
                            width: 160,
                            height: 36,
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(8),
                            ),
                          )
                        : RichText(
                            text: TextSpan(
                              children: [
                                TextSpan(
                                  text: 'RWF ',
                                  style: GoogleFonts.inter(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w500,
                                    color: Colors.white.withOpacity(0.8),
                                  ),
                                ),
                                TextSpan(
                                  text: _fmt(balance),
                                  style: GoogleFonts.poppins(
                                    fontSize: 32,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.white,
                                    height: 1.0,
                                  ),
                                ),
                              ],
                            ),
                          ),
                  ],
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _BalanceIndicator(
                      label: 'Safe to Spend',
                      amount: _data == null ? '—' : _fmt(safeToSpend),
                      color: const Color(0xFFB3E5FC),
                    ),
                    Container(
                      width: 1,
                      height: 30,
                      color: Colors.white.withOpacity(0.3),
                    ),
                    _BalanceIndicator(
                      label: 'Daily Budget',
                      amount: _data == null ? '—' : _fmt(safePerDay),
                      color: const Color(0xFFFFD54F),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Balance Indicator Widget
class _BalanceIndicator extends StatelessWidget {
  final String label;
  final String amount;
  final Color color;

  const _BalanceIndicator({
    required this.label,
    required this.amount,
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
            color: Colors.white.withOpacity(0.7),
            fontSize: 12,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          amount,
          style: GoogleFonts.poppins(
            color: color,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

/// Action Button Widget
class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _ActionButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            height: 60,
            width: 60,
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Icon(
              icon,
              color: color,
              size: 28,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: Colors.grey[700],
            ),
          ),
        ],
      ),
    );
  }
}

/// AI Insights Section
/// Safe to Spend Section
class _SafeToSpendSection extends StatelessWidget {
  const _SafeToSpendSection();

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => getIt<InsightsBloc>()..add(LoadSafeToSpend()),
      child: BlocBuilder<InsightsBloc, InsightsState>(
        builder: (context, state) {
          if (state is InsightsLoading) {
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.grey.shade100),
                ),
                child: const Center(child: CircularProgressIndicator()),
              ),
            );
          }

          if (state is SafeToSpendLoaded) {
            final data = state.safeToSpend;
            final safeAmount =
                (data['safe_to_spend'] as num?)?.toDouble() ?? 0.0;
            final totalBalance =
                (data['total_balance'] as num?)?.toDouble() ?? 0.0;
            final reservedExpenses =
                (data['reserved_for_expenses'] as num?)?.toDouble() ?? 0.0;
            final reservedGoals =
                (data['reserved_for_goals'] as num?)?.toDouble() ?? 0.0;
            final emergencyBuffer =
                (data['emergency_buffer'] as num?)?.toDouble() ?? 0.0;
            final explanation = data['explanation'] as String? ?? '';

            final isPositive = safeAmount > 0;
            final isLow = safeAmount < 10000 && safeAmount > 0;

            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Safe to Spend',
                        style: GoogleFonts.poppins(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF1E293B),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: isPositive
                              ? const Color(0xFFE8F5E9)
                              : const Color(0xFFFFEBEE),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              isPositive ? Icons.check_circle : Icons.warning,
                              size: 14,
                              color: isPositive
                                  ? const Color(0xFF2E7D32)
                                  : const Color(0xFFC62828),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              isPositive ? 'Available' : 'Over Budget',
                              style: GoogleFonts.inter(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: isPositive
                                    ? const Color(0xFF2E7D32)
                                    : const Color(0xFFC62828),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: isPositive
                            ? [const Color(0xFF2E7D32), const Color(0xFF43A047)]
                            : isLow
                                ? [
                                    const Color(0xFFF57C00),
                                    const Color(0xFFFB8C00)
                                  ]
                                : [
                                    const Color(0xFFC62828),
                                    const Color(0xFFD32F2F)
                                  ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: (isPositive
                                  ? Colors.green
                                  : isLow
                                      ? Colors.orange
                                      : Colors.red)
                              .withOpacity(0.3),
                          blurRadius: 15,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Amount
                        Text(
                          'RWF ${safeAmount.toStringAsFixed(0).replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+(?!\d))'), (m) => '${m[1]},')}',
                          style: GoogleFonts.poppins(
                            fontSize: 36,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          explanation.isNotEmpty
                              ? explanation
                              : 'After covering all expenses, goals, and emergencies',
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            color: Colors.white.withOpacity(0.9),
                            height: 1.4,
                          ),
                        ),
                        const SizedBox(height: 24),

                        // Breakdown
                        _buildBreakdownRow(
                          'Total Balance',
                          totalBalance,
                          Icons.account_balance_wallet,
                          Colors.white,
                        ),
                        const SizedBox(height: 12),
                        _buildBreakdownRow(
                          'Reserved for Expenses',
                          reservedExpenses,
                          Icons.receipt_long,
                          Colors.white.withOpacity(0.8),
                        ),
                        const SizedBox(height: 12),
                        _buildBreakdownRow(
                          'Reserved for Goals',
                          reservedGoals,
                          Icons.flag,
                          Colors.white.withOpacity(0.8),
                        ),
                        const SizedBox(height: 12),
                        _buildBreakdownRow(
                          'Emergency Buffer',
                          emergencyBuffer,
                          Icons.security,
                          Colors.white.withOpacity(0.8),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          }

          // Error or initial state - show placeholder
          return const SizedBox.shrink();
        },
      ),
    );
  }

  Widget _buildBreakdownRow(
      String label, double amount, IconData icon, Color color) {
    return Row(
      children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 13,
              color: color,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        Text(
          'RWF ${amount.toStringAsFixed(0).replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+(?!\d))'), (m) => '${m[1]},')}',
          style: GoogleFonts.inter(
            fontSize: 13,
            color: color,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

/// AI Insights Section — fetches live Claude-generated nudges from the backend.
class _AIInsightsSection extends StatefulWidget {
  const _AIInsightsSection();

  @override
  State<_AIInsightsSection> createState() => _AIInsightsSectionState();
}

class _AIInsightsSectionState extends State<_AIInsightsSection> {
  final ApiClient _api = getIt<ApiClient>();

  List<Map<String, dynamic>> _nudges = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadNudges();
  }

  Future<void> _loadNudges() async {
    try {
      final data = await _api.getRecommendations();
      if (mounted) {
        setState(() {
          _nudges = data.cast<Map<String, dynamic>>();
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _refresh() async {
    setState(() => _loading = true);
    try {
      await _api.generateNudges('manual');
      await _loadNudges();
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _dismiss(int id) async {
    await _api.updateRecommendation(id, 'dismissed');
    setState(() => _nudges.removeWhere((n) => n['id'] == id));
  }

  Future<void> _act(int id, String actionType) async {
    await _api.updateRecommendation(id, 'acted');
    // Navigate based on action type
    if (!mounted) return;
    if (actionType == 'invest') {
      context.push(Routes.investments);
    } else {
      context.push(Routes.goals);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Smart Nudges',
                style: GoogleFonts.poppins(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF1E293B),
                ),
              ),
              Row(
                children: [
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE0F2F1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      'AI',
                      style: GoogleFonts.inter(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF00695C),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: _refresh,
                    child:
                        Icon(Icons.refresh, size: 20, color: Colors.grey[500]),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (_loading)
            _NudgeCardShimmer()
          else if (_nudges.isEmpty)
            _EmptyNudgeCard(onRefresh: _refresh)
          else
            Column(
              children: _nudges
                  .take(3)
                  .map((n) => Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: _NudgeCard(
                          nudge: n,
                          onAct: () =>
                              _act(n['id'] as int, n['action_type'] ?? 'save'),
                          onDismiss: () => _dismiss(n['id'] as int),
                        ),
                      ))
                  .toList(),
            ),
        ],
      ),
    );
  }
}

class _NudgeCard extends StatelessWidget {
  final Map<String, dynamic> nudge;
  final VoidCallback onAct;
  final VoidCallback onDismiss;

  const _NudgeCard({
    required this.nudge,
    required this.onAct,
    required this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    final type = nudge['recommendation_type'] as String? ?? 'savings';
    final urgency = nudge['urgency'] as String? ?? 'normal';
    final title = nudge['title'] as String? ?? '';
    final message = nudge['message'] as String? ?? '';
    final actionType = nudge['action_type'] as String? ?? 'save';

    final colors = _colorsForType(type, urgency);
    final icon = _iconForType(type);
    final actionLabel = _actionLabel(actionType);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colors['border']!, width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: colors['iconBg'],
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, size: 18, color: colors['iconColor']),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF1E293B),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      message,
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: Colors.grey[600],
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
              GestureDetector(
                onTap: onDismiss,
                child: Icon(Icons.close, size: 16, color: Colors.grey[400]),
              ),
            ],
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: onAct,
              style: ElevatedButton.styleFrom(
                backgroundColor: colors['buttonBg'],
                foregroundColor: Colors.white,
                elevation: 0,
                padding: const EdgeInsets.symmetric(vertical: 10),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: Text(
                actionLabel,
                style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Map<String, dynamic> _colorsForType(String type, String urgency) {
    if (urgency == 'high') {
      return {
        'iconBg': const Color(0xFFFEE2E2),
        'iconColor': const Color(0xFFDC2626),
        'border': const Color(0xFFFECACA),
        'buttonBg': const Color(0xFFDC2626),
      };
    }
    if (type == 'investment') {
      return {
        'iconBg': const Color(0xFFEDE9FE),
        'iconColor': const Color(0xFF7C3AED),
        'border': const Color(0xFFDDD6FE),
        'buttonBg': const Color(0xFF7C3AED),
      };
    }
    if (type == 'spending') {
      return {
        'iconBg': const Color(0xFFFFF7ED),
        'iconColor': const Color(0xFFEA580C),
        'border': const Color(0xFFFED7AA),
        'buttonBg': const Color(0xFFEA580C),
      };
    }
    // savings (default)
    return {
      'iconBg': const Color(0xFFE0F2F1),
      'iconColor': AppColors.primary,
      'border': const Color(0xFFB2DFDB),
      'buttonBg': AppColors.primary,
    };
  }

  IconData _iconForType(String type) {
    switch (type) {
      case 'investment':
        return Icons.trending_up;
      case 'spending':
        return Icons.warning_amber_outlined;
      default:
        return Icons.savings_outlined;
    }
  }

  String _actionLabel(String actionType) {
    switch (actionType) {
      case 'invest':
        return 'Invest Now';
      case 'reduce_spending':
        return 'View Spending';
      case 'view_goals':
        return 'View Goals';
      default:
        return 'Save Now';
    }
  }
}

class _NudgeCardShimmer extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: 120,
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(16),
      ),
      child: const Center(
        child: SizedBox(
          width: 24,
          height: 24,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      ),
    );
  }
}

class _EmptyNudgeCard extends StatelessWidget {
  final VoidCallback onRefresh;
  const _EmptyNudgeCard({required this.onRefresh});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade100),
      ),
      child: Column(
        children: [
          Icon(Icons.lightbulb_outline, color: Colors.grey[400], size: 32),
          const SizedBox(height: 8),
          Text(
            'No nudges yet',
            style: GoogleFonts.inter(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: Colors.grey[500],
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Keep transacting and we\'ll personalise your advice.',
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(fontSize: 12, color: Colors.grey[400]),
          ),
          const SizedBox(height: 12),
          TextButton(
            onPressed: onRefresh,
            child: Text(
              'Generate nudge',
              style: GoogleFonts.inter(
                fontSize: 13,
                color: AppColors.primary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Recent Transactions Section
class _RecentTransactionsSection extends StatefulWidget {
  const _RecentTransactionsSection();

  @override
  State<_RecentTransactionsSection> createState() =>
      _RecentTransactionsSectionState();
}

class _RecentTransactionsSectionState
    extends State<_RecentTransactionsSection> {
  final ApiClient _api = getIt<ApiClient>();
  List<Map<String, dynamic>> _transactions = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final data = await _api.getTransactions(pageSize: 5);
      final items = (data['items'] as List? ?? []).cast<Map<String, dynamic>>();
      if (mounted)
        setState(() {
          _transactions = items;
          _loading = false;
        });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _fmtDate(String? raw) {
    if (raw == null) return '';
    try {
      final dt = DateTime.parse(raw).toLocal();
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final txDay = DateTime(dt.year, dt.month, dt.day);
      final diff = today.difference(txDay).inDays;
      final time = DateFormat('h:mm a').format(dt);
      if (diff == 0) return 'Today, $time';
      if (diff == 1) return 'Yesterday, $time';
      return DateFormat('MMM d, h:mm a').format(dt);
    } catch (_) {
      return raw;
    }
  }

  _TileConfig _configFor(Map<String, dynamic> tx) {
    final type = (tx['transaction_type'] as String? ?? '').toLowerCase();
    final category = (tx['category'] as String? ?? '').toLowerCase();
    final amount = (tx['amount'] as num?)?.toDouble() ?? 0.0;
    final formatted = NumberFormat('#,###').format(amount.round());

    if (type == 'income') {
      return _TileConfig(
        title: tx['counterparty_name'] as String? ?? 'Income',
        subtitle: tx['description'] as String? ?? '',
        amount: '+ RWF $formatted',
        isPositive: true,
        icon: Icons.arrow_downward_rounded,
        color: Colors.green.shade100,
        iconColor: Colors.green.shade700,
      );
    }
    if (type == 'savings') {
      return _TileConfig(
        title: tx['counterparty_name'] as String? ?? 'Savings',
        subtitle: tx['description'] as String? ?? '',
        amount: '- RWF $formatted',
        isPositive: false,
        icon: Icons.shield_outlined,
        color: Colors.orange.shade100,
        iconColor: Colors.orange.shade700,
      );
    }
    // expense — icon by category
    IconData icon = Icons.remove_circle_outline;
    Color bg = Colors.grey.shade100;
    Color fg = Colors.grey.shade700;
    if (category.contains('food') || category.contains('grocer')) {
      icon = Icons.restaurant;
      bg = Colors.red.shade100;
      fg = Colors.red.shade700;
    } else if (category.contains('transport')) {
      icon = Icons.directions_bus;
      bg = Colors.blue.shade100;
      fg = Colors.blue.shade700;
    } else if (category.contains('airtime') || category.contains('data')) {
      icon = Icons.wifi;
      bg = Colors.blue.shade100;
      fg = Colors.blue.shade700;
    } else if (category.contains('util')) {
      icon = Icons.bolt;
      bg = Colors.yellow.shade100;
      fg = Colors.yellow.shade800;
    } else if (category.contains('entertainment')) {
      icon = Icons.movie_outlined;
      bg = Colors.purple.shade100;
      fg = Colors.purple.shade700;
    } else if (category.contains('health')) {
      icon = Icons.local_hospital_outlined;
      bg = Colors.teal.shade100;
      fg = Colors.teal.shade700;
    } else if (category.contains('momo') || category.contains('transfer')) {
      icon = Icons.smartphone;
      bg = Colors.green.shade100;
      fg = Colors.green.shade700;
    }
    return _TileConfig(
      title: tx['counterparty_name'] as String? ?? 'Expense',
      subtitle: tx['description'] as String? ?? '',
      amount: '- RWF $formatted',
      isPositive: false,
      icon: icon,
      color: bg,
      iconColor: fg,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Recent Activity',
                style: GoogleFonts.poppins(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF1E293B),
                ),
              ),
              TextButton(
                onPressed: () => context.push(Routes.transactions),
                child: Text(
                  'See All',
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: AppColors.primary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (_loading)
            const Center(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            )
          else if (_transactions.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Text(
                'No recent transactions',
                style: GoogleFonts.inter(
                  color: Colors.grey[500],
                  fontSize: 14,
                ),
              ),
            )
          else
            ...List.generate(_transactions.length, (i) {
              final tx = _transactions[i];
              final cfg = _configFor(tx);
              return _TransactionTile(
                title: cfg.title,
                subtitle: cfg.subtitle,
                amount: cfg.amount,
                isPositive: cfg.isPositive,
                date: _fmtDate(tx['transaction_date'] as String?),
                icon: cfg.icon,
                color: cfg.color,
                iconColor: cfg.iconColor,
              );
            }),
          const SizedBox(height: 80),
        ],
      ),
    );
  }
}

/// Helper data class for transaction tile configuration
class _TileConfig {
  final String title;
  final String subtitle;
  final String amount;
  final bool isPositive;
  final IconData icon;
  final Color color;
  final Color iconColor;
  const _TileConfig({
    required this.title,
    required this.subtitle,
    required this.amount,
    required this.isPositive,
    required this.icon,
    required this.color,
    required this.iconColor,
  });
}

/// Transaction Tile Widget
class _TransactionTile extends StatelessWidget {
  final String title;
  final String subtitle;
  final String amount;
  final bool isPositive;
  final String date;
  final IconData icon;
  final Color color;
  final Color iconColor;

  const _TransactionTile({
    required this.title,
    required this.subtitle,
    required this.amount,
    required this.isPositive,
    required this.date,
    required this.icon,
    required this.color,
    required this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: iconColor, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.inter(
                    fontWeight: FontWeight.w600,
                    fontSize: 15,
                    color: const Color(0xFF1E293B),
                  ),
                ),
                Text(
                  date,
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: Colors.grey[500],
                  ),
                ),
              ],
            ),
          ),
          Text(
            amount,
            style: GoogleFonts.inter(
              fontWeight: FontWeight.bold,
              fontSize: 15,
              color: isPositive ? Colors.green[700] : Colors.black87,
            ),
          ),
        ],
      ),
    );
  }
}

/// Bottom Nav Item
class _NavItem extends StatelessWidget {
  final IconData icon;
  final IconData activeIcon;
  final String label;
  final bool isActive;
  final VoidCallback onTap;

  const _NavItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.isActive,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isActive ? activeIcon : icon,
            color: isActive ? AppColors.primary : Colors.grey[400],
            size: 24,
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 11,
              fontWeight: isActive ? FontWeight.w600 : FontWeight.w500,
              color: isActive ? AppColors.primary : Colors.grey[500],
            ),
          ),
        ],
      ),
    );
  }
}

// ==================== Profile Content ====================

class _InsightsContent extends StatelessWidget {
  const _InsightsContent();

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'AI Insights',
              style: GoogleFonts.poppins(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: const Color(0xFF1E293B),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Personalized financial recommendations',
              style: GoogleFonts.inter(
                fontSize: 14,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 24),
            // Finance Advisor Card
            GestureDetector(
              onTap: () => context.push(Routes.advisor),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      AppColors.primary,
                      AppColors.primary.withOpacity(0.85),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primary.withOpacity(0.3),
                      blurRadius: 16,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Container(
                      width: 52,
                      height: 52,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Icon(Icons.auto_awesome,
                          color: Colors.white, size: 26),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Finance Advisor',
                            style: GoogleFonts.poppins(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Ask anything about your money',
                            style: GoogleFonts.inter(
                              fontSize: 13,
                              color: Colors.white.withOpacity(0.85),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        'AI',
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Icon(Icons.arrow_forward_ios,
                        color: Colors.white, size: 16),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
            // Health Score Card
            GestureDetector(
              onTap: () => context.push(Routes.financialHealth),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
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
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Financial Health Score',
                          style: GoogleFonts.poppins(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFF1E293B),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.green.shade100,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            'B+',
                            style: GoogleFonts.poppins(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.green.shade700,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: LinearProgressIndicator(
                        value: 0.72,
                        minHeight: 12,
                        backgroundColor: Colors.grey.shade200,
                        valueColor:
                            AlwaysStoppedAnimation(Colors.green.shade500),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            'Your finances are looking healthy! Keep building your emergency buffer.',
                            style: GoogleFonts.inter(
                              fontSize: 13,
                              color: Colors.grey[600],
                              height: 1.5,
                            ),
                          ),
                        ),
                        Icon(Icons.chevron_right, color: Colors.grey[400]),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
            // Predictions Card
            GestureDetector(
              onTap: () => context.push(Routes.predictions),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.primary.withOpacity(0.3)),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.primary,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child:
                          const Icon(Icons.auto_awesome, color: Colors.white),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'AI Predictions',
                            style: GoogleFonts.inter(
                              fontWeight: FontWeight.w600,
                              fontSize: 16,
                              color: const Color(0xFF1E293B),
                            ),
                          ),
                          Text(
                            'Forecast income & expenses',
                            style: GoogleFonts.inter(
                              fontSize: 13,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    ),
                    Icon(Icons.arrow_forward_ios,
                        color: AppColors.primary, size: 18),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            // Investment Simulation
            GestureDetector(
              onTap: () => context.push(Routes.investmentSimulator),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: const Color(0xFF7C3AED).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                      color: const Color(0xFF7C3AED).withOpacity(0.3)),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFF7C3AED),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.calculate_outlined,
                          color: Colors.white),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Investment Simulator',
                            style: GoogleFonts.inter(
                              fontWeight: FontWeight.w600,
                              fontSize: 16,
                              color: const Color(0xFF1E293B),
                            ),
                          ),
                          Text(
                            'See how Ejo Heza grows your money',
                            style: GoogleFonts.inter(
                              fontSize: 13,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Icon(Icons.arrow_forward_ios,
                        color: Color(0xFF7C3AED), size: 18),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            // My Investments Card
            GestureDetector(
              onTap: () => context.push(Routes.investments),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.teal.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.teal.withOpacity(0.3)),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.teal,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.trending_up, color: Colors.white),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'My Investments',
                            style: GoogleFonts.inter(
                              fontWeight: FontWeight.w600,
                              fontSize: 16,
                              color: const Color(0xFF1E293B),
                            ),
                          ),
                          Text(
                            'Track & manage your portfolio',
                            style: GoogleFonts.inter(
                              fontSize: 13,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Icon(Icons.arrow_forward_ios,
                        color: Colors.teal, size: 18),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
