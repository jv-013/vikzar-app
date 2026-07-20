import 'package:cloud_firestore/cloud_firestore.dart';

import 'failure.dart';

/// Maps *any* error a Firestore call can throw to a [Failure] — added Phase
/// 8C after live testing surfaced a real bug: every repository's
/// `on FirebaseException catch (e)` clause missed a genuine
/// `permission-denied` rejection from inside `runTransaction`'s web
/// implementation (`cloud_firestore_web`'s `convertWebExceptions` does not
/// always yield a plain [FirebaseException] for every failure shape a
/// transaction can produce), silently falling through to the generic
/// `catch (e)` branch and reporting [UnknownFailure] instead of
/// [PermissionFailure] — a real instance of this project's "no silent
/// failures, no fake success" mandate being violated by an overly narrow
/// catch type, not by any swallowed exception.
///
/// [error] is deliberately `Object`, not [FirebaseException]: every
/// call site should use a single `catch (error) { mapFirestoreError(error)
/// }` rather than a `on FirebaseException catch` / `catch` pair, so no
/// error shape can slip past unclassified again.
Failure mapFirestoreError(Object error) {
  final code = _extractCode(error);
  switch (code) {
    case 'permission-denied':
      return PermissionFailure(message: code, cause: error);
    case 'unavailable':
    case 'deadline-exceeded':
      return NetworkFailure(message: code, cause: error);
    case null:
      return UnknownFailure(cause: error);
    default:
      return UnknownFailure(message: code, cause: error);
  }
}

/// Firebase's own [FirebaseException] carries `.code` directly. Anything
/// else (a plain JS interop error object that didn't get converted, a
/// [TimeoutException], etc.) is checked for a same-shaped `code` property
/// via `dynamic` access, then as a last resort by matching a known code
/// string inside `toString()` — better than silently defaulting to
/// "unknown" when the information to classify correctly is right there in
/// the error, just not in the exact type this code expected.
String? _extractCode(Object error) {
  if (error is FirebaseException) return error.code;

  try {
    final dynamicCode = (error as dynamic).code;
    if (dynamicCode is String) return dynamicCode;
  } catch (_) {
    // Not an object with a `.code` getter — fall through to string
    // matching below.
  }

  const knownCodes = [
    'permission-denied',
    'unavailable',
    'deadline-exceeded',
    'not-found',
    'aborted',
    'cancelled',
  ];
  final text = error.toString();
  for (final known in knownCodes) {
    if (text.contains(known)) return known;
  }
  return null;
}
