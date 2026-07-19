import 'package:flutter_test/flutter_test.dart';

import 'package:vikzar/features/onboarding/domain/models/player_onboarding_data.dart';

void main() {
  group('PlayerProfileData.isComplete', () {
    test('false when required fields are missing', () {
      const profile = PlayerProfileData(name: 'Jai');
      expect(profile.isComplete, isFalse);
    });

    test('true once every required field is set, injury status included', () {
      const profile = PlayerProfileData(
        name: 'Jai',
        age: 21,
        height: 180,
        weight: 75,
        preferredFoot: PreferredFoot.right,
        position: PlayingPosition.midfielder,
        injuryStatus: InjuryHistoryStatus.never,
      );
      expect(profile.isComplete, isTrue);
    });

    test('name of only whitespace does not count as complete', () {
      const profile = PlayerProfileData(
        name: '   ',
        age: 21,
        height: 180,
        weight: 75,
        preferredFoot: PreferredFoot.right,
        position: PlayingPosition.midfielder,
        injuryStatus: InjuryHistoryStatus.never,
      );
      expect(profile.isComplete, isFalse);
    });
  });
}
