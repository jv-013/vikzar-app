import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/errors/failure.dart';
import '../../../../core/errors/failure_message_mapper.dart';
import '../../../../design_system/components/vikzar_button.dart';
import '../../../../design_system/components/vikzar_icon.dart';
import '../../../../design_system/components/vikzar_text_field.dart';
import '../../../../design_system/tokens/motion.dart';
import '../../../../design_system/tokens/spacing.dart';
import '../../../../services/deep_links/deep_link_service.dart';
import '../controllers/auth_controller.dart';

/// Sign In / Create Account — DESIGN_SPECIFICATION.md §19.1, rebuilt at
/// Phase 17 around three real Firebase Authentication providers (see
/// DECISIONS.md's Phase 17 ADR, which supersedes ADR-044's placeholder
/// email/code flow): Google, Apple (iOS/macOS only), and Firebase's own
/// Email Link (magic link) as a no-password fallback. There is no
/// password field, no 6-digit code, and no separate sign-up path — every
/// provider transparently creates an account on first use.
///
/// One continuous screen, not a step machine: Google/Apple resolve in a
/// single tap; the email-link path swaps its form for a "check your
/// email" confirmation via [AnimatedSwitcher], matching this screen's
/// prior step-transition treatment without reintroducing step state.
/// `AuthController` never navigates itself — the router
/// (`routing/route_guards.dart`) moves on once `authStateProvider`
/// changes, for every provider alike.
class AuthScreen extends ConsumerStatefulWidget {
  const AuthScreen({super.key});

  @override
  ConsumerState<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends ConsumerState<AuthScreen> {
  final _emailController = TextEditingController();
  StreamSubscription<Uri>? _linkSubscription;

  @override
  void initState() {
    super.initState();
    // The email-link flow always completes here: an unauthenticated user
    // is always routed to this screen (route_guards.dart), so this is the
    // one place that needs to listen for the tapped link reopening the
    // app. `linkStream` alone covers both a cold start (the plugin
    // replays the launch link to the first stream listener) and a warm
    // resume (a new link while already running) — subscribing to it
    // *and* separately calling `getInitialLink()` double-processes the
    // same cold-start link, which wastes a `signInWithEmailLink` call on
    // a single-use code and needlessly risks an "already used" error
    // racing the real one.
    //
    // Web-excluded: `app_links` reopens a *native* app via a custom
    // scheme/universal link — meaningless on web, where following the
    // emailed link simply loads this same page fresh at that URL, and
    // its native event channel isn't implemented there (validated:
    // browser testing surfaced an uncaught MissingPluginException).
    if (!kIsWeb) {
      _linkSubscription = ref.read(deepLinkServiceProvider).linkStream.listen(_handleIncomingLink);
    }
  }

  void _handleIncomingLink(Uri uri) {
    ref.read(authControllerProvider.notifier).completeSignInWithLink(uri.toString());
  }

  @override
  void dispose() {
    _emailController.dispose();
    _linkSubscription?.cancel();
    super.dispose();
  }

  Future<void> _sendMagicLink() async {
    FocusScope.of(context).unfocus();
    await ref.read(authControllerProvider.notifier).sendMagicLink(_emailController.text.trim());
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final flowState = ref.watch(authControllerProvider);
    final errorText = flowState.failure == null
        ? null
        : FailureMessageMapper.toMessage(flowState.failure as Failure);
    final isApplePlatform = !kIsWeb && (Platform.isIOS || Platform.isMacOS);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: SpacingTokens.space24),
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
                child: flowState.magicLinkSent
                    ? _CheckYourEmailStep(
                        key: const ValueKey('check-email'),
                        email: flowState.pendingEmail,
                        isLoading: flowState.isSubmitting,
                        errorText: errorText,
                        onResend: () =>
                            ref.read(authControllerProvider.notifier).resendMagicLink(),
                        onEditEmail: () =>
                            ref.read(authControllerProvider.notifier).editEmail(),
                      )
                    : _SignInStep(
                        key: const ValueKey('sign-in'),
                        emailController: _emailController,
                        isLoading: flowState.isSubmitting,
                        errorText: errorText,
                        showApple: isApplePlatform,
                        onGoogle: () =>
                            ref.read(authControllerProvider.notifier).signInWithGoogle(),
                        onApple: () =>
                            ref.read(authControllerProvider.notifier).signInWithApple(),
                        onSendMagicLink: _sendMagicLink,
                      ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SignInStep extends StatelessWidget {
  const _SignInStep({
    super.key,
    required this.emailController,
    required this.isLoading,
    required this.errorText,
    required this.showApple,
    required this.onGoogle,
    required this.onApple,
    required this.onSendMagicLink,
  });

  final TextEditingController emailController;
  final bool isLoading;
  final String? errorText;
  final bool showApple;
  final VoidCallback onGoogle;
  final VoidCallback onApple;
  final VoidCallback onSendMagicLink;

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
          'Get into training in seconds.',
          style: theme.textTheme.bodyLarge?.copyWith(color: theme.colorScheme.onSurfaceVariant),
        ),
        const SizedBox(height: SpacingTokens.space32),
        VikzarButton(
          label: 'Continue with Google',
          variant: VikzarButtonVariant.secondary,
          isLoading: isLoading,
          onPressed: isLoading ? null : onGoogle,
        ),
        if (showApple) ...[
          const SizedBox(height: SpacingTokens.space12),
          VikzarButton(
            label: 'Continue with Apple',
            variant: VikzarButtonVariant.secondary,
            isLoading: isLoading,
            onPressed: isLoading ? null : onApple,
          ),
        ],
        const SizedBox(height: SpacingTokens.space24),
        Row(
          children: [
            Expanded(child: Divider(color: theme.colorScheme.onSurface.withValues(alpha: 0.12))),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: SpacingTokens.space12),
              child: Text(
                'or',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
            Expanded(child: Divider(color: theme.colorScheme.onSurface.withValues(alpha: 0.12))),
          ],
        ),
        const SizedBox(height: SpacingTokens.space24),
        VikzarTextField(
          label: 'Email',
          controller: emailController,
          keyboardType: TextInputType.emailAddress,
          autofillHints: const [AutofillHints.email],
          enabled: !isLoading,
          errorText: errorText,
          onSubmitted: (_) => onSendMagicLink(),
        ),
        const SizedBox(height: SpacingTokens.space16),
        Text.rich(
          TextSpan(
            style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            children: const [
              TextSpan(text: "By continuing, you agree to Vikzar's "),
              TextSpan(
                text: 'Privacy Policy',
                style: TextStyle(decoration: TextDecoration.underline),
              ),
              TextSpan(text: ' and '),
              TextSpan(text: 'Terms of Use', style: TextStyle(decoration: TextDecoration.underline)),
              TextSpan(text: '.'),
            ],
          ),
        ),
        const SizedBox(height: SpacingTokens.space32),
        Align(
          alignment: Alignment.centerRight,
          child: VikzarButton(
            label: 'Email me a link',
            isLoading: isLoading,
            onPressed: onSendMagicLink,
          ),
        ),
        const SizedBox(height: SpacingTokens.space64),
      ],
    );
  }
}

class _CheckYourEmailStep extends StatelessWidget {
  const _CheckYourEmailStep({
    super.key,
    required this.email,
    required this.isLoading,
    required this.errorText,
    required this.onResend,
    required this.onEditEmail,
  });

  final String email;
  final bool isLoading;
  final String? errorText;
  final VoidCallback onResend;
  final VoidCallback onEditEmail;

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
        Text('Check your email.', style: theme.textTheme.headlineLarge),
        const SizedBox(height: SpacingTokens.space12),
        Text.rich(
          TextSpan(
            style: theme.textTheme.bodyLarge?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            children: [
              const TextSpan(text: "We've sent a sign-in link to "),
              TextSpan(text: email, style: TextStyle(color: theme.colorScheme.onSurface)),
              const TextSpan(text: '. Open it on this device to continue.'),
            ],
          ),
        ),
        if (errorText != null) ...[
          const SizedBox(height: SpacingTokens.space16),
          Text(errorText!, style: TextStyle(color: theme.colorScheme.error)),
        ],
        const SizedBox(height: SpacingTokens.space24),
        Row(
          children: [
            TextButton(
              onPressed: isLoading ? null : onResend,
              child: Text(
                'Resend link',
                style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.primary),
              ),
            ),
            TextButton(
              onPressed: isLoading ? null : onEditEmail,
              child: Text(
                'Edit email',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ],
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
