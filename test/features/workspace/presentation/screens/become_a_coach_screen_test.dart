import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:vikzar/core/result/result.dart';
import 'package:vikzar/design_system/theme/app_theme.dart';
import 'package:vikzar/features/workspace/data/repositories/coach_request_repository_impl.dart';
import 'package:vikzar/features/workspace/domain/models/coach_request.dart';
import 'package:vikzar/features/workspace/domain/repositories/coach_request_repository.dart';
import 'package:vikzar/features/workspace/presentation/screens/become_a_coach_complete_screen.dart';
import 'package:vikzar/features/workspace/presentation/screens/become_a_coach_screen.dart';
import 'package:vikzar/routing/app_router.dart';
import 'package:vikzar/shared/models/app_user.dart';
import 'package:vikzar/shared/providers/current_app_user_provider.dart';
import 'package:vikzar/shared/providers/current_uid_provider.dart';

const _uid = 'uid_123';

/// Records the submitted request instead of touching real Firestore —
/// Phase 8B (DECISIONS.md ADR-051) turned Submit into a real write.
class _RecordingCoachRequestRepository implements CoachRequestRepository {
  CoachRequest? submitted;

  @override
  Future<Result<void>> submit(CoachRequest request) async {
    submitted = request;
    return const Result.success(null);
  }
}

void main() {
  group('BecomeACoachScreen', () {
    testWidgets(
      'Submit stays disabled until Level, Club, and Role are filled, then '
      'advances to the submitted-for-review confirmation',
      (tester) async {
        // The form is taller than the default 800x600 test surface, which
        // leaves Submit's computed tap offset outside the rendered
        // window. Enlarge it so the button is actually reachable.
        tester.view.physicalSize = const Size(800, 1400);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        // The screen navigates via the real AppRoute path constants
        // (context.push(AppRoute.becomeCoachCompletePath)), so the test's
        // router must register those same paths, not stand-ins.
        final router = GoRouter(
          initialLocation: AppRoute.becomeCoachPath,
          routes: [
            GoRoute(
              path: AppRoute.becomeCoachPath,
              builder: (context, state) => const BecomeACoachScreen(),
            ),
            GoRoute(
              path: AppRoute.becomeCoachCompletePath,
              builder: (context, state) => const BecomeACoachCompleteScreen(),
            ),
          ],
        );

        final repository = _RecordingCoachRequestRepository();

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              currentUidProvider.overrideWithValue(_uid),
              currentAppUserProvider.overrideWithValue(
                const AppUser(uid: _uid, email: 'player@vikzar.app', displayName: 'Jordan Blake'),
              ),
              coachRequestRepositoryProvider.overrideWithValue(repository),
            ],
            child: MaterialApp.router(theme: AppTheme.dark(), routerConfig: router),
          ),
        );

        TextButton submitButton() =>
            tester.widget<TextButton>(find.widgetWithText(TextButton, 'Submit'));

        expect(submitButton().onPressed, isNull);

        await tester.tap(find.text('Club'));
        await tester.enterText(
          find.widgetWithText(TextField, 'Club / Academy Name'),
          'Riverside Academy',
        );
        await tester.enterText(
          find.widgetWithText(TextField, 'Current Role'),
          'Assistant Coach',
        );
        await tester.pumpAndSettle();

        expect(submitButton().onPressed, isNotNull);

        await tester.tap(find.text('Submit'));
        await tester.pumpAndSettle();

        expect(find.text('Your request has been submitted.'), findsOneWidget);
        expect(
          find.textContaining("We'll review it and notify you"),
          findsOneWidget,
        );
        expect(repository.submitted, isNotNull);
        expect(repository.submitted!.uid, _uid);
        expect(repository.submitted!.club, 'Riverside Academy');
      },
    );
  });
}
