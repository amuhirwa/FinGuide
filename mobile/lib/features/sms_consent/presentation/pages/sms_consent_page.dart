/*
 * SMS Consent Page
 * ================
 * First-time consent form explaining what data FinGuide reads and why.
 * Shown once after login/register, before the dashboard.
 */

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/app_router.dart';
import '../../../../core/theme/app_theme.dart';
import '../bloc/sms_consent_bloc.dart';

class SmsConsentPage extends StatelessWidget {
  const SmsConsentPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocListener<SmsConsentBloc, SmsConsentState>(
      listener: (context, state) {
        if (state is SmsConsentComplete) {
          _showImportResult(context, state.transactionsImported);
        } else if (state is SmsConsentSkipped) {
          context.go(Routes.dashboard);
        } else if (state is SmsConsentPermissionDenied) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'SMS permission denied. You can enable it later in Settings.',
              ),
            ),
          );
          // Still navigate forward — the app works without SMS
          Future.delayed(const Duration(seconds: 2), () {
            if (context.mounted) context.go(Routes.dashboard);
          });
        } else if (state is SmsConsentError) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Import error: ${state.message}')),
          );
          Future.delayed(const Duration(seconds: 2), () {
            if (context.mounted) context.go(Routes.dashboard);
          });
        }
      },
      child: Scaffold(
        backgroundColor: AppColors.background,
        body: SafeArea(
          child: BlocBuilder<SmsConsentBloc, SmsConsentState>(
            builder: (context, state) {
              if (state is SmsConsentImporting) {
                return _ImportingView();
              }
              if (state is SmsConsentRequestingPermission) {
                return _ImportingView(label: 'Requesting permission…');
              }
              return _ConsentFormView();
            },
          ),
        ),
      ),
    );
  }

  void _showImportResult(BuildContext context, int count) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        icon: Icon(Icons.check_circle_rounded,
            color: AppColors.success, size: 48),
        title: const Text('Import Complete'),
        content: Text(
          count > 0
              ? 'We found and imported $count MoMo transactions from your messages. '
                  'FinGuide will now listen for new transactions in real time.'
              : 'No MoMo messages were found on this device yet. '
                  'FinGuide will automatically capture new MoMo transactions as they arrive.',
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              context.go(Routes.dashboard);
            },
            child: const Text('Continue'),
          ),
        ],
      ),
    );
  }
}

// ─── Consent Form ────────────────────────────────────────────────────

class _ConsentFormView extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: AppSpacing.screenPadding,
      child: Column(
        children: [
          const SizedBox(height: AppSpacing.xl),

          // Header icon
          Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF00A3AD), Color(0xFF00838F)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(32),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary.withOpacity(0.25),
                  blurRadius: 24,
                  offset: const Offset(0, 12),
                ),
              ],
            ),
            child:
                const Icon(Icons.sms_outlined, size: 48, color: Colors.white),
          ),

          const SizedBox(height: AppSpacing.xl),

          Text(
            'Read Your MoMo Messages?',
            style: AppTypography.headlineMedium.copyWith(
              color: AppColors.textPrimary,
            ),
            textAlign: TextAlign.center,
          ),

          const SizedBox(height: AppSpacing.sm),

          Text(
            'To give you accurate forecasts, FinGuide needs to read your '
            'mobile money SMS messages.',
            style: AppTypography.bodyLarge.copyWith(
              color: AppColors.textSecondary,
              height: 1.5,
            ),
            textAlign: TextAlign.center,
          ),

          const SizedBox(height: AppSpacing.xl),

          // Data explanation cards
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                children: const [
                  _DataCard(
                    icon: Icons.visibility_outlined,
                    title: 'What we read',
                    description:
                        'Only MoMo transaction SMS (payments, transfers, top-ups). '
                        'We ignore all other messages.',
                  ),
                  SizedBox(height: AppSpacing.md),
                  _DataCard(
                    icon: Icons.analytics_outlined,
                    title: 'How we use it',
                    description:
                        'Transactions are parsed to track your income & expenses, '
                        'power AI forecasts, and calculate your Safe-to-Spend budget.',
                  ),
                  SizedBox(height: AppSpacing.md),
                  _DataCard(
                    icon: Icons.lock_outline,
                    title: 'Your data stays private',
                    description:
                        'Messages are processed on your device first. Only structured '
                        'transaction data (amount, category, date) is sent to your '
                        'secure FinGuide account — never the full SMS text.',
                  ),
                  SizedBox(height: AppSpacing.md),
                  _DataCard(
                    icon: Icons.sync_outlined,
                    title: 'Real-time updates',
                    description:
                        'After the initial import, FinGuide will automatically '
                        'capture new MoMo messages as they arrive so your data '
                        'is always up to date.',
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: AppSpacing.lg),

          // Allow button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                context.read<SmsConsentBloc>().add(SmsConsentAccepted());
              },
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 18),
              ),
              child: const Text('Allow SMS Access'),
            ),
          ),

          const SizedBox(height: AppSpacing.sm),

          // Decline button
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: () {
                context.read<SmsConsentBloc>().add(SmsConsentDeclined());
              },
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 18),
                side: BorderSide(color: AppColors.border),
              ),
              child: Text(
                'Not Now',
                style: TextStyle(color: AppColors.textSecondary),
              ),
            ),
          ),

          const SizedBox(height: AppSpacing.sm),

          Text(
            'You can change this later in Settings.',
            style: AppTypography.bodySmall.copyWith(
              color: AppColors.textTertiary,
            ),
          ),

          const SizedBox(height: AppSpacing.md),
        ],
      ),
    );
  }
}

// ─── Importing view ──────────────────────────────────────────────────

class _ImportingView extends StatelessWidget {
  final String label;

  const _ImportingView({this.label = 'Reading your MoMo messages…'});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: AppSpacing.screenPadding,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              width: 64,
              height: 64,
              child: CircularProgressIndicator(
                strokeWidth: 3,
                valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
              ),
            ),
            const SizedBox(height: AppSpacing.xl),
            Text(
              label,
              style: AppTypography.titleMedium.copyWith(
                color: AppColors.textPrimary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'This may take a moment if you have many messages.',
              style: AppTypography.bodyMedium.copyWith(
                color: AppColors.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Reusable data explanation card ──────────────────────────────────

class _DataCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;

  const _DataCard({
    required this.icon,
    required this.title,
    required this.description,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.borderLight),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: AppColors.primarySurface,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: AppColors.primary, size: 22),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: AppTypography.titleSmall.copyWith(
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: AppTypography.bodySmall.copyWith(
                    color: AppColors.textSecondary,
                    height: 1.5,
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
