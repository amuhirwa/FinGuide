/*
 * Investments Page
 * ================
 * Track and manage investments with advice
 */

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../../../core/di/injection.dart';
import '../../../../core/theme/app_theme.dart';
import '../../data/models/investment_model.dart';
import '../bloc/investment_bloc.dart';

class InvestmentsPage extends StatefulWidget {
  const InvestmentsPage({super.key});

  @override
  State<InvestmentsPage> createState() => _InvestmentsPageState();
}

class _InvestmentsPageState extends State<InvestmentsPage> {
  @override
  void initState() {
    super.initState();
    context.read<InvestmentBloc>().add(LoadInvestments());
    context.read<InvestmentBloc>().add(LoadInvestmentSummary());
    context.read<InvestmentBloc>().add(LoadInvestmentAdvice());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FD),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: Text(
          'Investments',
          style: GoogleFonts.poppins(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: const Color(0xFF1E293B),
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              context.read<InvestmentBloc>().add(LoadInvestments());
              context.read<InvestmentBloc>().add(LoadInvestmentSummary());
            },
          ),
        ],
      ),
      body: BlocBuilder<InvestmentBloc, InvestmentState>(
        builder: (context, state) {
          if (state is InvestmentLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          if (state is InvestmentError) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.error_outline, size: 64, color: Colors.red[300]),
                  const SizedBox(height: 16),
                  Text(state.message),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () =>
                        context.read<InvestmentBloc>().add(LoadInvestments()),
                    child: const Text('Retry'),
                  ),
                ],
              ),
            );
          }

          if (state is InvestmentsLoaded) {
            return RefreshIndicator(
              onRefresh: () async {
                context.read<InvestmentBloc>().add(LoadInvestments());
                context.read<InvestmentBloc>().add(LoadInvestmentSummary());
              },
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Summary Card
                    if (state.summary != null)
                      _buildSummaryCard(state.summary!),
                    const SizedBox(height: 24),

                    // Advice Section
                    if (state.advice != null && state.advice!.isNotEmpty) ...[
                      _buildAdviceSection(state.advice!),
                      const SizedBox(height: 24),
                    ],

                    // Investments List
                    Text(
                      'Your Investments',
                      style: GoogleFonts.poppins(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF1E293B),
                      ),
                    ),
                    const SizedBox(height: 16),

                    if (state.investments.isEmpty)
                      _buildEmptyState()
                    else
                      ...state.investments
                          .map((inv) => _buildInvestmentCard(inv)),
                  ],
                ),
              ),
            );
          }

          return _buildEmptyState();
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => BlocProvider(
              create: (_) => getIt<InvestmentBloc>(),
              child: const AddInvestmentPage(),
            ),
          ),
        ).then((_) {
          context.read<InvestmentBloc>().add(LoadInvestments());
          context.read<InvestmentBloc>().add(LoadInvestmentSummary());
        }),
        backgroundColor: AppColors.secondary,
        icon: const Icon(Icons.add, color: Colors.white),
        label: Text(
          'Add Investment',
          style: GoogleFonts.inter(
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
      ),
    );
  }

  Widget _buildSummaryCard(InvestmentSummary summary) {
    final format = NumberFormat('#,###', 'en_US');
    final isPositive = summary.totalGain >= 0;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Portfolio Value',
            style: GoogleFonts.inter(
              fontSize: 14,
              color: Colors.white70,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'RWF ${format.format(summary.totalValue)}',
            style: GoogleFonts.poppins(
              fontSize: 32,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: isPositive
                      ? Colors.green.withOpacity(0.2)
                      : Colors.red.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  children: [
                    Icon(
                      isPositive ? Icons.trending_up : Icons.trending_down,
                      color: isPositive ? Colors.greenAccent : Colors.redAccent,
                      size: 16,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '${isPositive ? '+' : ''}${summary.totalGainPercentage.toStringAsFixed(1)}%',
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color:
                            isPositive ? Colors.greenAccent : Colors.redAccent,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Text(
                '${isPositive ? '+' : ''}RWF ${format.format(summary.totalGain.abs())}',
                style: GoogleFonts.inter(
                  fontSize: 14,
                  color: Colors.white70,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildSummaryItem(
                'Invested',
                'RWF ${format.format(summary.totalInvested)}',
              ),
              _buildSummaryItem(
                'Monthly',
                'RWF ${format.format(summary.monthlyContribution)}',
              ),
              _buildSummaryItem(
                'Active',
                '${summary.activeCount}',
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryItem(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 12,
            color: Colors.white60,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: GoogleFonts.inter(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
      ],
    );
  }

  Widget _buildAdviceSection(List<InvestmentAdvice> advice) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Investment Advice',
              style: GoogleFonts.poppins(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF1E293B),
              ),
            ),
            Icon(Icons.lightbulb_outline, color: Colors.amber[600]),
          ],
        ),
        const SizedBox(height: 12),
        ...advice.take(3).map((a) => _buildAdviceCard(a)),
      ],
    );
  }

  Widget _buildAdviceCard(InvestmentAdvice advice) {
    Color priorityColor;
    switch (advice.priority) {
      case 'high':
        priorityColor = Colors.red;
        break;
      case 'medium':
        priorityColor = Colors.orange;
        break;
      default:
        priorityColor = Colors.blue;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border(
          left: BorderSide(color: priorityColor, width: 4),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                _getAdviceIcon(advice.type),
                color: priorityColor,
                size: 20,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  advice.title,
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF1E293B),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            advice.description,
            style: GoogleFonts.inter(
              fontSize: 13,
              color: Colors.grey[600],
            ),
          ),
          if (advice.actionLabel != null) ...[
            const SizedBox(height: 12),
            TextButton(
              onPressed: () {
                // Handle action
              },
              style: TextButton.styleFrom(
                padding: EdgeInsets.zero,
                minimumSize: const Size(0, 0),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: Text(
                advice.actionLabel!,
                style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: priorityColor,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  IconData _getAdviceIcon(String type) {
    switch (type) {
      case 'diversify':
        return Icons.pie_chart;
      case 'increase':
        return Icons.trending_up;
      case 'rebalance':
        return Icons.balance;
      case 'opportunity':
        return Icons.lightbulb;
      default:
        return Icons.info;
    }
  }

  Widget _buildInvestmentCard(InvestmentModel investment) {
    final format = NumberFormat('#,###', 'en_US');
    final isPositive = (investment.gainPercentage ?? 0) >= 0;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
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
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color:
                      _getTypeColor(investment.investmentType).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  _getTypeIcon(investment.investmentType),
                  color: _getTypeColor(investment.investmentType),
                  size: 24,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      investment.name,
                      style: GoogleFonts.inter(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF1E293B),
                      ),
                    ),
                    Text(
                      _getTypeLabel(investment.investmentType),
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    'RWF ${format.format(investment.currentValue)}',
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF1E293B),
                    ),
                  ),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: isPositive
                          ? Colors.green.withOpacity(0.1)
                          : Colors.red.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '${isPositive ? '+' : ''}${(investment.gainPercentage ?? 0).toStringAsFixed(1)}%',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: isPositive ? Colors.green : Colors.red,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Progress bar for maturity if applicable
          if (investment.maturityDate != null) ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Maturity: ${DateFormat('MMM d, yyyy').format(investment.maturityDate!)}',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),
                Text(
                  '${_getDaysToMaturity(investment.maturityDate!)} days left',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: AppColors.primary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: _getMaturityProgress(
                    investment.startDate, investment.maturityDate!),
                backgroundColor: Colors.grey[200],
                valueColor:
                    const AlwaysStoppedAnimation<Color>(AppColors.primary),
                minHeight: 6,
              ),
            ),
          ],
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildInfoChip(
                'Initial',
                'RWF ${format.format(investment.initialAmount)}',
              ),
              _buildInfoChip(
                'Return',
                '${investment.expectedAnnualReturn.toStringAsFixed(1)}% p.a.',
              ),
              if (investment.autoContribute)
                _buildInfoChip(
                  'Auto',
                  'RWF ${format.format(investment.monthlyContribution)}/mo',
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildInfoChip(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 11,
            color: Colors.grey[500],
          ),
        ),
        Text(
          value,
          style: GoogleFonts.inter(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: const Color(0xFF1E293B),
          ),
        ),
      ],
    );
  }

  int _getDaysToMaturity(DateTime maturityDate) {
    return maturityDate.difference(DateTime.now()).inDays;
  }

  double _getMaturityProgress(DateTime startDate, DateTime maturityDate) {
    final total = maturityDate.difference(startDate).inDays;
    final elapsed = DateTime.now().difference(startDate).inDays;
    return (elapsed / total).clamp(0.0, 1.0);
  }

  Color _getTypeColor(InvestmentType type) {
    switch (type) {
      case InvestmentType.ejo_heza:
        return Colors.blue;
      case InvestmentType.rnit:
        return Colors.purple;
      case InvestmentType.savings_account:
        return Colors.green;
      case InvestmentType.fixed_deposit:
        return Colors.orange;
      case InvestmentType.sacco:
        return Colors.teal;
      case InvestmentType.stocks:
        return Colors.red;
      case InvestmentType.bonds:
        return Colors.indigo;
      case InvestmentType.mutual_fund:
        return Colors.pink;
      case InvestmentType.real_estate:
        return Colors.brown;
      case InvestmentType.business:
        return Colors.amber;
      case InvestmentType.other:
        return Colors.grey;
    }
  }

  IconData _getTypeIcon(InvestmentType type) {
    switch (type) {
      case InvestmentType.ejo_heza:
        return Icons.account_balance;
      case InvestmentType.rnit:
        return Icons.security;
      case InvestmentType.savings_account:
        return Icons.savings;
      case InvestmentType.fixed_deposit:
        return Icons.lock_clock;
      case InvestmentType.sacco:
        return Icons.groups;
      case InvestmentType.stocks:
        return Icons.candlestick_chart;
      case InvestmentType.bonds:
        return Icons.description;
      case InvestmentType.mutual_fund:
        return Icons.pie_chart;
      case InvestmentType.real_estate:
        return Icons.home_work;
      case InvestmentType.business:
        return Icons.store;
      case InvestmentType.other:
        return Icons.attach_money;
    }
  }

  String _getTypeLabel(InvestmentType type) {
    switch (type) {
      case InvestmentType.ejo_heza:
        return 'Ejo Heza Pension';
      case InvestmentType.rnit:
        return 'RNIT Bonds';
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

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.trending_up,
              size: 64,
              color: AppColors.primary.withOpacity(0.5),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'No Investments Yet',
            style: GoogleFonts.poppins(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: const Color(0xFF1E293B),
            ),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 48),
            child: Text(
              'Start building your wealth by adding your first investment',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                fontSize: 14,
                color: Colors.grey[600],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ==================== Add Investment Page ====================

class AddInvestmentPage extends StatefulWidget {
  final InvestmentModel? investment;

  const AddInvestmentPage({super.key, this.investment});

  @override
  State<AddInvestmentPage> createState() => _AddInvestmentPageState();
}

class _AddInvestmentPageState extends State<AddInvestmentPage> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _initialAmountController = TextEditingController();
  final _expectedReturnController = TextEditingController();
  final _monthlyContributionController = TextEditingController();
  final _institutionController = TextEditingController();

  InvestmentType _type = InvestmentType.savings_account;
  DateTime _startDate = DateTime.now();
  DateTime? _maturityDate;
  bool _autoContribute = false;
  int _contributionDay = 1;

  bool get isEditing => widget.investment != null;

  @override
  void initState() {
    super.initState();
    if (widget.investment != null) {
      final inv = widget.investment!;
      _nameController.text = inv.name;
      _descriptionController.text = inv.description ?? '';
      _initialAmountController.text = inv.initialAmount.toString();
      _expectedReturnController.text = inv.expectedAnnualReturn.toString();
      _monthlyContributionController.text = inv.monthlyContribution.toString();
      _institutionController.text = inv.institutionName ?? '';
      _type = inv.investmentType;
      _startDate = inv.startDate;
      _maturityDate = inv.maturityDate;
      _autoContribute = inv.autoContribute;
      _contributionDay = inv.contributionDay;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _initialAmountController.dispose();
    _expectedReturnController.dispose();
    _monthlyContributionController.dispose();
    _institutionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FD),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: Text(
          isEditing ? 'Edit Investment' : 'Add Investment',
          style: GoogleFonts.poppins(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: const Color(0xFF1E293B),
          ),
        ),
      ),
      body: BlocListener<InvestmentBloc, InvestmentState>(
        listener: (context, state) {
          if (state is InvestmentCreated) {
            Navigator.pop(context, true);
          } else if (state is InvestmentError) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(state.message)),
            );
          }
        },
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Investment Type
                _buildLabel('Investment Type'),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<InvestmentType>(
                      isExpanded: true,
                      value: _type,
                      items: InvestmentType.values
                          .map((t) => DropdownMenuItem(
                                value: t,
                                child: Text(_getTypeLabel(t)),
                              ))
                          .toList(),
                      onChanged: (v) {
                        if (v != null) setState(() => _type = v);
                      },
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                // Name
                _buildLabel('Investment Name'),
                TextFormField(
                  controller: _nameController,
                  decoration: _inputDecoration('e.g., My Ejo Heza Account'),
                  validator: (v) => v?.isEmpty == true ? 'Required' : null,
                ),
                const SizedBox(height: 20),

                // Description
                _buildLabel('Description (Optional)'),
                TextFormField(
                  controller: _descriptionController,
                  decoration: _inputDecoration('Notes about this investment'),
                  maxLines: 2,
                ),
                const SizedBox(height: 20),

                // Initial Amount
                _buildLabel('Initial Amount (RWF)'),
                TextFormField(
                  controller: _initialAmountController,
                  keyboardType: TextInputType.number,
                  decoration: _inputDecoration('0'),
                  validator: (v) {
                    if (v?.isEmpty == true) return 'Required';
                    if (double.tryParse(v!) == null) return 'Invalid number';
                    return null;
                  },
                ),
                const SizedBox(height: 20),

                // Expected Annual Return
                _buildLabel('Expected Annual Return (%)'),
                TextFormField(
                  controller: _expectedReturnController,
                  keyboardType: TextInputType.number,
                  decoration: _inputDecoration('e.g., 8.5'),
                  validator: (v) {
                    if (v?.isEmpty == true) return 'Required';
                    if (double.tryParse(v!) == null) return 'Invalid number';
                    return null;
                  },
                ),
                const SizedBox(height: 20),

                // Institution
                _buildLabel('Institution Name (Optional)'),
                TextFormField(
                  controller: _institutionController,
                  decoration: _inputDecoration('e.g., Bank of Kigali'),
                ),
                const SizedBox(height: 20),

                // Start Date
                _buildLabel('Start Date'),
                _buildDatePicker(
                  _startDate,
                  (date) => setState(() => _startDate = date),
                ),
                const SizedBox(height: 20),

                // Maturity Date
                _buildLabel('Maturity Date (Optional)'),
                _buildDatePicker(
                  _maturityDate,
                  (date) => setState(() => _maturityDate = date),
                  allowNull: true,
                ),
                const SizedBox(height: 20),

                // Auto Contribute
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(
                    'Auto-contribute monthly',
                    style: GoogleFonts.inter(
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  subtitle: Text(
                    'Automatically add contribution each month',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: Colors.grey[600],
                    ),
                  ),
                  value: _autoContribute,
                  onChanged: (v) => setState(() => _autoContribute = v),
                  activeColor: AppColors.primary,
                ),

                if (_autoContribute) ...[
                  const SizedBox(height: 16),
                  _buildLabel('Monthly Contribution (RWF)'),
                  TextFormField(
                    controller: _monthlyContributionController,
                    keyboardType: TextInputType.number,
                    decoration: _inputDecoration('0'),
                  ),
                  const SizedBox(height: 16),
                  _buildLabel('Contribution Day'),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<int>(
                        isExpanded: true,
                        value: _contributionDay,
                        items: List.generate(
                          28,
                          (i) => DropdownMenuItem(
                            value: i + 1,
                            child: Text('Day ${i + 1}'),
                          ),
                        ),
                        onChanged: (v) {
                          if (v != null) setState(() => _contributionDay = v);
                        },
                      ),
                    ),
                  ),
                ],

                const SizedBox(height: 32),

                // Submit Button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _submit,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(
                      isEditing ? 'Update Investment' : 'Add Investment',
                      style: GoogleFonts.inter(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
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

  InputDecoration _inputDecoration(String hint) {
    return InputDecoration(
      hintText: hint,
      filled: true,
      fillColor: Colors.white,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
    );
  }

  Widget _buildDatePicker(
    DateTime? date,
    Function(DateTime) onChanged, {
    bool allowNull = false,
  }) {
    return InkWell(
      onTap: () async {
        final picked = await showDatePicker(
          context: context,
          initialDate: date ?? DateTime.now(),
          firstDate: DateTime(2020),
          lastDate: DateTime(2050),
        );
        if (picked != null) {
          onChanged(picked);
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              date != null
                  ? DateFormat('MMM d, yyyy').format(date)
                  : 'Select date',
              style: GoogleFonts.inter(
                color: date != null ? Colors.black : Colors.grey,
              ),
            ),
            const Icon(Icons.calendar_today, size: 20, color: Colors.grey),
          ],
        ),
      ),
    );
  }

  String _getTypeLabel(InvestmentType type) {
    switch (type) {
      case InvestmentType.ejo_heza:
        return 'Ejo Heza Pension';
      case InvestmentType.rnit:
        return 'RNIT Bonds';
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

  void _submit() {
    if (_formKey.currentState!.validate()) {
      final data = {
        'investment_type': _type.name,
        'name': _nameController.text,
        'description': _descriptionController.text.isEmpty
            ? null
            : _descriptionController.text,
        'initial_amount': double.parse(_initialAmountController.text),
        'expected_annual_return': double.parse(_expectedReturnController.text),
        'monthly_contribution': _autoContribute
            ? double.parse(_monthlyContributionController.text)
            : 0.0,
        'contribution_day': _contributionDay,
        'auto_contribute': _autoContribute,
        'start_date': _startDate.toIso8601String(),
        'maturity_date': _maturityDate?.toIso8601String(),
        'institution_name': _institutionController.text.isEmpty
            ? null
            : _institutionController.text,
      };

      context.read<InvestmentBloc>().add(CreateInvestment(data));
    }
  }
}
