import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:vikzar/design_system/theme/app_theme.dart';
import 'package:vikzar/features/onboarding/presentation/screens/splash_screen.dart';

void main() {
  group('SplashScreen', () {
    testWidgets('renders the wordmark and tagline', (tester) async {
      await tester.pumpWidget(
        MaterialApp(theme: AppTheme.dark(), home: const SplashScreen()),
      );
      await tester.pump(); // let the fade-in animation start

      expect(find.text('VIKZAR'), findsOneWidget);
      expect(find.text('Know Every Impact.'), findsOneWidget);
    });

    testWidgets('has no buttons, spinner, or progress indicator '
        '(DESIGN_SPECIFICATION.md §19.1)', (tester) async {
      await tester.pumpWidget(
        MaterialApp(theme: AppTheme.dark(), home: const SplashScreen()),
      );
      await tester.pump();

      expect(find.byType(ElevatedButton), findsNothing);
      expect(find.byType(TextButton), findsNothing);
      expect(find.byType(OutlinedButton), findsNothing);
      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(find.byType(LinearProgressIndicator), findsNothing);
    });

    testWidgets('fades in rather than appearing instantly', (tester) async {
      await tester.pumpWidget(
        MaterialApp(theme: AppTheme.dark(), home: const SplashScreen()),
      );

      // Immediately after the first frame, the fade animation has not yet
      // completed, so the content should not be fully opaque.
      final fadeFinder = find.byKey(const Key('splashFadeTransition'));
      final fadeTransition = tester.widget<FadeTransition>(fadeFinder);
      expect(fadeTransition.opacity.value, lessThan(1.0));

      await tester.pumpAndSettle();

      final settledFade = tester.widget<FadeTransition>(fadeFinder);
      expect(settledFade.opacity.value, 1.0);
    });
  });
}
