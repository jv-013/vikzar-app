import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/errors/failure.dart';
import '../../../../core/errors/failure_message_mapper.dart';
import '../../../../design_system/components/vikzar_button.dart';
import '../../../../design_system/components/vikzar_icon.dart';
import '../../../../design_system/components/vikzar_otp_field.dart';
import '../../../../design_system/components/vikzar_text_field.dart';
import '../../../../design_system/tokens/motion.dart';
import '../../../../design_system/tokens/spacing.dart';
import '../controllers/auth_controller.dart';

const _resendCooldown = Duration(seconds: 30);

/// Sign In / Create Account — DESIGN_SPECIFICATION.md §19.1, revised
/// Phase 6: one continuous, passwordless flow — email, then a 6-digit
/// code. No password field, no separate sign-up path, no "signed in
/// successfully" confirmation screen. `AuthController` transparently signs
/// in or creates the account after code verification; the router
/// (`routing/route_guards.dart`) handles moving on once `authStateProvider`
/// changes — this screen never navigates itself.
class AuthScreen extends ConsumerStatefulWidget {
  const AuthScreen({super.key});

  @override
  ConsumerState<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends ConsumerState<AuthScreen> {
  final _emailController = TextEditingController();
  Timer? _cooldownTimer;
  int _cooldownSeconds = 0;

  @override
  void dispose() {
    _emailController.dispose();
    _cooldownTimer?.cancel();
    super.dispose();
  }

  void _startCooldown() {
    _cooldownTimer?.cancel();
    setState(() => _cooldownSeconds = _resendCooldown.inSeconds);
    _cooldownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_cooldownSeconds <= 1) {
        timer.cancel();
        setState(() => _cooldownSeconds = 0);
      } else {
        setState(() => _cooldownSeconds -= 1);
      }
    });
  }

  Future<void> _submitEmail() async {
    FocusScope.of(context).unfocus();
    await ref
        .read(authControllerProvider.notifier)
        .submitEmail(_emailController.text.trim());
    if (ref.read(authControllerProvider).step == AuthStep.otp) {
      _startCooldown();
    }
  }

  void _submitOtp(String code) {
    FocusScope.of(context).unfocus();
    ref.read(authControllerProvider.notifier).submitOtp(code);
  }

  Future<void> _resend() async {
    await ref.read(authControllerProvider.notifier).resendOtp();
    _startCooldown();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final flowState = ref.watch(authControllerProvider);
    final errorText = flowState.failure == null
        ? null
        : FailureMessageMapper.toMessage(flowState.failure as Failure);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(
                horizontal: SpacingTokens.space24,
              ),
              child: AnimatedSwitcher(
                duration: MotionTokens.pageTransition,
                switchInCurve: MotionTokens.entrance,
                switchOutCurve: MotionTokens.exit,
                transitionBuilder: (child, animation) => FadeTransition(
                  opacity: animation,
                  child: SlideTransition(
                    position: Tween<Offset>(
                      begin: const Offset(0.06, 0),
                      end: Offset.zero,
                    ).animate(animation),
                    child: child,
                  ),
                ),
                child: flowState.step == AuthStep.email
                    ? _EmailStep(
                        key: const ValueKey(AuthStep.email),
                        controller: _emailController,
                        isLoading: flowState.isSubmitting,
                        errorText: errorText,
                        onSubmit: _submitEmail,
                      )
                    : _OtpStep(
                        key: const ValueKey(AuthStep.otp),
                        email: flowState.email,
                        isLoading: flowState.isSubmitting,
                        errorText: errorText,
                        cooldownSeconds: _cooldownSeconds,
                        onCompleted: _submitOtp,
                        onResend: _resend,
                        onEditEmail: () =>
                            ref.read(authControllerProvider.notifier).editEmail(),
                      ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _EmailStep extends StatelessWidget {
  const _EmailStep({
    super.key,
    required this.controller,
    required this.isLoading,
    required this.errorText,
    required this.onSubmit,
  });

  final TextEditingController controller;
  final bool isLoading;
  final String? errorText;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        const SizedBox(height: SpacingTokens.space64),
        VikzarIcon(size: 48, color: theme.colorScheme.onSurface),
        const SizedBox(height: SpacingTokens.space32),
        Text('Sign in or create your account.', style: theme.textTheme.headlineLarge),
        const SizedBox(height: SpacingTokens.space12),
        Text(
          'Enter your email to continue.',
          style: theme.textTheme.bodyLarge?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: SpacingTokens.space32),
        VikzarTextField(
          label: 'Email',
          controller: controller,
          keyboardType: TextInputType.emailAddress,
          autofillHints: const [AutofillHints.email],
          enabled: !isLoading,
          errorText: errorText,
          onSubmitted: (_) => onSubmit(),
        ),
        const SizedBox(height: SpacingTokens.space16),
        Text.rich(
          TextSpan(
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
            children: const [
              TextSpan(text: "By continuing, you agree to Vikzar's "),
              TextSpan(
                text: 'Privacy Policy',
                style: TextStyle(decoration: TextDecoration.underline),
              ),
              TextSpan(text: ' and '),
              TextSpan(
                text: 'Terms of Use',
                style: TextStyle(decoration: TextDecoration.underline),
              ),
              TextSpan(text: '.'),
            ],
          ),
        ),
        const SizedBox(height: SpacingTokens.space32),
        Align(
          alignment: Alignment.centerRight,
          child: VikzarButton(label: 'Continue', isLoading: isLoading, onPressed: onSubmit),
        ),
        const SizedBox(height: SpacingTokens.space64),
      ],
    );
  }
}

class _OtpStep extends StatelessWidget {
  const _OtpStep({
    super.key,
    required this.email,
    required this.isLoading,
    required this.errorText,
    required this.cooldownSeconds,
    required this.onCompleted,
    required this.onResend,
    required this.onEditEmail,
  });

  final String email;
  final bool isLoading;
  final String? errorText;
  final int cooldownSeconds;
  final ValueChanged<String> onCompleted;
  final VoidCallback onResend;
  final VoidCallback onEditEmail;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final canResend = cooldownSeconds == 0 && !isLoading;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        const SizedBox(height: SpacingTokens.space64),
        VikzarIcon(size: 48, color: theme.colorScheme.onSurface),
        const SizedBox(height: SpacingTokens.space32),
        Text('Enter the code we sent you.', style: theme.textTheme.headlineLarge),
        const SizedBox(height: SpacingTokens.space12),
        Text.rich(
          TextSpan(
            style: theme.textTheme.bodyLarge?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
            children: [
              const TextSpan(text: "We've sent a 6-digit code to "),
              TextSpan(
                text: email,
                style: TextStyle(color: theme.colorScheme.onSurface),
              ),
              const TextSpan(text: '. '),
              TextSpan(
                text: 'Edit',
                style: TextStyle(
                  color: theme.colorScheme.primary,
                  decoration: TextDecoration.underline,
                ),
                recognizer: TapGestureRecognizer()..onTap = onEditEmail,
              ),
            ],
          ),
        ),
        const SizedBox(height: SpacingTokens.space32),
        VikzarOtpField(
          enabled: !isLoading,
          errorText: errorText,
          onCompleted: onCompleted,
        ),
        const SizedBox(height: SpacingTokens.space12),
        Text(
          "Code verification isn't live yet — any 6-digit code is "
          'accepted while this is in development.',
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: SpacingTokens.space24),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton(
            onPressed: canResend ? onResend : null,
            child: Text(
              canResend ? 'Resend code' : 'Resend code in ${cooldownSeconds}s',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: canResend
                    ? theme.colorScheme.primary
                    : theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ),
        if (isLoading) ...[
          const SizedBox(height: SpacingTokens.space16),
          Center(
            child: SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation(theme.colorScheme.primary),
              ),
            ),
          ),
        ],
        const SizedBox(height: SpacingTokens.space64),
      ],
    );
  }
}
