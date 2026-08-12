import 'package:flutter_test/flutter_test.dart';

import 'package:vikzar/core/errors/failure.dart';
import 'package:vikzar/core/errors/failure_message_mapper.dart';

void main() {
  group('FailureMessageMapper', () {
    test('never includes a raw error code in the user-facing message', () {
      const failures = [
        NetworkFailure(message: 'some-raw-code'),
        AuthFailure(message: 'wrong-password'),
        PermissionFailure(message: 'permission-denied'),
        CloudFailure(message: 'internal'),
        UnknownFailure(message: 'weird-native-exception-string'),
      ];

      for (final failure in failures) {
        final message = FailureMessageMapper.toMessage(failure);
        expect(
          message.contains(failure.message!),
          isFalse,
          reason: 'Raw code "${failure.message}" leaked into user-facing copy',
        );
      }
    });

    test('maps known auth error codes to specific, calm copy', () {
      expect(
        FailureMessageMapper.toMessage(const AuthFailure(message: 'invalid-credential')),
        "We couldn't verify that. Please try again.",
      );
      expect(
        FailureMessageMapper.toMessage(const AuthFailure(message: 'invalid-email')),
        contains("doesn't look right"),
      );
    });

    test('falls back to a calm generic message for an unrecognized code', () {
      final message = FailureMessageMapper.toMessage(
        const AuthFailure(message: 'some-new-sdk-code-not-yet-mapped'),
      );
      expect(message, isNotEmpty);
      expect(message, isNot(contains('some-new-sdk-code-not-yet-mapped')));
    });
  });
}
