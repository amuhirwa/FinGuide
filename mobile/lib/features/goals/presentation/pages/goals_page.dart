/*
 * Goals Page
 * ==========
 * Full savings goals list and management
 */

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart' hide TextDirection;

import '../../../../core/di/injection.dart';
import '../../../../core/theme/app_theme.dart';
import '../../data/models/savings_goal_model.dart';
import '../../../investments/data/models/rnit_model.dart';
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
            if (state.goals.isEmpty && state.piggybank == null) {
              return _buildEmptyState();
            }
            return _buildGoalsList(state.goals, piggybank: state.piggybank);
          }

          return _buildEmptyState();
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => BlocProvider(
              create: (_) => getIt<GoalsBloc>(),
              child: const CreateGoalPage(),
            ),
          ),
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

  Widget _buildGoalsList(List<SavingsGoalModel> goals,
      {PiggyBankModel? piggybank}) {
    final activeGoals =
        goals.where((g) => g.status == GoalStatus.active).toList();
    final completedGoals =
        goals.where((g) => g.status == GoalStatus.completed).toList();

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Piggybank Hero
        if (piggybank != null) ...[
          _PiggyBankHero(
            piggybank: piggybank,
            onTap: () => _showAssignToGoalSheet(piggybank, activeGoals),
          ),
          const SizedBox(height: 24),
        ],

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

  void _showAssignToGoalSheet(
      PiggyBankModel piggybank, List<SavingsGoalModel> goals) {
    final fmt = NumberFormat('#,###', 'en_US');
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        maxChildSize: 0.9,
        minChildSize: 0.4,
        builder: (_, controller) => Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            children: [
              // Drag handle
              Container(
                margin: const EdgeInsets.only(top: 12),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Assign Savings to a Goal',
                      style: GoogleFonts.poppins(
                        fontSize: 20,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF1E293B),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Available: RWF ${fmt.format(piggybank.balance.toInt())}',
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              if (goals.isEmpty)
                Expanded(
                  child: Center(
                    child: Text(
                      'No active goals yet.\nCreate a goal first!',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.inter(
                        fontSize: 15,
                        color: Colors.grey[500],
                      ),
                    ),
                  ),
                )
              else
                Expanded(
                  child: ListView.separated(
                    controller: controller,
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
                    itemCount: goals.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (_, i) {
                      final goal = goals[i];
                      final remaining = (goal.targetAmount - goal.currentAmount)
                          .clamp(0.0, double.infinity);
                      return InkWell(
                        borderRadius: BorderRadius.circular(16),
                        onTap: () {
                          Navigator.pop(ctx);
                          _showContributeDialog(goal);
                        },
                        child: Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF8F9FD),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: Colors.grey.shade200),
                          ),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: AppColors.secondary.withOpacity(0.12),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Icon(Icons.flag,
                                    color: AppColors.secondary, size: 20),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      goal.name,
                                      style: GoogleFonts.poppins(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w600,
                                        color: const Color(0xFF1E293B),
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      'Needs RWF ${fmt.format(remaining.toInt())} more',
                                      style: GoogleFonts.inter(
                                        fontSize: 13,
                                        color: Colors.grey[500],
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(4),
                                      child: LinearProgressIndicator(
                                        value: goal.progressPercentage / 100,
                                        minHeight: 6,
                                        backgroundColor: Colors.grey[200],
                                        valueColor: AlwaysStoppedAnimation(
                                            AppColors.secondary),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 12),
                              Icon(Icons.chevron_right,
                                  color: Colors.grey[400]),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
            ],
          ),
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

// ── Piggybank Hero ────────────────────────────────────────────────────────────

class _PiggyBankHero extends StatelessWidget {
  final PiggyBankModel piggybank;
  final VoidCallback onTap;

  const _PiggyBankHero({required this.piggybank, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final fmt = NumberFormat('#,###', 'en_US');
    final pb = piggybank;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 196,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFFF9A825), Color(0xFFFFB81C), Color(0xFFFFCC55)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFFFFB81C).withOpacity(0.42),
              blurRadius: 22,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: Stack(
            children: [
              // Background decorative circles
              Positioned(
                top: -28,
                right: 158,
                child: Container(
                  width: 88,
                  height: 88,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withOpacity(0.07),
                  ),
                ),
              ),
              Positioned(
                bottom: -36,
                left: 100,
                child: Container(
                  width: 108,
                  height: 108,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withOpacity(0.06),
                  ),
                ),
              ),

              // Piggybank illustration (right side)
              Positioned(
                right: -4,
                top: 0,
                bottom: 0,
                width: 162,
                child: CustomPaint(painter: _PiggyPainter()),
              ),

              // Text content (left side)
              Padding(
                padding: const EdgeInsets.fromLTRB(22, 18, 170, 18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Label row
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(
                            Icons.savings_rounded,
                            size: 14,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Savings Piggybank',
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: Colors.white.withOpacity(0.88),
                          ),
                        ),
                      ],
                    ),

                    // Balance
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'RWF',
                          style: GoogleFonts.inter(
                              fontSize: 11, color: Colors.white70),
                        ),
                        Text(
                          fmt.format(pb.balance.toInt()),
                          style: GoogleFonts.poppins(
                            fontSize: 27,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                            height: 1.1,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),

                    // Footer: stat + CTA button
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        RichText(
                          text: TextSpan(
                            style: GoogleFonts.inter(
                                fontSize: 12,
                                color: Colors.white.withOpacity(0.75)),
                            children: [
                              TextSpan(
                                text:
                                    'RWF ${fmt.format(pb.totalContributed.toInt())}',
                                style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                    color: Colors.white),
                              ),
                              const TextSpan(text: ' saved'),
                            ],
                          ),
                        ),
                        const SizedBox(height: 9),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 7),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.10),
                                blurRadius: 8,
                                offset: const Offset(0, 3),
                              ),
                            ],
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.add,
                                  color: Color(0xFFF0820F), size: 13),
                              const SizedBox(width: 5),
                              Text(
                                'Assign to Goal',
                                style: GoogleFonts.inter(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: const Color(0xFFF0820F),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Piggybank CustomPainter ───────────────────────────────────────────────────

class _PiggyPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    const pigRose = Color(0xFFFFD4DC);
    const pigPink = Color(0xFFFFBBBB);
    const pigDark = Color(0xFFFF9999);
    const coinGold = Color(0xFFFFB81C);
    const coinBorderColor = Color(0xFFF9A825);

    final bodyP = Paint()
      ..color = pigRose
      ..style = PaintingStyle.fill;
    final pinkP = Paint()
      ..color = pigPink
      ..style = PaintingStyle.fill;
    final darkP = Paint()
      ..color = pigDark
      ..style = PaintingStyle.fill;

    // Positioning relative to canvas
    final bx = size.width * 0.38; // body center x ≈ 61
    final by = size.height * 0.52; // body center y ≈ 102
    final bw = size.width * 0.58; // body width ≈ 93
    final bh = size.height * 0.38; // body height ≈ 74
    final hr = size.width * 0.155; // head radius ≈ 25
    final hx = bx + bw * 0.44; // head center x ≈ 102
    final hy = by - bh * 0.09; // head center y ≈ 95

    // ── Tail ───────────────────────────────────────────────────────────────
    canvas.drawPath(
      Path()
        ..moveTo(bx - bw * 0.44, by - 2)
        ..cubicTo(bx - bw * 0.58, by - 21, bx - bw * 0.65, by - 4,
            bx - bw * 0.56, by + 8),
      Paint()
        ..color = pigPink
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3.5
        ..strokeCap = StrokeCap.round,
    );

    // ── Legs ───────────────────────────────────────────────────────────────
    final legRRect = RRect.fromRectAndRadius(
        const Rect.fromLTWH(0, 0, 12, 16), const Radius.circular(6));
    for (final lx in [bx - 28.0, bx - 11.0, bx + 6.0, bx + 23.0]) {
      canvas.drawRRect(legRRect.shift(Offset(lx - 6, by + bh * 0.49)), pinkP);
    }

    // ── Body shadow ────────────────────────────────────────────────────────
    canvas.drawOval(
      Rect.fromCenter(center: Offset(bx, by + 7), width: bw, height: bh * 0.55),
      Paint()
        ..color = Colors.black.withOpacity(0.07)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 9),
    );

    // ── Body ───────────────────────────────────────────────────────────────
    canvas.drawOval(
        Rect.fromCenter(center: Offset(bx, by), width: bw, height: bh), bodyP);
    // Body sheen
    canvas.drawOval(
      Rect.fromCenter(center: Offset(bx - 16, by - 14), width: 28, height: 18),
      Paint()
        ..color = Colors.white.withOpacity(0.28)
        ..style = PaintingStyle.fill,
    );

    // ── Coin slot ──────────────────────────────────────────────────────────
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(
            center: Offset(bx - 3, by - bh * 0.49), width: 22, height: 4),
        const Radius.circular(2),
      ),
      Paint()
        ..color = const Color(0xFFEE7070).withOpacity(0.60)
        ..style = PaintingStyle.fill,
    );

    // ── Coin (being dropped in) ─────────────────────────────────────────────
    final coinX = bx - 3;
    final coinY = by - bh * 0.49 - 12;
    canvas.drawCircle(
        Offset(coinX, coinY),
        8.5,
        Paint()
          ..color = coinGold
          ..style = PaintingStyle.fill);
    // Coin shine
    canvas.drawCircle(
      Offset(coinX - 3, coinY - 3),
      2.8,
      Paint()
        ..color = Colors.white.withOpacity(0.38)
        ..style = PaintingStyle.fill,
    );
    // Coin border
    canvas.drawCircle(
      Offset(coinX, coinY),
      8.5,
      Paint()
        ..color = coinBorderColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );
    // RWF symbol on coin
    final textPainter = TextPainter(
      text: TextSpan(
        text: '₣',
        style: TextStyle(
          color: const Color(0xFFF9A825).withOpacity(0.85),
          fontSize: 9,
          fontWeight: FontWeight.bold,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    textPainter.paint(canvas,
        Offset(coinX - textPainter.width / 2, coinY - textPainter.height / 2));

    // ── Head ───────────────────────────────────────────────────────────────
    canvas.drawCircle(Offset(hx, hy), hr, bodyP);
    // Head sheen
    canvas.drawOval(
      Rect.fromCenter(center: Offset(hx - 7, hy - 10), width: 14, height: 10),
      Paint()
        ..color = Colors.white.withOpacity(0.20)
        ..style = PaintingStyle.fill,
    );

    // ── Ear ────────────────────────────────────────────────────────────────
    canvas.drawOval(
        Rect.fromCenter(
            center: Offset(hx + 3, hy - hr * 0.83), width: 16, height: 20),
        bodyP);
    canvas.drawOval(
        Rect.fromCenter(
            center: Offset(hx + 3, hy - hr * 0.79), width: 9, height: 12),
        pinkP);

    // ── Snout ──────────────────────────────────────────────────────────────
    canvas.drawOval(
      Rect.fromCenter(
          center: Offset(hx + hr * 0.81, hy + 4), width: 18, height: 13),
      pinkP,
    );
    canvas.drawCircle(Offset(hx + hr * 0.66, hy + 5.5), 2.2, darkP);
    canvas.drawCircle(Offset(hx + hr * 0.96, hy + 5.5), 2.2, darkP);

    // ── Eye ────────────────────────────────────────────────────────────────
    canvas.drawCircle(
        Offset(hx + 8, hy - 9),
        3.0,
        Paint()
          ..color = const Color(0xFF2D1515)
          ..style = PaintingStyle.fill);
    canvas.drawCircle(
        Offset(hx + 9, hy - 10),
        1.2,
        Paint()
          ..color = Colors.white
          ..style = PaintingStyle.fill);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _PiggyStatBox extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;

  const _PiggyStatBox({
    required this.label,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.15),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(icon, size: 16, color: Colors.white70),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label,
                      style: GoogleFonts.inter(
                          fontSize: 11, color: Colors.white60)),
                  Text(value,
                      style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Colors.white),
                      overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
