/*
 * Splash Page
 * ===========
 * Minimalist splash screen with logo and loading indicator
 */

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/app_router.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../auth/presentation/bloc/auth_bloc.dart';

/// Splash page widget
class SplashPage extends StatefulWidget {
  const SplashPage({super.key});

  @override
  State<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends State<SplashPage>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;

  /// True once the 2s splash delay has passed. Until then navigation is
  /// deferred; afterwards any auth state change routes immediately.
  bool _splashDelayElapsed = false;
  bool _navigated = false;

  @override
  void initState() {
    super.initState();

    // Read the *current* state after the splash delay rather than relying on
    // BlocListener alone. AuthCheckRequested is dispatched when the bloc is
    // created in main(), so it can settle before this page ever subscribes -
    // a race that release builds lose more often than debug ones, because AOT
    // startup reaches the first frame sooner. When that happened the listener
    // never fired and the app sat on the splash screen forever.
    Future.delayed(const Duration(seconds: 2), () {
      if (!mounted) return;
      _splashDelayElapsed = true;
      _navigateBasedOnState(context.read<AuthBloc>().state);
    });

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.6, curve: Curves.easeOut),
      ),
    );

    _scaleAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.6, curve: Curves.easeOutBack),
      ),
    );

    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _navigateBasedOnState(AuthState state) {
    if (_navigated) return;

    // Only latch once a state actually routes somewhere - transient states
    // (AuthInitial, AuthLoading) must not consume the one navigation.
    final String? target = switch (state) {
      AuthShowOnboarding() => Routes.onboarding,
      AuthShowSmsConsent() => Routes.smsConsent,
      AuthAuthenticated() => Routes.dashboard,
      AuthUnauthenticated() => Routes.login,
      _ => null,
    };
    if (target == null) return;

    _navigated = true;
    context.go(target);
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<AuthBloc, AuthState>(
      listener: (context, state) {
        // The splash delay is owned by the timer in initState; here we only
        // handle states that arrive after it has already elapsed.
        if (_splashDelayElapsed) {
          _navigateBasedOnState(state);
        }
      },
      child: Scaffold(
        backgroundColor: AppColors.background,
        body: Center(
          child: AnimatedBuilder(
            animation: _controller,
            builder: (context, child) {
              return Opacity(
                opacity: _fadeAnimation.value,
                child: Transform.scale(
                  scale: _scaleAnimation.value,
                  child: child,
                ),
              );
            },
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Logo
                Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(32),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primary.withOpacity(0.2),
                        blurRadius: 32,
                        offset: const Offset(0, 12),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(32),
                    child: Image.asset(
                      'assets/images/logo.png',
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return Center(
                          child: Text(
                            'F',
                            style: TextStyle(
                              fontFamily: 'Outfit',
                              fontSize: 64,
                              fontWeight: FontWeight.w700,
                              color: AppColors.primary,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),

                const SizedBox(height: AppSpacing.xl),

                // App Name
                Text(
                  'FinGuide',
                  style: AppTypography.displaySmall.copyWith(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w700,
                  ),
                ),

                const SizedBox(height: AppSpacing.sm),

                // Tagline
                Text(
                  'Your AI Financial Advisor',
                  style: AppTypography.bodyLarge.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),

                const SizedBox(height: AppSpacing.xxl),

                // Loading Indicator
                SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      AppColors.primary.withOpacity(0.7),
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
}
