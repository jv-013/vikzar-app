import 'package:cloud_functions/cloud_functions.dart';

import 'failure.dart';

/// Maps a failed Callable Cloud Function invocation to [CloudFailure] —
/// the type `failure.dart` already reserves for exactly this ("A
/// Callable Cloud Function call failed"). Phase 13 §5 is this
/// codebase's first Flutter-side caller of a Callable
/// (`createPlannedSession`) — prior phases only ever read/wrote Firestore
/// directly, so no such mapper existed yet.
Failure mapCloudFunctionError(Object error) {
  if (error is FirebaseFunctionsException) {
    return CloudFailure(message: error.code, cause: error);
  }
  return CloudFailure(cause: error);
}
