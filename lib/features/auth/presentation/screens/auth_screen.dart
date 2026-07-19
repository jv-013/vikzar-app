import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/errors/failure.dart';
import '../../../../core/errors/failure_message_mapper.dart';
import '../../../../design_system/components/vikzar_button.dart';
import '../../../../design_system/components/vikzar_icon.dart';
import '../../../../design_system/components/vikzar_text_field.dart';
import '../../../../design_system/tokens/spacing.dart';
import '../controllers/auth_controller.dart';

/// Sign In / Create Account — DESIGN_SPECIFICATION.md §19.1: one screen,
/// one email field, one password field, one "Continue" action. No
/// separate sign-up flow, no OTP step, no "signed in successfully"
/// confirmation screen — `AuthController.submit` transparently signs in or
/// creates the account, and the router (`routing/route_guards.dart`)
/// handles moving on once `authStateProvider` changes; this screen never
/// navigates itself.
class AuthScreen extends ConsumerStatefulWidget {
  const AuthScreen({super.key});

  @override
  ConsumerState<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends ConsumerState<AuthScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _submit() {
    FocusScope.of(context).unfocus();
    ref
        .read(authControllerProvider.notifier)
        .submit(
          email: _emailController.text.trim(),
          password: _passwordController.text,
        );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final authState = ref.watch(authControllerProvider);
    final isLoading = authState.isLoading;
    final errorText = authState.hasError
        ? FailureMessageMapper.toMessage(authState.error as Failure)
        : null;

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
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(height: SpacingTokens.space64),
                  VikzarIcon(size: 48, color: theme.colorScheme.onSurface),
                  const SizedBox(height: SpacingTokens.space32),
                  Text(
                    'Sign in or create your account.',
                    style: theme.textTheme.headlineLarge,
                  ),
                  const SizedBox(height: SpacingTokens.space32),
                  VikzarTextField(
                    label: 'Email',
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    autofillHints: const [AutofillHints.email],
                    enabled: !isLoading,
                  ),
                  const SizedBox(height: SpacingTokens.space16),
                  VikzarTextField(
                    label: 'Password',
                    controller: _passwordController,
                    obscureText: true,
                    autofillHints: const [AutofillHints.password],
                    enabled: !isLoading,
                    errorText: errorText,
                    onSubmitted: (_) => _submit(),
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
                    child: VikzarButton(
                      label: 'Continue',
                      isLoading: isLoading,
                      onPressed: _submit,
                    ),
                  ),
                  const SizedBox(height: SpacingTokens.space64),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
