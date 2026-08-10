import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../services/firebase/firestore_service.dart';
import '../../../shared/providers/current_uid_provider.dart';

enum FirestoreConnectivity {
  /// The signed-in account's own document was just served from a real
  /// server round-trip, not the local cache.
  live,

  /// Served from Firestore's on-device persistence cache — the last
  /// snapshot this device actually received from the server, not proof
  /// of a current connection.
  cached,

  /// Not signed in, so there is no document this account is guaranteed
  /// to be allowed to read (Firestore security rules only grant a
  /// query-wide read on a document the caller owns).
  unknown,
}

/// A real, minimal connectivity signal for the Developer Diagnostics
/// screen — reuses the signed-in account's own `users/{uid}` document
/// (guaranteed self-readable by `firestore.rules`, unlike an arbitrary
/// collection query) and reads [DocumentSnapshot.metadata.isFromCache]
/// off it. Not a general Firestore health check — just "did the last
/// snapshot for this document come from the server or the cache."
final firestoreConnectivityProvider = StreamProvider<FirestoreConnectivity>((ref) {
  final uid = ref.watch(currentUidProvider);
  if (uid == null) return Stream.value(FirestoreConnectivity.unknown);

  final firestore = ref.watch(firestoreProvider);
  return firestore
      .collection('users')
      .doc(uid)
      .snapshots(includeMetadataChanges: true)
      .map((snapshot) {
        return snapshot.metadata.isFromCache
            ? FirestoreConnectivity.cached
            : FirestoreConnectivity.live;
      });
});
