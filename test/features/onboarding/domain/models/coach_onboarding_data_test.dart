import 'package:flutter_test/flutter_test.dart';

import 'package:vikzar/features/onboarding/domain/models/coach_onboarding_data.dart';

void main() {
  group('CoachProfileData.isComplete', () {
    test('false when required fields are missing', () {
      const profile = CoachProfileData(name: 'Jai');
      expect(profile.isComplete, isFalse);
    });

    test('true once name, age, and title are set — club is optional', () {
      const profile = CoachProfileData(name: 'Jai', age: 34, title: 'Head Coach');
      expect(profile.isComplete, isTrue);
    });
  });

  group('TeamSetupData.isComplete', () {
    test('false with no mode chosen', () {
      const team = TeamSetupData();
      expect(team.isComplete, isFalse);
    });

    test('create mode requires a non-empty team name', () {
      const empty = TeamSetupData(mode: TeamSetupMode.create);
      const filled = TeamSetupData(mode: TeamSetupMode.create, teamName: 'Riverside U18');
      expect(empty.isComplete, isFalse);
      expect(filled.isComplete, isTrue);
    });

    test('join mode requires a non-empty invite code', () {
      const empty = TeamSetupData(mode: TeamSetupMode.join);
      const filled = TeamSetupData(mode: TeamSetupMode.join, inviteCode: 'ABC123');
      expect(empty.isComplete, isFalse);
      expect(filled.isComplete, isTrue);
    });
  });
}
