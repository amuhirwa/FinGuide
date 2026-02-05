/*
 * Onboarding Page
 * ===============
 * 3-page swipeable introduction explaining key features
 */

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:smooth_page_indicator/smooth_page_indicator.dart';

import '../../../../core/di/injection.dart';
import '../../../../core/router/app_router.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../auth/data/datasources/auth_local_datasource.dart';

/// Onboarding page widget
class OnboardingPage extends StatefulWidget {
  const OnboardingPage({super.key});

  @override
  State<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends State<OnboardingPage> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  final List<OnboardingItem> _items = [
    OnboardingItem(
      icon: Icons.sms_outlined,
      title: 'Smart SMS Parsing',
      description:
          'We automatically read your mobile money messages to track income and expenses—no manual entry needed.',
      gradient: const LinearGradient(
        colors: [Color(0xFF00A3AD), Color(0xFF00838F)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
    ),
    OnboardingItem(
      icon: Icons.auto_graph_rounded,
      title: 'AI-Powered Forecasting',
      description:
          'Our BiLSTM model predicts your cash flow, helping you know exactly when money is coming and going.',
      gradient: const LinearGradient(
        colors: [Color(0xFF6366F1), Color(0xFF4F46E5)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
    ),
    OnboardingItem(
      icon: Icons.savings_outlined,
      title: 'Ejo Heza & Savings Nudges',
      description:
          'Get personalized recommendations to save, including automatic nudges for Ejo Heza and other investments.',
      gradient: const LinearGradient(
        colors: [Color(0xFFFFB81C), Color(0xFFF59E0B)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
    ),
  ];

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _onPageChanged(int page) {
    setState(() {
      _currentPage = page;
    });
  }

  Future<void> _completeOnboarding() async {
    await getIt<AuthLocalDataSource>().setOnboardingSeen();
    if (mounted) {
      context.go(Routes.login);
    }
  }

  void _nextPage() {
    if (_currentPage < _items.length - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOut,
      );
    } else {
      _completeOnboarding();
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            // Skip Button
            Align(
              alignment: Alignment.topRight,
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: TextButton(
                  onPressed: _completeOnboarding,
                  child: Text(
                    'Skip',
                    style: AppTypography.labelLarge.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
              ),
            ),

            // Page View
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                onPageChanged: _onPageChanged,
                itemCount: _items.length,
                itemBuilder: (context, index) {
                  return _OnboardingPageItem(item: _items[index]);
                },
              ),
            ),

            // Bottom Section
            Padding(
              padding: AppSpacing.screenPadding,
              child: Column(
                children: [
                  // Page Indicator
                  SmoothPageIndicator(
                    controller: _pageController,
                    count: _items.length,
                    effect: ExpandingDotsEffect(
                      dotWidth: 8,
                      dotHeight: 8,
                      spacing: 6,
                      activeDotColor: AppColors.primary,
                      dotColor: AppColors.border,
                    ),
                  ),

                  const SizedBox(height: AppSpacing.xl),

                  // Next/Get Started Button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _nextPage,
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 18),
                      ),
                      child: Text(
                        _currentPage == _items.length - 1
                            ? 'Get Started'
                            : 'Next',
                      ),
                    ),
                  ),

                  const SizedBox(height: AppSpacing.md),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Onboarding item data class
class OnboardingItem {
  final IconData icon;
  final String title;
  final String description;
  final Gradient gradient;

  const OnboardingItem({
    required this.icon,
    required this.title,
    required this.description,
    required this.gradient,
  });
}

/// Individual onboarding page item widget
class _OnboardingPageItem extends StatelessWidget {
  final OnboardingItem item;

  const _OnboardingPageItem({required this.item});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Icon Container
          Container(
            width: 140,
            height: 140,
            decoration: BoxDecoration(
              gradient: item.gradient,
              borderRadius: BorderRadius.circular(40),
              boxShadow: [
                BoxShadow(
                  color: (item.gradient.colors.first).withOpacity(0.3),
                  blurRadius: 32,
                  offset: const Offset(0, 16),
                ),
              ],
            ),
            child: Icon(item.icon, size: 64, color: Colors.white),
          ),

          const SizedBox(height: AppSpacing.xxl),

          // Title
          Text(
            item.title,
            style: AppTypography.headlineMedium.copyWith(
              color: AppColors.textPrimary,
            ),
            textAlign: TextAlign.center,
          ),

          const SizedBox(height: AppSpacing.md),

          // Description
          Text(
            item.description,
            style: AppTypography.bodyLarge.copyWith(
              color: AppColors.textSecondary,
              height: 1.6,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
