/*
 * Profile & Settings Page
 * =======================
 * Comprehensive profile management with settings and preferences
 */

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/app_router.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../auth/presentation/bloc/auth_bloc.dart';

class ProfilePage extends StatelessWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AuthBloc, AuthState>(
      builder: (context, state) {
        if (state is! AuthAuthenticated) {
          return const Center(child: CircularProgressIndicator());
        }

        final user = state.user;

        return SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Text(
                  'Profile & Settings',
                  style: AppTypography.headlineMedium.copyWith(
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: AppSpacing.xl),

                // User Profile Card
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  decoration: BoxDecoration(
                    gradient: AppColors.primaryGradient,
                    borderRadius: BorderRadius.circular(AppRadius.lg),
                    boxShadow: AppShadows.medium,
                  ),
                  child: Row(
                    children: [
                      // Avatar
                      Container(
                        width: 72,
                        height: 72,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: Colors.white,
                            width: 3,
                          ),
                        ),
                        child: Center(
                          child: Text(
                            user.fullName.isNotEmpty
                                ? user.fullName[0].toUpperCase()
                                : 'U',
                            style: AppTypography.displaySmall.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.md),
                      // User Info
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              user.fullName,
                              style: AppTypography.titleLarge.copyWith(
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              user.phoneNumber,
                              style: AppTypography.bodyMedium.copyWith(
                                color: Colors.white.withOpacity(0.9),
                              ),
                            ),
                          ],
                        ),
                      ),
                      // Edit button
                      IconButton(
                        onPressed: () {
                          // TODO: Navigate to edit profile
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Edit profile coming soon!'),
                            ),
                          );
                        },
                        icon: const Icon(Icons.edit, color: Colors.white),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.xl),

                // Financial Profile Section
                _SectionHeader(
                  icon: Icons.account_balance_wallet,
                  title: 'Financial Profile',
                ),
                const SizedBox(height: AppSpacing.md),
                _SettingsTile(
                  icon: Icons.category,
                  title: 'Ubudehe Category',
                  subtitle: user.ubudeheCategoryDisplay,
                  onTap: () {
                    // TODO: Update Ubudehe category
                  },
                ),
                _SettingsTile(
                  icon: Icons.calendar_today,
                  title: 'Income Frequency',
                  subtitle: user.incomeFrequencyDisplay,
                  onTap: () {
                    // TODO: Update income frequency
                  },
                ),
                const SizedBox(height: AppSpacing.xl),

                // App Settings Section
                _SectionHeader(
                  icon: Icons.settings,
                  title: 'App Settings',
                ),
                const SizedBox(height: AppSpacing.md),
                _SettingsTile(
                  icon: Icons.dark_mode,
                  title: 'Dark Mode',
                  subtitle: 'Coming soon',
                  trailing: Switch(
                    value: false,
                    onChanged: null, // TODO: Implement dark mode
                    activeColor: AppColors.primary,
                  ),
                  onTap: null,
                ),
                _SettingsTile(
                  icon: Icons.notifications,
                  title: 'Notifications',
                  subtitle: 'Manage notification preferences',
                  onTap: () {
                    // TODO: Navigate to notifications settings
                  },
                ),
                _SettingsTile(
                  icon: Icons.language,
                  title: 'Language',
                  subtitle: 'English (US)',
                  onTap: () {
                    // TODO: Navigate to language settings
                  },
                ),
                _SettingsTile(
                  icon: Icons.attach_money,
                  title: 'Currency',
                  subtitle: 'RWF (Rwandan Franc)',
                  onTap: () {
                    // TODO: Navigate to currency settings
                  },
                ),
                const SizedBox(height: AppSpacing.xl),

                // Data & Privacy Section
                _SectionHeader(
                  icon: Icons.security,
                  title: 'Data & Privacy',
                ),
                const SizedBox(height: AppSpacing.md),
                _SettingsTile(
                  icon: Icons.sms,
                  title: 'SMS Permissions',
                  subtitle: 'Manage MoMo SMS access',
                  onTap: () {
                    context.push(Routes.smsConsent);
                  },
                ),
                _SettingsTile(
                  icon: Icons.download,
                  title: 'Export Data',
                  subtitle: 'Download your financial reports',
                  onTap: () {
                    context.push(Routes.reports);
                  },
                ),
                _SettingsTile(
                  icon: Icons.delete_outline,
                  title: 'Clear Local Data',
                  subtitle: 'Remove cached data',
                  onTap: () => _showClearDataDialog(context),
                  textColor: AppColors.warning,
                ),
                const SizedBox(height: AppSpacing.xl),

                // About Section
                _SectionHeader(
                  icon: Icons.info_outline,
                  title: 'About',
                ),
                const SizedBox(height: AppSpacing.md),
                _SettingsTile(
                  icon: Icons.info,
                  title: 'App Version',
                  subtitle: '1.0.0',
                  onTap: null,
                ),
                _SettingsTile(
                  icon: Icons.help_outline,
                  title: 'Help & Support',
                  subtitle: 'Get help or send feedback',
                  onTap: () {
                    // TODO: Navigate to help/support
                  },
                ),
                _SettingsTile(
                  icon: Icons.privacy_tip_outlined,
                  title: 'Privacy Policy',
                  onTap: () {
                    // TODO: Navigate to privacy policy
                  },
                ),
                _SettingsTile(
                  icon: Icons.description_outlined,
                  title: 'Terms of Service',
                  onTap: () {
                    // TODO: Navigate to terms
                  },
                ),
                const SizedBox(height: AppSpacing.xl),

                // Logout Button
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () => _showLogoutDialog(context),
                    icon: const Icon(Icons.logout),
                    label: const Text('Logout'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.error,
                      side: const BorderSide(color: AppColors.error),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppRadius.md),
                      ),
                      padding: const EdgeInsets.symmetric(
                        vertical: AppSpacing.md,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.xl),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showLogoutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(
          'Logout',
          style: AppTypography.titleLarge,
        ),
        content: Text(
          'Are you sure you want to logout?',
          style: AppTypography.bodyLarge,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(
              'Cancel',
              style: AppTypography.labelLarge.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(dialogContext);
              context.read<AuthBloc>().add(AuthLogoutRequested());
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: Colors.white,
            ),
            child: Text('Logout', style: AppTypography.labelLarge),
          ),
        ],
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg),
        ),
      ),
    );
  }

  void _showClearDataDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(
          'Clear Local Data',
          style: AppTypography.titleLarge,
        ),
        content: Text(
          'This will remove all cached data from your device. Your data on the server will remain intact.',
          style: AppTypography.bodyLarge,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(
              'Cancel',
              style: AppTypography.labelLarge.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(dialogContext);
              // TODO: Implement clear cache
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Local data cleared'),
                  backgroundColor: AppColors.success,
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.warning,
              foregroundColor: Colors.white,
            ),
            child: Text('Clear', style: AppTypography.labelLarge),
          ),
        ],
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg),
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final IconData icon;
  final String title;

  const _SectionHeader({
    required this.icon,
    required this.title,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 20, color: AppColors.primary),
        const SizedBox(width: AppSpacing.sm),
        Text(
          title,
          style: AppTypography.titleMedium.copyWith(
            color: AppColors.primary,
          ),
        ),
      ],
    );
  }
}

class _SettingsTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback? onTap;
  final Widget? trailing;
  final Color? textColor;

  const _SettingsTile({
    required this.icon,
    required this.title,
    this.subtitle,
    this.onTap,
    this.trailing,
    this.textColor,
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
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: (textColor ?? AppColors.primary).withOpacity(0.1),
            borderRadius: BorderRadius.circular(AppRadius.sm),
          ),
          child: Icon(
            icon,
            color: textColor ?? AppColors.primary,
            size: 20,
          ),
        ),
        title: Text(
          title,
          style: AppTypography.bodyLarge.copyWith(
            color: textColor ?? AppColors.textPrimary,
          ),
        ),
        subtitle: subtitle != null
            ? Text(
                subtitle!,
                style: AppTypography.bodySmall.copyWith(
                  color: AppColors.textSecondary,
                ),
              )
            : null,
        trailing: trailing ??
            (onTap != null
                ? const Icon(
                    Icons.chevron_right,
                    color: AppColors.textTertiary,
                  )
                : null),
        onTap: onTap,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
      ),
    );
  }
}
