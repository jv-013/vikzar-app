import 'package:flutter_test/flutter_test.dart';

import 'package:vikzar/core/errors/failure.dart';
import 'package:vikzar/core/result/result.dart';

void main() {
  group('Result', () {
    test('success reports isSuccess/isFailure correctly', () {
      const result = Result<int>.success(42);

      expect(result.isSuccess, isTrue);
      expect(result.isFailure, isFalse);
    });

    test('failure reports isSuccess/isFailure correctly', () {
      const result = Result<int>.failure(NetworkFailure());

      expect(result.isSuccess, isFalse);
      expect(result.isFailure, isTrue);
    });

    test('map transforms a success value', () {
      const result = Result<int>.success(2);

      final mapped = result.map((value) => value * 10);

      expect(mapped.fold(onSuccess: (v) => v, onFailure: (_) => -1), 20);
    });

    test('map leaves a failure untouched', () {
      const failure = NetworkFailure(message: 'offline');
      const result = Result<int>.failure(failure);

      final mapped = result.map((value) => value * 10);

      expect(
        mapped.fold(onSuccess: (_) => null, onFailure: (f) => f),
        same(failure),
      );
    });

    test('fold calls onSuccess for a Success', () {
      const result = Result<String>.success('ok');

      final output = result.fold(
        onSuccess: (value) => 'success: $value',
        onFailure: (failure) => 'failure',
      );

      expect(output, 'success: ok');
    });

    test('fold calls onFailure for a ResultFailure', () {
      const result = Result<String>.failure(UnknownFailure());

      final output = result.fold(
        onSuccess: (value) => 'success',
        onFailure: (failure) => 'failure: ${failure.runtimeType}',
      );

      expect(output, 'failure: UnknownFailure');
    });
  });
}
