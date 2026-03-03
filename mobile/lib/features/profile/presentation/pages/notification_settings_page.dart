/*
 * Notification Settings Page
 * ==========================
 * Lets users enable/disable different notification categories.
 * Preferences are persisted in SharedPreferences.
 */

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../core/theme/app_theme.dart';

class NotificationSettingsPage extends StatefulWidget {
  const NotificationSettingsPage({super.key});

  @override
  State<NotificationSettingsPage> createState() =>
      _NotificationSettingsPageState();
}

class _NotificationSettingsPageState extends State<NotificationSettingsPage> {
  // Pref keys
  static const _kTransactionAlerts = 'notif_transaction_alerts';
  static const _kWeeklySummary = 'notif_weekly_summary';
  static const _kSavingsNudges = 'notif_savings_nudges';
  static const _kBudgetWarnings = 'notif_budget_warnings';
  static const _kGoalReminders = 'notif_goal_reminders';

  bool _transactionAlerts = true;
  bool _weeklySummary = true;
  bool _savingsNudges = true;
  bool _budgetWarnings = true;
  bool _goalReminders = true;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadPreferences();
  }

  Future<void> _loadPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _transactionAlerts = prefs.getBool(_kTransactionAlerts) ?? true;
      _weeklySummary = prefs.getBool(_kWeeklySummary) ?? true;
      _savingsNudges = prefs.getBool(_kSavingsNudges) ?? true;
      _budgetWarnings = prefs.getBool(_kBudgetWarnings) ?? true;
      _goalReminders = prefs.getBool(_kGoalReminders) ?? true;
      _loading = false;
    });
  }

  Future<void> _set(String key, bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(key, value);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          color: AppColors.textPrimary,
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Notifications',
          style: AppTypography.titleLarge.copyWith(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(AppSpacing.lg),
              children: [
                _sectionHeader(
                  icon: Icons.swap_horiz_rounded,
                  title: 'Transactions',
                ),
                const SizedBox(height: AppSpacing.sm),
                _NotifTile(
                  icon: Icons.receipt_long_outlined,
                  title: 'Transaction Alerts',
                  subtitle: 'Get notified when income or expense is detected',
                  value: _transactionAlerts,
                  onChanged: (v) {
                    setState(() => _transactionAlerts = v);
                    _set(_kTransactionAlerts, v);
                  },
                ),
                const SizedBox(height: AppSpacing.lg),

                _sectionHeader(
                  icon: Icons.insights_rounded,
                  title: 'Insights & Reports',
                ),
                const SizedBox(height: AppSpacing.sm),
                _NotifTile(
                  icon: Icons.bar_chart_rounded,
                  title: 'Weekly Summary',
                  subtitle: 'A recap of your financial activity every Sunday',
                  value: _weeklySummary,
                  onChanged: (v) {
                    setState(() => _weeklySummary = v);
                    _set(_kWeeklySummary, v);
                  },
                ),
                _NotifTile(
                  icon: Icons.savings_outlined,
                  title: 'Savings Nudges',
                  subtitle: 'Tips and reminders to help you save more',
                  value: _savingsNudges,
                  onChanged: (v) {
                    setState(() => _savingsNudges = v);
                    _set(_kSavingsNudges, v);
                  },
                ),
                _NotifTile(
                  icon: Icons.warning_amber_rounded,
                  title: 'Budget Warnings',
                  subtitle: 'Alerts when spending approaches your limit',
                  value: _budgetWarnings,
                  onChanged: (v) {
                    setState(() => _budgetWarnings = v);
                    _set(_kBudgetWarnings, v);
                  },
                ),
                const SizedBox(height: AppSpacing.lg),

                _sectionHeader(
                  icon: Icons.flag_rounded,
                  title: 'Goals',
                ),
                const SizedBox(height: AppSpacing.sm),
                _NotifTile(
                  icon: Icons.emoji_events_outlined,
                  title: 'Goal Reminders',
                  subtitle: 'Updates on your savings goal progress',
                  value: _goalReminders,
                  onChanged: (v) {
                    setState(() => _goalReminders = v);
                    _set(_kGoalReminders, v);
                  },
                ),
                const SizedBox(height: AppSpacing.xl),

                // Info note
                Container(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(AppRadius.md),
                    border:
                        Border.all(color: AppColors.primary.withOpacity(0.2)),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.info_outline,
                          color: AppColors.primary, size: 18),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: Text(
                          'You can also manage notifications in your device Settings > Apps > FinGuide.',
                          style: AppTypography.bodySmall
                              .copyWith(color: AppColors.primary),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
              ],
            ),
    );
  }

  Widget _sectionHeader({required IconData icon, required String title}) {
    return Row(
      children: [
        Icon(icon, size: 18, color: AppColors.primary),
        const SizedBox(width: AppSpacing.sm),
        Text(
          title,
          style: AppTypography.titleSmall.copyWith(
            color: AppColors.primary,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

class _NotifTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _NotifTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.md),
        boxShadow: AppShadows.small,
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md, vertical: AppSpacing.xs),
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: AppColors.primary.withOpacity(0.1),
            borderRadius: BorderRadius.circular(AppRadius.sm),
          ),
          child: Icon(icon, color: AppColors.primary, size: 20),
        ),
        title: Text(title, style: AppTypography.bodyLarge),
        subtitle: Text(
          subtitle,
          style:
              AppTypography.bodySmall.copyWith(color: AppColors.textSecondary),
        ),
        trailing: Switch(
          value: value,
          onChanged: onChanged,
          activeColor: AppColors.primary,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
      ),
    );
  }
}
