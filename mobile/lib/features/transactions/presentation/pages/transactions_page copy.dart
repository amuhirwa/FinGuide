/*
 * Transactions Page
 * =================
 * Full transaction list with filters
 */

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_theme.dart';
import '../../data/models/transaction_model.dart';
import '../bloc/transaction_bloc.dart';

class TransactionsPage extends StatefulWidget {
  const TransactionsPage({super.key});

  @override
  State<TransactionsPage> createState() => _TransactionsPageState();
}

class _TransactionsPageState extends State<TransactionsPage> {
  String? _selectedType;
  String? _selectedCategory;
  final _currencyFormat = NumberFormat('#,###', 'en_US');

  @override
  void initState() {
    super.initState();
    context.read<TransactionBloc>().add(LoadTransactions());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FD),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: Text(
          'Transactions',
          style: GoogleFonts.poppins(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: const Color(0xFF1E293B),
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.filter_list, color: Color(0xFF1E293B)),
            onPressed: _showFilterSheet,
          ),
        ],
      ),
      body: Column(
        children: [
          // Summary Card
          _buildSummaryCard(),

          // Filter Chips
          if (_selectedType != null || _selectedCategory != null)
            _buildActiveFilters(),

          // Transaction List
          Expanded(
            child: BlocBuilder<TransactionBloc, TransactionState>(
              builder: (context, state) {
                if (state is TransactionLoading) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (state is TransactionError) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.error_outline,
                            size: 64, color: Colors.grey[300]),
                        const SizedBox(height: 16),
                        Text(
                          'Failed to load transactions',
                          style: GoogleFonts.inter(color: Colors.grey[600]),
                        ),
                        const SizedBox(height: 8),
                        ElevatedButton(
                          onPressed: () => context
                              .read<TransactionBloc>()
                              .add(LoadTransactions()),
                          child: const Text('Retry'),
                        ),
                      ],
                    ),
                  );
                }

                if (state is TransactionsLoaded) {
                  if (state.transactions.isEmpty) {
                    return _buildEmptyState();
                  }
                  return _buildTransactionList(state.transactions);
                }

                return _buildEmptyState();
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const AddTransactionPage()),
        ),
        backgroundColor: AppColors.primary,
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  Widget _buildSummaryCard() {
    return BlocBuilder<TransactionBloc, TransactionState>(
      builder: (context, state) {
        double income = 0;
        double expenses = 0;

        if (state is TransactionsLoaded && state.summary != null) {
          income = state.summary!.totalIncome;
          expenses = state.summary!.totalExpenses;
        }

        return Container(
          margin: const EdgeInsets.all(16),
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
          child: Row(
            children: [
              Expanded(
                child: _SummaryItem(
                  label: 'Income',
                  amount: income,
                  color: Colors.green,
                  icon: Icons.arrow_downward,
                ),
              ),
              Container(
                width: 1,
                height: 50,
                color: Colors.grey[200],
              ),
              Expanded(
                child: _SummaryItem(
                  label: 'Expenses',
                  amount: expenses,
                  color: Colors.red,
                  icon: Icons.arrow_upward,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildActiveFilters() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          if (_selectedType != null)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Chip(
                label: Text(_selectedType!),
                deleteIcon: const Icon(Icons.close, size: 18),
                onDeleted: () {
                  setState(() => _selectedType = null);
                  _applyFilters();
                },
              ),
            ),
          if (_selectedCategory != null)
            Chip(
              label: Text(_selectedCategory!),
              deleteIcon: const Icon(Icons.close, size: 18),
              onDeleted: () {
                setState(() => _selectedCategory = null);
                _applyFilters();
              },
            ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.receipt_long_outlined, size: 80, color: Colors.grey[300]),
          const SizedBox(height: 16),
          Text(
            'No transactions yet',
            style: GoogleFonts.poppins(
              fontSize: 18,
              fontWeight: FontWeight.w500,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Add your first transaction or import from SMS',
            style: GoogleFonts.inter(
              fontSize: 14,
              color: Colors.grey[500],
            ),
          ),
          const SizedBox(height: 24),
          OutlinedButton.icon(
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const SmsImportPage()),
            ),
            icon: const Icon(Icons.sms_outlined),
            label: const Text('Import from SMS'),
          ),
        ],
      ),
    );
  }

  Widget _buildTransactionList(List<TransactionModel> transactions) {
    // Group by date
    final grouped = <String, List<TransactionModel>>{};
    for (var tx in transactions) {
      final dateKey = DateFormat('yyyy-MM-dd').format(tx.transactionDate);
      grouped.putIfAbsent(dateKey, () => []).add(tx);
    }

    final sortedKeys = grouped.keys.toList()..sort((a, b) => b.compareTo(a));

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: sortedKeys.length,
      itemBuilder: (context, index) {
        final dateKey = sortedKeys[index];
        final dayTransactions = grouped[dateKey]!;
        final date = DateTime.parse(dateKey);

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Text(
                _formatDate(date),
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey[600],
                ),
              ),
            ),
            ...dayTransactions.map((tx) => _TransactionTile(
                  transaction: tx,
                  onTap: () => _showTransactionDetail(tx),
                )),
          ],
        );
      },
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final txDate = DateTime(date.year, date.month, date.day);

    if (txDate == today) return 'Today';
    if (txDate == yesterday) return 'Yesterday';
    return DateFormat('EEEE, MMM d').format(date);
  }

  void _showFilterSheet() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => _FilterSheet(
        selectedType: _selectedType,
        selectedCategory: _selectedCategory,
        onApply: (type, category) {
          setState(() {
            _selectedType = type;
            _selectedCategory = category;
          });
          _applyFilters();
          Navigator.pop(context);
        },
      ),
    );
  }

  void _applyFilters() {
    context.read<TransactionBloc>().add(LoadTransactions(
          transactionType: _selectedType,
          category: _selectedCategory,
        ));
  }

  void _showTransactionDetail(TransactionModel tx) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => BlocProvider.value(
          value: context.read<TransactionBloc>(),
          child: TransactionDetailPage(transaction: tx),
        ),
      ),
    );
  }
}

class _SummaryItem extends StatelessWidget {
  final String label;
  final double amount;
  final Color color;
  final IconData icon;

  const _SummaryItem({
    required this.label,
    required this.amount,
    required this.color,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final format = NumberFormat('#,###', 'en_US');
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 16, color: color),
            const SizedBox(width: 4),
            Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 13,
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          'RWF ${format.format(amount)}',
          style: GoogleFonts.poppins(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: color,
          ),
        ),
      ],
    );
  }
}

class _TransactionTile extends StatelessWidget {
  final TransactionModel transaction;
  final VoidCallback onTap;

  const _TransactionTile({
    required this.transaction,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final format = NumberFormat('#,###', 'en_US');
    final isIncome = transaction.transactionType == TransactionType.income;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.02),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: _getCategoryColor().withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                _getCategoryIcon(),
                color: _getCategoryColor(),
                size: 24,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    transaction.description ?? transaction.categoryDisplay,
                    style: GoogleFonts.inter(
                      fontWeight: FontWeight.w600,
                      fontSize: 15,
                      color: const Color(0xFF1E293B),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Text(
                        transaction.categoryDisplay,
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          color: Colors.grey[500],
                        ),
                      ),
                      if (!transaction.isVerified) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.orange.shade100,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            'Unverified',
                            style: GoogleFonts.inter(
                              fontSize: 10,
                              fontWeight: FontWeight.w500,
                              color: Colors.orange.shade700,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            Text(
              '${isIncome ? '+' : '-'} RWF ${format.format(transaction.amount)}',
              style: GoogleFonts.inter(
                fontWeight: FontWeight.bold,
                fontSize: 14,
                color: isIncome ? Colors.green[700] : const Color(0xFF1E293B),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _getCategoryColor() {
    switch (transaction.category) {
      case TransactionCategory.salary:
      case TransactionCategory.freelance:
      case TransactionCategory.business:
      case TransactionCategory.gift_received:
      case TransactionCategory.refund:
      case TransactionCategory.other_income:
        return Colors.green;
      case TransactionCategory.food_groceries:
      case TransactionCategory.dining_out:
        return Colors.orange;
      case TransactionCategory.transport:
        return Colors.blue;
      case TransactionCategory.utilities:
      case TransactionCategory.rent:
        return Colors.purple;
      case TransactionCategory.entertainment:
      case TransactionCategory.subscriptions:
        return Colors.pink;
      case TransactionCategory.savings:
      case TransactionCategory.ejo_heza:
      case TransactionCategory.investment:
        return Colors.teal;
      case TransactionCategory.airtime_data:
        return Colors.indigo;
      case TransactionCategory.healthcare:
        return Colors.red;
      case TransactionCategory.education:
        return Colors.cyan;
      case TransactionCategory.shopping:
        return Colors.amber;
      case TransactionCategory.transfer_out:
      case TransactionCategory.fees:
      case TransactionCategory.other:
        return Colors.grey;
    }
  }

  IconData _getCategoryIcon() {
    switch (transaction.category) {
      case TransactionCategory.salary:
        return Icons.work_outline;
      case TransactionCategory.freelance:
        return Icons.laptop;
      case TransactionCategory.business:
        return Icons.store;
      case TransactionCategory.gift_received:
        return Icons.card_giftcard;
      case TransactionCategory.refund:
        return Icons.replay;
      case TransactionCategory.other_income:
        return Icons.attach_money;
      case TransactionCategory.food_groceries:
        return Icons.restaurant;
      case TransactionCategory.dining_out:
        return Icons.local_dining;
      case TransactionCategory.transport:
        return Icons.directions_bus;
      case TransactionCategory.utilities:
        return Icons.flash_on;
      case TransactionCategory.rent:
        return Icons.home;
      case TransactionCategory.entertainment:
        return Icons.movie;
      case TransactionCategory.subscriptions:
        return Icons.subscriptions;
      case TransactionCategory.savings:
        return Icons.savings;
      case TransactionCategory.ejo_heza:
        return Icons.account_balance;
      case TransactionCategory.investment:
        return Icons.trending_up;
      case TransactionCategory.airtime_data:
        return Icons.phone_android;
      case TransactionCategory.healthcare:
        return Icons.local_hospital;
      case TransactionCategory.education:
        return Icons.school;
      case TransactionCategory.shopping:
        return Icons.shopping_bag;
      case TransactionCategory.transfer_out:
        return Icons.swap_horiz;
      case TransactionCategory.fees:
        return Icons.receipt_long;
      case TransactionCategory.other:
        return Icons.receipt;
    }
  }
}

class _FilterSheet extends StatefulWidget {
  final String? selectedType;
  final String? selectedCategory;
  final Function(String?, String?) onApply;

  const _FilterSheet({
    this.selectedType,
    this.selectedCategory,
    required this.onApply,
  });

  @override
  State<_FilterSheet> createState() => _FilterSheetState();
}

class _FilterSheetState extends State<_FilterSheet> {
  String? _type;
  String? _category;

  @override
  void initState() {
    super.initState();
    _type = widget.selectedType;
    _category = widget.selectedCategory;
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Filter Transactions',
            style: GoogleFonts.poppins(
              fontSize: 20,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'Transaction Type',
            style: GoogleFonts.inter(
              fontWeight: FontWeight.w500,
              color: Colors.grey[700],
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            children: [
              _FilterChip(
                label: 'All',
                selected: _type == null,
                onSelected: () => setState(() => _type = null),
              ),
              _FilterChip(
                label: 'Income',
                selected: _type == 'income',
                onSelected: () => setState(() => _type = 'income'),
              ),
              _FilterChip(
                label: 'Expense',
                selected: _type == 'expense',
                onSelected: () => setState(() => _type = 'expense'),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Text(
            'Category',
            style: GoogleFonts.inter(
              fontWeight: FontWeight.w500,
              color: Colors.grey[700],
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _FilterChip(
                label: 'All',
                selected: _category == null,
                onSelected: () => setState(() => _category = null),
              ),
              ...TransactionCategory.values.take(8).map(
                    (c) => _FilterChip(
                      label: c.name,
                      selected: _category == c.name,
                      onSelected: () => setState(() => _category = c.name),
                    ),
                  ),
            ],
          ),
          const SizedBox(height: 32),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => widget.onApply(_type, _category),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text('Apply Filters'),
            ),
          ),
        ],
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onSelected;

  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onSelected,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? AppColors.primary : Colors.grey[100],
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: selected ? Colors.white : Colors.grey[700],
          ),
        ),
      ),
    );
  }
}

// ==================== Add Transaction Page ====================

class AddTransactionPage extends StatefulWidget {
  final TransactionModel? transaction;

  const AddTransactionPage({super.key, this.transaction});

  @override
  State<AddTransactionPage> createState() => _AddTransactionPageState();
}

class _AddTransactionPageState extends State<AddTransactionPage> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _descriptionController = TextEditingController();

  TransactionType _type = TransactionType.expense;
  TransactionCategory _category = TransactionCategory.other;
  NeedWantCategory _needWant = NeedWantCategory.uncategorized;
  DateTime _date = DateTime.now();

  bool get isEditing => widget.transaction != null;

  @override
  void initState() {
    super.initState();
    if (widget.transaction != null) {
      final tx = widget.transaction!;
      _amountController.text = tx.amount.toString();
      _descriptionController.text = tx.description ?? '';
      _type = tx.transactionType;
      _category = tx.category;
      _needWant = tx.needWant;
      _date = tx.transactionDate;
    }
  }

  @override
  void dispose() {
    _amountController.dispose();
    _descriptionController.dispose();
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
          isEditing ? 'Edit Transaction' : 'Add Transaction',
          style: GoogleFonts.poppins(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: const Color(0xFF1E293B),
          ),
        ),
      ),
      body: BlocListener<TransactionBloc, TransactionState>(
        listener: (context, state) {
          if (state is TransactionCreated) {
            Navigator.pop(context, true);
          } else if (state is TransactionError) {
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
                // Type Selector
                Text(
                  'Type',
                  style: GoogleFonts.inter(
                    fontWeight: FontWeight.w500,
                    color: Colors.grey[700],
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _TypeButton(
                        label: 'Income',
                        icon: Icons.arrow_downward,
                        color: Colors.green,
                        selected: _type == TransactionType.income,
                        onTap: () =>
                            setState(() => _type = TransactionType.income),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _TypeButton(
                        label: 'Expense',
                        icon: Icons.arrow_upward,
                        color: Colors.red,
                        selected: _type == TransactionType.expense,
                        onTap: () =>
                            setState(() => _type = TransactionType.expense),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // Amount
                Text(
                  'Amount (RWF)',
                  style: GoogleFonts.inter(
                    fontWeight: FontWeight.w500,
                    color: Colors.grey[700],
                  ),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _amountController,
                  keyboardType: TextInputType.number,
                  style: GoogleFonts.poppins(
                    fontSize: 24,
                    fontWeight: FontWeight.w600,
                  ),
                  decoration: InputDecoration(
                    hintText: '0',
                    prefixText: 'RWF ',
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter an amount';
                    }
                    if (double.tryParse(value) == null) {
                      return 'Please enter a valid number';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 24),

                // Description
                Text(
                  'Description',
                  style: GoogleFonts.inter(
                    fontWeight: FontWeight.w500,
                    color: Colors.grey[700],
                  ),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _descriptionController,
                  decoration: InputDecoration(
                    hintText: 'What was this for?',
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // Category
                Text(
                  'Category',
                  style: GoogleFonts.inter(
                    fontWeight: FontWeight.w500,
                    color: Colors.grey[700],
                  ),
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<TransactionCategory>(
                      isExpanded: true,
                      value: _category,
                      items: TransactionCategory.values
                          .map((c) => DropdownMenuItem(
                                value: c,
                                child: Text(_getCategoryDisplayName(c)),
                              ))
                          .toList(),
                      onChanged: (value) {
                        if (value != null) setState(() => _category = value);
                      },
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // Need/Want
                if (_type == TransactionType.expense) ...[
                  Text(
                    'Is this a Need or Want?',
                    style: GoogleFonts.inter(
                      fontWeight: FontWeight.w500,
                      color: Colors.grey[700],
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: _NeedWantButton(
                          label: 'Need',
                          selected: _needWant == NeedWantCategory.need,
                          onTap: () =>
                              setState(() => _needWant = NeedWantCategory.need),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _NeedWantButton(
                          label: 'Want',
                          selected: _needWant == NeedWantCategory.want,
                          onTap: () =>
                              setState(() => _needWant = NeedWantCategory.want),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                ],

                // Date
                Text(
                  'Date',
                  style: GoogleFonts.inter(
                    fontWeight: FontWeight.w500,
                    color: Colors.grey[700],
                  ),
                ),
                const SizedBox(height: 12),
                GestureDetector(
                  onTap: _selectDate,
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.calendar_today, color: Colors.grey),
                        const SizedBox(width: 12),
                        Text(
                          DateFormat('EEEE, MMM d, yyyy').format(_date),
                          style: GoogleFonts.inter(fontSize: 16),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 40),

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
                      isEditing ? 'Update Transaction' : 'Add Transaction',
                      style: GoogleFonts.inter(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
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

  Future<void> _selectDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      setState(() => _date = picked);
    }
  }

  String _getCategoryDisplayName(TransactionCategory category) {
    switch (category) {
      case TransactionCategory.salary:
        return 'Salary';
      case TransactionCategory.freelance:
        return 'Freelance';
      case TransactionCategory.business:
        return 'Business';
      case TransactionCategory.gift_received:
        return 'Gift Received';
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
        return 'Transfer Out';
      case TransactionCategory.fees:
        return 'Fees';
      case TransactionCategory.other:
        return 'Other';
    }
  }

  void _submit() {
    if (_formKey.currentState!.validate()) {
      final data = {
        'transaction_type': _type.name,
        'category': _category.name,
        'need_want': _needWant.name,
        'amount': double.parse(_amountController.text),
        'description': _descriptionController.text,
        'transaction_date': _date.toIso8601String(),
      };

      if (isEditing) {
        context
            .read<TransactionBloc>()
            .add(UpdateTransaction(widget.transaction!.id, data));
      } else {
        context.read<TransactionBloc>().add(CreateTransaction(data));
      }
    }
  }
}

class _TypeButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final bool selected;
  final VoidCallback onTap;

  const _TypeButton({
    required this.label,
    required this.icon,
    required this.color,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: selected ? color.withOpacity(0.1) : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? color : Colors.grey[300]!,
            width: 2,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: selected ? color : Colors.grey),
            const SizedBox(width: 8),
            Text(
              label,
              style: GoogleFonts.inter(
                fontWeight: FontWeight.w600,
                color: selected ? color : Colors.grey,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NeedWantButton extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _NeedWantButton({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: selected ? AppColors.primary : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? AppColors.primary : Colors.grey[300]!,
          ),
        ),
        child: Center(
          child: Text(
            label,
            style: GoogleFonts.inter(
              fontWeight: FontWeight.w500,
              color: selected ? Colors.white : Colors.grey[700],
            ),
          ),
        ),
      ),
    );
  }
}

// ==================== Transaction Detail Page ====================

class TransactionDetailPage extends StatelessWidget {
  final TransactionModel transaction;

  const TransactionDetailPage({super.key, required this.transaction});

  @override
  Widget build(BuildContext context) {
    final format = NumberFormat('#,###', 'en_US');
    final isIncome = transaction.transactionType == TransactionType.income;

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FD),
      floatingActionButton: transaction.counterparty != null
          ? FloatingActionButton.extended(
              onPressed: () => showModalBottomSheet(
                context: context,
                isScrollControlled: true,
                shape: const RoundedRectangleBorder(
                  borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                ),
                builder: (sheetCtx) => BlocProvider.value(
                  value: context.read<TransactionBloc>(),
                  child: _SetRuleSheet(transaction: transaction),
                ),
              ),
              icon: const Icon(Icons.auto_fix_high),
              label: const Text('Set Rule'),
              backgroundColor: AppColors.primary,
            )
          : null,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: Text(
          'Transaction Details',
          style: GoogleFonts.poppins(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: const Color(0xFF1E293B),
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_outlined, color: Color(0xFF1E293B)),
            onPressed: () => Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (_) => AddTransactionPage(transaction: transaction),
              ),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            // Amount Card
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: isIncome ? Colors.green : Colors.white,
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
                children: [
                  Text(
                    isIncome ? 'Income' : 'Expense',
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      color: isIncome ? Colors.white70 : Colors.grey[600],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${isIncome ? '+' : '-'} RWF ${format.format(transaction.amount)}',
                    style: GoogleFonts.poppins(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      color: isIncome ? Colors.white : const Color(0xFF1E293B),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    DateFormat('EEEE, MMM d, yyyy • h:mm a')
                        .format(transaction.transactionDate),
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      color: isIncome ? Colors.white70 : Colors.grey[500],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Details Card
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                children: [
                  _DetailRow(
                    label: 'Category',
                    value: transaction.categoryDisplay,
                  ),
                  const Divider(height: 24),
                  _DetailRow(
                    label: 'Type',
                    value: transaction.needWant.name.toUpperCase(),
                  ),
                  if (transaction.description != null) ...[
                    const Divider(height: 24),
                    _DetailRow(
                      label: 'Description',
                      value: transaction.description!,
                    ),
                  ],
                  if (transaction.counterparty != null) ...[
                    const Divider(height: 24),
                    _DetailRow(
                      label: 'Counterparty',
                      value: transaction.counterpartyName ??
                          transaction.counterparty!,
                    ),
                  ],
                  if (transaction.reference != null) ...[
                    const Divider(height: 24),
                    _DetailRow(
                      label: 'Reference',
                      value: transaction.reference!,
                    ),
                  ],
                  const Divider(height: 24),
                  _DetailRow(
                    label: 'Status',
                    value: transaction.isVerified ? 'Verified' : 'Unverified',
                    valueColor:
                        transaction.isVerified ? Colors.green : Colors.orange,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final String label;
  final String value;
  final Color? valueColor;

  const _DetailRow({
    required this.label,
    required this.value,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 14,
            color: Colors.grey[600],
          ),
        ),
        Text(
          value,
          style: GoogleFonts.inter(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: valueColor ?? const Color(0xFF1E293B),
          ),
        ),
      ],
    );
  }
}

// ==================== Counterparty Rule Sheet ====================

class _SetRuleSheet extends StatefulWidget {
  final TransactionModel transaction;

  const _SetRuleSheet({required this.transaction});

  @override
  State<_SetRuleSheet> createState() => _SetRuleSheetState();
}

class _SetRuleSheetState extends State<_SetRuleSheet> {
  late TransactionCategory _category;
  late NeedWantCategory _needWant;

  @override
  void initState() {
    super.initState();
    _category = widget.transaction.category;
    _needWant = widget.transaction.needWant;
  }

  @override
  Widget build(BuildContext context) {
    final name =
        widget.transaction.counterpartyName ?? widget.transaction.counterparty!;
    return Padding(
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 24,
        bottom: MediaQuery.of(context).viewInsets.bottom + 32,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Text(
              'Set Rule for "$name"',
              style: GoogleFonts.poppins(
                  fontSize: 18, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 4),
            Text(
              'Future transactions with this party will use these settings automatically.',
              style: GoogleFonts.inter(fontSize: 13, color: Colors.grey[600]),
            ),
            const SizedBox(height: 24),
            Text(
              'Category',
              style: GoogleFonts.inter(
                  fontWeight: FontWeight.w500, color: Colors.grey[700]),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: TransactionCategory.values.map((c) {
                final selected = _category == c;
                return GestureDetector(
                  onTap: () => setState(() => _category = c),
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: selected ? AppColors.primary : Colors.grey[100],
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      c.name.replaceAll('_', ' '),
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        color: selected ? Colors.white : Colors.grey[700],
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 24),
            Text(
              'Need / Want',
              style: GoogleFonts.inter(
                  fontWeight: FontWeight.w500, color: Colors.grey[700]),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              children: NeedWantCategory.values.map((nw) {
                final selected = _needWant == nw;
                return GestureDetector(
                  onTap: () => setState(() => _needWant = nw),
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: selected ? AppColors.primary : Colors.grey[100],
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      nw.name[0].toUpperCase() + nw.name.substring(1),
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: selected ? Colors.white : Colors.grey[700],
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  context.read<TransactionBloc>().add(
                        UpdateTransaction(widget.transaction.id, {
                          'category': _category.name,
                          'need_want': _needWant.name,
                        }),
                      );
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Rule saved for "$name"'),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text('Save Rule'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ==================== SMS Import Page ====================

class SmsImportPage extends StatefulWidget {
  const SmsImportPage({super.key});

  @override
  State<SmsImportPage> createState() => _SmsImportPageState();
}

class _SmsImportPageState extends State<SmsImportPage> {
  final List<String> _sampleMessages = [
    'You have received RWF 50,000 from 0788123456. Your new balance is RWF 150,000. Ref: TXN123456',
    'You have sent RWF 10,000 to 0788654321 for Airtime Bundle. Your new balance is RWF 140,000. Ref: TXN123457',
    'Payment received: RWF 25,000 from Client ABC. Balance: RWF 165,000. Ref: TXN123458',
  ];

  bool _isLoading = false;
  List<TransactionModel>? _parsedTransactions;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FD),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: Text(
          'Import from SMS',
          style: GoogleFonts.poppins(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: const Color(0xFF1E293B),
          ),
        ),
      ),
      body: BlocListener<TransactionBloc, TransactionState>(
        listener: (context, state) {
          if (state is SmsParseSuccess) {
            setState(() {
              _isLoading = false;
              _parsedTransactions = state.transactions;
            });
          } else if (state is TransactionError) {
            setState(() => _isLoading = false);
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(state.message)),
            );
          }
        },
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Info Card
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline, color: AppColors.primary),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Text(
                        'We\'ll scan your MoMo SMS messages and automatically create transactions from them.',
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          color: const Color(0xFF1E293B),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Permission Request
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'SMS Permission Required',
                      style: GoogleFonts.poppins(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'To import transactions, we need permission to read your SMS messages. We only read MoMo-related messages.',
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        color: Colors.grey[600],
                      ),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _requestPermission,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text('Grant Permission & Scan'),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Demo Mode
              Text(
                'Or try with sample data',
                style: GoogleFonts.inter(
                  fontSize: 14,
                  color: Colors.grey[600],
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: _isLoading ? null : _parseSampleMessages,
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Parse Sample Messages'),
                ),
              ),

              // Results
              if (_parsedTransactions != null) ...[
                const SizedBox(height: 32),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Parsed Transactions',
                      style: GoogleFonts.poppins(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      '${_parsedTransactions!.length} found',
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                ..._parsedTransactions!.map((tx) => _TransactionTile(
                      transaction: tx,
                      onTap: () {},
                    )),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.pop(context);
                      context.read<TransactionBloc>().add(LoadTransactions());
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text('Done'),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  void _requestPermission() {
    // In a real app, request SMS permission here
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('SMS permission would be requested here'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _parseSampleMessages() {
    setState(() => _isLoading = true);
    context.read<TransactionBloc>().add(ParseSmsMessages(_sampleMessages));
  }
}
