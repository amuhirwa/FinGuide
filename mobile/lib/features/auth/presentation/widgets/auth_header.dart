/*
 * Auth Header Widget
 * ==================
 * Reusable header component for auth screens
 */

import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';

/// Header widget for authentication screens
class AuthHeader extends StatelessWidget {
  final String title;
  final String subtitle;

  const AuthHeader({super.key, required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Logo
        Container(
          width: 64,
          height: 64,
          decoration: BoxDecoration(
            gradient: AppColors.wealthGradient,
            borderRadius: BorderRadius.circular(AppRadius.lg),
            boxShadow: AppShadows.medium,
          ),
          child: const Center(
            child: Text(
              'F',
              style: TextStyle(
                fontFamily: 'Outfit',
                fontSize: 32,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
          ),
        ),

        const SizedBox(height: AppSpacing.lg),

        // Title
        Text(
          title,
          style: AppTypography.headlineLarge.copyWith(
            color: AppColors.textPrimary,
          ),
        ),

        const SizedBox(height: AppSpacing.xs),

        // Subtitle
        Text(
          subtitle,
          style: AppTypography.bodyLarge.copyWith(
            color: AppColors.textSecondary,
          ),
        ),
      ],
    );
  }
}
