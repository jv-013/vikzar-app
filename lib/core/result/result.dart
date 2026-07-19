import '../errors/failure.dart';

/// The typed success/failure construct every repository method returns,
/// per ARCHITECTURE.md §16 and FLUTTER_ARCHITECTURE.md §12.
///
/// Repositories never throw across the domain boundary; they return a
/// [Result] so the presentation layer must consciously handle failure.
sealed class Result<T> {
  const Result();

  const factory Result.success(T value) = Success<T>;
  const factory Result.failure(Failure failure) = ResultFailure<T>;

  /// True if this is a [Success].
  bool get isSuccess => this is Success<T>;

  /// True if this is a [ResultFailure].
  bool get isFailure => this is ResultFailure<T>;

  /// Maps a success value, leaving a failure untouched.
  Result<R> map<R>(R Function(T value) transform) => switch (this) {
    Success<T>(value: final value) => Result.success(transform(value)),
    ResultFailure<T>(failure: final failure) => Result.failure(failure),
  };

  /// Folds this [Result] into a single value, handling both cases.
  R fold<R>({
    required R Function(T value) onSuccess,
    required R Function(Failure failure) onFailure,
  }) => switch (this) {
    Success<T>(value: final value) => onSuccess(value),
    ResultFailure<T>(failure: final failure) => onFailure(failure),
  };
}

final class Success<T> extends Result<T> {
  const Success(this.value);

  final T value;
}

final class ResultFailure<T> extends Result<T> {
  const ResultFailure(this.failure);

  final Failure failure;
}
