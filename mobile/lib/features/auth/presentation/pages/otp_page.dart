/*
 * OTP Verification Page
 * =====================
 * Waits for the device to auto-read the Twilio SMS OTP.
 *
 * • Starts a telephony SMS listener on mount – no keyboard, no manual entry.
 * • Parses "Your FinGuide OTP is XXXXXX" from the body of the incoming message.
 * • Auto-dispatches AuthOtpAutoDetected when the code is found.
 * • Blocks the user if the SMS is not received within 5 minutes (meaning the
 *   phone number they entered is likely not the SIM in this device).
 * • Provides a "Resend OTP" button after 30 seconds.
 */

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:telephony/telephony.dart';

import '../../../../core/router/app_router.dart';
import '../../../../core/theme/app_theme.dart';
import '../bloc/auth_bloc.dart';

/// How long (in seconds) to wait before allowing resend
const int _kResendCooldownSeconds = 30;

/// Total OTP validity window in seconds (must match backend OTP_EXPIRE_MINUTES * 60)
const int _kOtpWindowSeconds = 5 * 60;

/// Regex to extract the OTP from the Twilio message body
final RegExp _otpPattern = RegExp(r'Your FinGuide OTP is (\d{6})');

class OtpPage extends StatefulWidget {
  /// Phone number the OTP was sent to – shown in the UI for confirmation
  final String phoneNumber;

  const OtpPage({super.key, required this.phoneNumber});

  @override
  State<OtpPage> createState() => _OtpPageState();
}

class _OtpPageState extends State<OtpPage> with SingleTickerProviderStateMixin {
  final Telephony _telephony = Telephony.instance;

  // Displayed OTP digits (empty = not yet received)
  String _detectedCode = '';

  // Countdown timer
  late int _remainingSeconds;
  late int _resendCooldown;
  Timer? _countdownTimer;

  // Animation for the waiting pulsing ring
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  bool _timedOut = false;

  @override
  void initState() {
    super.initState();
    _remainingSeconds = _kOtpWindowSeconds;
    _resendCooldown = _kResendCooldownSeconds;

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 0.85, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _startCountdown();
    _startSmsListener();
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    _pulseController.dispose();
    // Stop listening when page is gone
    _telephony.listenIncomingSms(
      onNewMessage: (_) {},
      listenInBackground: false,
    );
    super.dispose();
  }

  // ── SMS Listener ─────────────────────────────────────────────────────────

  void _startSmsListener() {
    _telephony.listenIncomingSms(
      onNewMessage: _onSmsReceived,
      listenInBackground: false,
    );
  }

  void _onSmsReceived(SmsMessage message) {
    final body = message.body ?? '';
    final match = _otpPattern.firstMatch(body);
    if (match == null) return; // Not our message

    final code = match.group(1)!;

    if (!mounted) return;
    setState(() => _detectedCode = code);

    // Give the user a brief moment to see the filled boxes before dispatching
    Future.delayed(const Duration(milliseconds: 500), () {
      if (!mounted) return;
      context.read<AuthBloc>().add(AuthOtpAutoDetected(otpCode: code));
    });
  }

  // ── Countdown Timer ───────────────────────────────────────────────────────

  void _startCountdown() {
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      setState(() {
        if (_remainingSeconds > 0) {
          _remainingSeconds--;
          if (_resendCooldown > 0) _resendCooldown--;
        } else {
          _timedOut = true;
          timer.cancel();
        }
      });
    });
  }

  String get _formattedTime {
    final m = _remainingSeconds ~/ 60;
    final s = _remainingSeconds % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  // ── UI ────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return BlocListener<AuthBloc, AuthState>(
      listener: _onStateChange,
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon:
                const Icon(Icons.arrow_back_ios, color: AppColors.textPrimary),
            onPressed: () => context.go(Routes.login),
          ),
        ),
        body: SafeArea(
          child: Padding(
            padding: AppSpacing.screenPadding,
            child: _timedOut ? _buildTimedOutView() : _buildWaitingView(),
          ),
        ),
      ),
    );
  }

  void _onStateChange(BuildContext context, AuthState state) {
    if (state is AuthAuthenticated) {
      context.go(Routes.dashboard);
    } else if (state is AuthShowSmsConsent) {
      context.go(Routes.smsConsent);
    } else if (state is AuthOtpError) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(state.message),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  // ── Waiting view ──────────────────────────────────────────────────────────

  Widget _buildWaitingView() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        const SizedBox(height: AppSpacing.xxl),

        // Title
        Text(
          'Verifying your number',
          style: AppTypography.headlineMedium.copyWith(
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: AppSpacing.sm),

        // Subtitle
        Text(
          'An SMS with your OTP was sent to',
          style: AppTypography.bodyMedium.copyWith(
            color: AppColors.textSecondary,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 4),
        Text(
          widget.phoneNumber,
          style: AppTypography.bodyLarge.copyWith(
            color: AppColors.primary,
            fontWeight: FontWeight.w600,
          ),
          textAlign: TextAlign.center,
        ),

        const SizedBox(height: AppSpacing.xl),

        // Pulsing ring around message icon
        _buildPulsingIcon(),

        const SizedBox(height: AppSpacing.xl),

        // OTP digit boxes (auto-filled only)
        _buildOtpBoxes(),

        const SizedBox(height: AppSpacing.md),

        // Status text
        BlocBuilder<AuthBloc, AuthState>(
          builder: (context, state) {
            if (state is AuthOtpVerifying) {
              return Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: AppColors.primary,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Verifying…',
                    style: AppTypography.bodyMedium.copyWith(
                      color: AppColors.primary,
                    ),
                  ),
                ],
              );
            }
            return Text(
              _detectedCode.isNotEmpty
                  ? 'OTP detected! Completing verification…'
                  : 'Waiting for SMS…',
              style: AppTypography.bodyMedium.copyWith(
                color: _detectedCode.isNotEmpty
                    ? AppColors.success
                    : AppColors.textSecondary,
              ),
              textAlign: TextAlign.center,
            );
          },
        ),

        const SizedBox(height: AppSpacing.xl),

        // Info banner
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.infoSurface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.info.withOpacity(0.3)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.info_outline, color: AppColors.info, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'The OTP will be read automatically from your SMS. '
                  'The phone number you entered must be the SIM in this device.',
                  style: AppTypography.bodySmall.copyWith(
                    color: AppColors.info,
                  ),
                ),
              ),
            ],
          ),
        ),

        const Spacer(),

        // Countdown
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.timer_outlined,
              size: 16,
              color: AppColors.textSecondary,
            ),
            const SizedBox(width: 4),
            Text(
              'Expires in $_formattedTime',
              style: AppTypography.bodySmall.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),

        // Resend button (enabled after cooldown)
        TextButton(
          onPressed: _resendCooldown == 0
              ? () {
                  setState(() {
                    _resendCooldown = _kResendCooldownSeconds;
                    _remainingSeconds = _kOtpWindowSeconds;
                    _timedOut = false;
                    _detectedCode = '';
                  });
                  _startSmsListener();
                  context.read<AuthBloc>().add(AuthOtpResendRequested());
                }
              : null,
          child: Text(
            _resendCooldown > 0
                ? 'Resend OTP in ${_resendCooldown}s'
                : 'Resend OTP',
            style: AppTypography.bodyMedium.copyWith(
              color: _resendCooldown == 0
                  ? AppColors.primary
                  : AppColors.textTertiary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.md),
      ],
    );
  }

  // ── Timed-out view ────────────────────────────────────────────────────────

  Widget _buildTimedOutView() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        const SizedBox(height: AppSpacing.xxl),
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: AppColors.errorSurface,
            shape: BoxShape.circle,
          ),
          child: const Icon(
            Icons.sms_failed_outlined,
            size: 56,
            color: AppColors.error,
          ),
        ),
        const SizedBox(height: AppSpacing.xl),
        Text(
          'SMS Not Received',
          style: AppTypography.headlineMedium.copyWith(
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(
          'We could not detect the OTP SMS on this device.\n\n'
          'This could mean the number you entered ('
          '${widget.phoneNumber}) is not the active SIM in this phone.\n\n'
          'Only the phone number registered to this device can be used.',
          style: AppTypography.bodyMedium.copyWith(
            color: AppColors.textSecondary,
            height: 1.5,
          ),
          textAlign: TextAlign.center,
        ),
        const Spacer(),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: () {
              setState(() {
                _detectedCode = '';
                _remainingSeconds = _kOtpWindowSeconds;
                _resendCooldown = _kResendCooldownSeconds;
                _timedOut = false;
              });
              _startSmsListener();
              _startCountdown();
              context.read<AuthBloc>().add(AuthOtpResendRequested());
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: Text(
              'Try Again',
              style: AppTypography.bodyLarge.copyWith(
                color: AppColors.textOnPrimary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        TextButton(
          onPressed: () => context.go(Routes.login),
          child: Text(
            'Use a different number',
            style: AppTypography.bodyMedium.copyWith(
              color: AppColors.primary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.md),
      ],
    );
  }

  // ── Sub-widgets ───────────────────────────────────────────────────────────

  Widget _buildPulsingIcon() {
    return AnimatedBuilder(
      animation: _pulseAnimation,
      builder: (context, child) {
        return Transform.scale(
          scale: _pulseAnimation.value,
          child: child,
        );
      },
      child: Container(
        width: 100,
        height: 100,
        decoration: BoxDecoration(
          color: AppColors.primarySurface,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withOpacity(0.25),
              blurRadius: 24,
              spreadRadius: 4,
            ),
          ],
        ),
        child: const Icon(
          Icons.sms_outlined,
          size: 48,
          color: AppColors.primary,
        ),
      ),
    );
  }

  Widget _buildOtpBoxes() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(6, (i) {
        final filled = i < _detectedCode.length;
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: 44,
            height: 52,
            decoration: BoxDecoration(
              color:
                  filled ? AppColors.primarySurface : AppColors.surfaceVariant,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: filled ? AppColors.primary : AppColors.textTertiary,
                width: filled ? 2 : 1,
              ),
            ),
            alignment: Alignment.center,
            child: filled
                ? Text(
                    _detectedCode[i],
                    style: AppTypography.headlineMedium.copyWith(
                      color: AppColors.primary,
                      fontWeight: FontWeight.bold,
                    ),
                  )
                : Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(
                      color: AppColors.textTertiary,
                      shape: BoxShape.circle,
                    ),
                  ),
          ),
        );
      }),
    );
  }
}
