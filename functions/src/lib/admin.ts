import { initializeApp, getApps } from "firebase-admin/app";
import { getFirestore } from "firebase-admin/firestore";

/**
 * Single Admin SDK app instance, lazily initialized — Cloud Functions may
 * cold-start multiple times per container, so this must be idempotent.
 */
function app() {
  const existing = getApps();
  return existing.length > 0 ? existing[0]! : initializeApp();
}

export function db() {
  return getFirestore(app());
}
