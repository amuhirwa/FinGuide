/*
 * Goals Page
 * ==========
 * Full savings goals list and management
 */

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../../../core/di/injection.dart';
import '../../../../core/theme/app_theme.dart';
import '../../data/models/savings_goal_model.dart';
import '../bloc/goals_bloc.dart';

class GoalsPage extends StatefulWidget {
  const GoalsPage({super.key});

  @override
  State<GoalsPage> createState() => _GoalsPageState();
}

class _GoalsPageState extends State<GoalsPage> {
  @override
  void initState() {
    super.initState();
    context.read<GoalsBloc>().add(LoadGoals());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FD),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: Text(
          'Savings Goals',
          style: GoogleFonts.poppins(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: const Color(0xFF1E293B),
          ),
        ),
      ),
      body: BlocBuilder<GoalsBloc, GoalsState>(
        builder: (context, state) {
          if (state is GoalsLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          if (state is GoalsError) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.error_outline, size: 64, color: Colors.grey[300]),
                  const SizedBox(height: 16),
                  Text(
                    'Failed to load goals',
                    style: GoogleFonts.inter(color: Colors.grey[600]),
                  ),
                  const SizedBox(height: 8),
                  ElevatedButton(
                    onPressed: () => context.read<GoalsBloc>().add(LoadGoals()),
                    child: const Text('Retry'),
                  ),
                ],
              ),
            );
          }

          if (state is GoalsLoaded) {
            if (state.goals.isEmpty) {
              return _buildEmptyState();
            }
            return _buildGoalsList(state.goals);
          }

          return _buildEmptyState();
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const CreateGoalPage()),
        ).then((_) => context.read<GoalsBloc>().add(LoadGoals())),
        backgroundColor: AppColors.secondary,
        icon: const Icon(Icons.add, color: Colors.white),
        label: Text(
          'New Goal',
          style: GoogleFonts.inter(
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: AppColors.secondary.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.flag_outlined,
                size: 64,
                color: AppColors.secondary,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'No savings goals yet',
              style: GoogleFonts.poppins(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF1E293B),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Create your first goal to start saving towards something meaningful',
              style: GoogleFonts.inter(
                fontSize: 14,
                color: Colors.grey[600],
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const CreateGoalPage()),
              ).then((_) => context.read<GoalsBloc>().add(LoadGoals())),
              icon: const Icon(Icons.add),
              label: const Text('Create First Goal'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.secondary,
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGoalsList(List<SavingsGoalModel> goals) {
    // Separate active and completed
    final activeGoals =
        goals.where((g) => g.status == GoalStatus.active).toList();
    final completedGoals =
        goals.where((g) => g.status == GoalStatus.completed).toList();

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Summary Card
        _buildSummaryCard(goals),
        const SizedBox(height: 24),

        // Active Goals
        if (activeGoals.isNotEmpty) ...[
          Text(
            'Active Goals',
            style: GoogleFonts.poppins(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: const Color(0xFF1E293B),
            ),
          ),
          const SizedBox(height: 12),
          ...activeGoals.map((goal) => _GoalCard(
                goal: goal,
                onTap: () => _openGoalDetail(goal),
                onContribute: () => _showContributeDialog(goal),
              )),
        ],

        // Completed Goals
        if (completedGoals.isNotEmpty) ...[
          const SizedBox(height: 24),
          Text(
            'Completed',
            style: GoogleFonts.poppins(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: const Color(0xFF1E293B),
            ),
          ),
          const SizedBox(height: 12),
          ...completedGoals.map((goal) => _GoalCard(
                goal: goal,
                onTap: () => _openGoalDetail(goal),
              )),
        ],

        const SizedBox(height: 80), // FAB space
      ],
    );
  }

  Widget _buildSummaryCard(List<SavingsGoalModel> goals) {
    final format = NumberFormat('#,###', 'en_US');
    final totalTarget = goals.fold<double>(0, (sum, g) => sum + g.targetAmount);
    final totalSaved = goals.fold<double>(0, (sum, g) => sum + g.currentAmount);
    final overallProgress = totalTarget > 0 ? (totalSaved / totalTarget) : 0.0;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [AppColors.secondary, AppColors.secondary.withOpacity(0.8)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppColors.secondary.withOpacity(0.3),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Total Savings Progress',
            style: GoogleFonts.inter(
              fontSize: 14,
              color: Colors.white70,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'RWF ${format.format(totalSaved)}',
            style: GoogleFonts.poppins(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          Text(
            'of RWF ${format.format(totalTarget)}',
            style: GoogleFonts.inter(
              fontSize: 14,
              color: Colors.white70,
            ),
          ),
          const SizedBox(height: 16),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: overallProgress,
              minHeight: 8,
              backgroundColor: Colors.white24,
              valueColor: const AlwaysStoppedAnimation(Colors.white),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '${(overallProgress * 100).toStringAsFixed(1)}% complete',
            style: GoogleFonts.inter(
              fontSize: 13,
              color: Colors.white70,
            ),
          ),
        ],
      ),
    );
  }

  void _openGoalDetail(SavingsGoalModel goal) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => BlocProvider(
          create: (_) => getIt<GoalsBloc>(),
          child: GoalDetailPage(goal: goal),
        ),
      ),
    ).then((_) => context.read<GoalsBloc>().add(LoadGoals()));
  }

  void _showContributeDialog(SavingsGoalModel goal) {
    final controller = TextEditingController();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Padding(
        padding: EdgeInsets.only(
          left: 24,
          right: 24,
          top: 24,
          bottom: MediaQuery.of(context).viewInsets.bottom + 24,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Add to "${goal.name}"',
              style: GoogleFonts.poppins(
                fontSize: 20,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Suggested: RWF ${NumberFormat('#,###').format(goal.weeklyTarget)} this week',
              style: GoogleFonts.inter(
                fontSize: 14,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: controller,
              keyboardType: TextInputType.number,
              autofocus: true,
              decoration: InputDecoration(
                labelText: 'Amount (RWF)',
                filled: true,
                fillColor: Colors.grey[100],
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  final amount = double.tryParse(controller.text);
                  if (amount != null && amount > 0) {
                    context
                        .read<GoalsBloc>()
                        .add(ContributeToGoal(goal.id, amount));
                    Navigator.pop(context);
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.secondary,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text('Add Contribution'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GoalCard extends StatelessWidget {
  final SavingsGoalModel goal;
  final VoidCallback onTap;
  final VoidCallback? onContribute;

  const _GoalCard({
    required this.goal,
    required this.onTap,
    this.onContribute,
  });

  @override
  Widget build(BuildContext context) {
    final format = NumberFormat('#,###', 'en_US');
    final isCompleted = goal.status == GoalStatus.completed;

    return GestureDetector(
      onTap: onTap,
      child: Container(
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
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: _getPriorityColor().withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    isCompleted ? Icons.check_circle : Icons.flag,
                    color: _getPriorityColor(),
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        goal.name,
                        style: GoogleFonts.poppins(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF1E293B),
                        ),
                      ),
                      if (goal.deadline != null)
                        Text(
                          isCompleted
                              ? 'Completed!'
                              : 'Due ${DateFormat('MMM d, yyyy').format(goal.deadline!)}',
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            color:
                                isCompleted ? Colors.green : Colors.grey[500],
                          ),
                        ),
                    ],
                  ),
                ),
                if (!isCompleted && onContribute != null)
                  IconButton(
                    onPressed: onContribute,
                    icon: Icon(Icons.add_circle, color: AppColors.secondary),
                    tooltip: 'Add contribution',
                  ),
              ],
            ),
            const SizedBox(height: 16),

            // Progress
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'RWF ${format.format(goal.currentAmount)}',
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: AppColors.primary,
                  ),
                ),
                Text(
                  'of RWF ${format.format(goal.targetAmount)}',
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: goal.progressPercentage / 100,
                minHeight: 8,
                backgroundColor: Colors.grey[200],
                valueColor: AlwaysStoppedAnimation(
                  isCompleted ? Colors.green : AppColors.primary,
                ),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${goal.progressPercentage.toStringAsFixed(1)}%',
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: Colors.grey[600],
                  ),
                ),
                if (!isCompleted && goal.weeklyTarget > 0)
                  Text(
                    'Save RWF ${format.format(goal.weeklyTarget)}/week',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: AppColors.secondary,
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Color _getPriorityColor() {
    switch (goal.priority) {
      case GoalPriority.critical:
        return Colors.red;
      case GoalPriority.high:
        return Colors.orange;
      case GoalPriority.medium:
        return AppColors.secondary;
      case GoalPriority.low:
        return Colors.blue;
    }
  }
}

// ==================== Create Goal Page ====================

class CreateGoalPage extends StatefulWidget {
  final SavingsGoalModel? goal;

  const CreateGoalPage({super.key, this.goal});

  @override
  State<CreateGoalPage> createState() => _CreateGoalPageState();
}

class _CreateGoalPageState extends State<CreateGoalPage> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _amountController = TextEditingController();

  GoalPriority _priority = GoalPriority.medium;
  DateTime? _deadline;
  bool _isFlexible = false;

  bool get isEditing => widget.goal != null;

  @override
  void initState() {
    super.initState();
    if (widget.goal != null) {
      final g = widget.goal!;
      _nameController.text = g.name;
      _descriptionController.text = g.description ?? '';
      _amountController.text = g.targetAmount.toString();
      _priority = g.priority;
      _deadline = g.deadline;
      _isFlexible = g.isFlexible;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _amountController.dispose();
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
          isEditing ? 'Edit Goal' : 'Create Goal',
          style: GoogleFonts.poppins(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: const Color(0xFF1E293B),
          ),
        ),
      ),
      body: BlocListener<GoalsBloc, GoalsState>(
        listener: (context, state) {
          if (state is GoalCreated || state is GoalUpdated) {
            Navigator.pop(context, true);
          } else if (state is GoalsError) {
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
                // Goal Name
                _buildLabel('Goal Name'),
                TextFormField(
                  controller: _nameController,
                  decoration: _inputDecoration('e.g., Emergency Fund'),
                  validator: (v) => v?.isEmpty == true ? 'Required' : null,
                ),
                const SizedBox(height: 20),

                // Description
                _buildLabel('Description (Optional)'),
                TextFormField(
                  controller: _descriptionController,
                  decoration: _inputDecoration('What are you saving for?'),
                  maxLines: 2,
                ),
                const SizedBox(height: 20),

                // Target Amount
                _buildLabel('Target Amount (RWF)'),
                TextFormField(
                  controller: _amountController,
                  keyboardType: TextInputType.number,
                  decoration: _inputDecoration('0'),
                  validator: (v) {
                    if (v?.isEmpty == true) return 'Required';
                    if (double.tryParse(v!) == null) return 'Invalid number';
                    return null;
                  },
                ),
                const SizedBox(height: 20),

                // Priority
                _buildLabel('Priority'),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: GoalPriority.values.map((p) {
                    final isSelected = _priority == p;
                    return GestureDetector(
                      onTap: () => setState(() => _priority = p),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: isSelected ? AppColors.primary : Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isSelected
                                ? AppColors.primary
                                : Colors.grey[300]!,
                          ),
                        ),
                        child: Text(
                          p.name.toUpperCase(),
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: isSelected ? Colors.white : Colors.grey[700],
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 20),

                // Deadline
                _buildLabel('Target Date'),
                GestureDetector(
                  onTap: _selectDeadline,
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
                          _deadline != null
                              ? DateFormat('EEEE, MMM d, yyyy')
                                  .format(_deadline!)
                              : 'Select a date',
                          style: GoogleFonts.inter(
                            fontSize: 16,
                            color: _deadline != null
                                ? const Color(0xFF1E293B)
                                : Colors.grey,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                // Flexible deadline
                Row(
                  children: [
                    Switch(
                      value: _isFlexible,
                      onChanged: (v) => setState(() => _isFlexible = v),
                      activeColor: AppColors.primary,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Flexible deadline (adjust based on cash flow)',
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          color: Colors.grey[700],
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 40),

                // Submit Button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _submit,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.secondary,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(
                      isEditing ? 'Update Goal' : 'Create Goal',
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

  Future<void> _selectDeadline() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _deadline ?? DateTime.now().add(const Duration(days: 30)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365 * 5)),
    );
    if (picked != null) {
      setState(() => _deadline = picked);
    }
  }

  void _submit() {
    if (_formKey.currentState!.validate()) {
      final data = {
        'name': _nameController.text,
        'description': _descriptionController.text.isEmpty
            ? null
            : _descriptionController.text,
        'target_amount': double.parse(_amountController.text),
        'priority': _priority.name,
        'deadline': _deadline?.toIso8601String(),
        'is_flexible': _isFlexible,
      };

      if (isEditing) {
        context.read<GoalsBloc>().add(UpdateGoal(widget.goal!.id, data));
      } else {
        context.read<GoalsBloc>().add(CreateGoal(data));
      }
    }
  }
}

// ==================== Goal Detail Page ====================

class GoalDetailPage extends StatelessWidget {
  final SavingsGoalModel goal;

  const GoalDetailPage({super.key, required this.goal});

  @override
  Widget build(BuildContext context) {
    final format = NumberFormat('#,###', 'en_US');
    final isCompleted = goal.status == GoalStatus.completed;

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FD),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: Text(
          goal.name,
          style: GoogleFonts.poppins(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: const Color(0xFF1E293B),
          ),
        ),
        actions: [
          PopupMenuButton(
            itemBuilder: (context) => [
              const PopupMenuItem(value: 'edit', child: Text('Edit')),
              const PopupMenuItem(value: 'delete', child: Text('Delete')),
            ],
            onSelected: (value) {
              if (value == 'edit') {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => BlocProvider(
                      create: (_) => getIt<GoalsBloc>(),
                      child: CreateGoalPage(goal: goal),
                    ),
                  ),
                );
              } else if (value == 'delete') {
                _confirmDelete(context);
              }
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Progress Card
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: isCompleted ? Colors.green : AppColors.primary,
                borderRadius: BorderRadius.circular(24),
              ),
              child: Column(
                children: [
                  if (isCompleted)
                    const Icon(Icons.check_circle,
                        color: Colors.white, size: 48)
                  else
                    Stack(
                      alignment: Alignment.center,
                      children: [
                        SizedBox(
                          width: 120,
                          height: 120,
                          child: CircularProgressIndicator(
                            value: goal.progressPercentage / 100,
                            strokeWidth: 12,
                            backgroundColor: Colors.white24,
                            valueColor:
                                const AlwaysStoppedAnimation(Colors.white),
                          ),
                        ),
                        Text(
                          '${goal.progressPercentage.toStringAsFixed(0)}%',
                          style: GoogleFonts.poppins(
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  const SizedBox(height: 20),
                  Text(
                    'RWF ${format.format(goal.currentAmount)}',
                    style: GoogleFonts.poppins(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  Text(
                    'of RWF ${format.format(goal.targetAmount)}',
                    style: GoogleFonts.inter(
                      fontSize: 16,
                      color: Colors.white70,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Savings Targets
            if (!isCompleted) ...[
              Text(
                'Savings Targets',
                style: GoogleFonts.poppins(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _TargetCard(
                      label: 'Daily',
                      amount: goal.dailyTarget,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _TargetCard(
                      label: 'Weekly',
                      amount: goal.weeklyTarget,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
            ],

            // Details
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Details',
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 16),
                  _DetailRow(label: 'Priority', value: goal.priorityDisplay),
                  const Divider(height: 24),
                  _DetailRow(label: 'Status', value: goal.statusDisplay),
                  if (goal.deadline != null) ...[
                    const Divider(height: 24),
                    _DetailRow(
                      label: 'Deadline',
                      value: DateFormat('MMM d, yyyy').format(goal.deadline!),
                    ),
                  ],
                  if (goal.description != null) ...[
                    const Divider(height: 24),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Description',
                          style: GoogleFonts.inter(
                            fontSize: 14,
                            color: Colors.grey[600],
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          goal.description!,
                          style: GoogleFonts.inter(
                            fontSize: 14,
                            color: const Color(0xFF1E293B),
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: isCompleted
          ? null
          : SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: ElevatedButton(
                  onPressed: () => _showContributeDialog(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.secondary,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(
                    'Add Contribution',
                    style: GoogleFonts.inter(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ),
    );
  }

  void _showContributeDialog(BuildContext context) {
    final controller = TextEditingController();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          left: 24,
          right: 24,
          top: 24,
          bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Add Contribution',
              style: GoogleFonts.poppins(
                fontSize: 20,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: controller,
              keyboardType: TextInputType.number,
              autofocus: true,
              decoration: InputDecoration(
                labelText: 'Amount (RWF)',
                filled: true,
                fillColor: Colors.grey[100],
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  final amount = double.tryParse(controller.text);
                  if (amount != null && amount > 0) {
                    context
                        .read<GoalsBloc>()
                        .add(ContributeToGoal(goal.id, amount));
                    Navigator.pop(ctx);
                    Navigator.pop(context);
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.secondary,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text('Confirm'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _confirmDelete(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Goal?'),
        content: const Text('This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              context.read<GoalsBloc>().add(DeleteGoal(goal.id));
              Navigator.pop(ctx);
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}

class _TargetCard extends StatelessWidget {
  final String label;
  final double amount;

  const _TargetCard({required this.label, required this.amount});

  @override
  Widget build(BuildContext context) {
    final format = NumberFormat('#,###', 'en_US');
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 13,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'RWF ${format.format(amount)}',
            style: GoogleFonts.poppins(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: AppColors.primary,
            ),
          ),
        ],
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final String label;
  final String value;

  const _DetailRow({required this.label, required this.value});

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
            color: const Color(0xFF1E293B),
          ),
        ),
      ],
    );
  }
}
