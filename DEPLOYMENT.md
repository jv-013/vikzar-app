# Vikzar — Deployment

## Firebase project
`vikzar-prod`, account `connect@vikzar.in`. 20 Cloud Functions (gen2, `nodejs20`, `us-central1`).

## Backend (Cloud Functions)

```bash
cd functions
npm run build
npm test
cd ..
firebase deploy --only functions:<name>[,<name>...] --project vikzar-prod
```

Always scope `--only functions:<name>` to the function(s) actually changed — a bare `--only functions` touches all 20. `razAsk` is currently at revision `razask-00003-mad`, deployed 2026-08-09, and is the streaming/mode/memory-aware implementation described in `RELEASE_NOTES.md`.

**Node 20 runtime warning:** Firebase Cloud Functions gen2 will eventually deprecate Node 20. This is real, documented maintenance debt — **not** part of this release's scope. Do not upgrade Node or `firebase-functions` as part of a routine deploy; that's a separate, deliberate migration.

### The `functions.json` trap (fixed, but know why)
A file literally named `functions.json` sitting at the **repo root** (sibling to the `functions/` directory) will silently break `firebase deploy`'s discovery step: Node's `require()` resolution tries `<path>.json` before falling back to directory/`package.json` resolution, so a stray `functions.json` gets loaded instead of `functions/lib/index.js`, and every function looks like it has zero endpoints — no error, just an empty manifest. If this ever recurs (e.g., someone redirects `firebase functions:list --json` output to a file at the repo root again), that's almost certainly why. Never write CLI output to a file named `functions.json` at the repo root.

## Android release build

Signing config lives in `android/key.properties` (gitignored) + `android/keystore/vikzar-release.jks` (gitignored). **Back up both outside this repository** — losing them means this app can never be updated again under this signing identity; a new one would be a different app identity to the Play Store and to Google Sign-In.

```bash
flutter build apk --release
```

Output: `build/app/outputs/flutter-apk/app-release.apk`. Verify signing with:

```bash
$ANDROID_HOME/build-tools/<version>/apksigner verify --print-certs build/app/outputs/flutter-apk/app-release.apk
```

**New keystore → new SHA-1 → Google Sign-In needs one manual step.** The release keystore generated for this release has SHA-1 `6E:83:3D:FE:55:26:81:18:C6:1E:84:53:A6:73:13:B6:CA:87:24:E8`. This is **not yet registered** with the Google Cloud OAuth client backing Google Sign-In (`android/app/google-services.json`'s `oauth_client` entries currently only cover the debug keystore). Until that SHA-1 is added in Google Cloud Console → APIs & Services → Credentials (and `google-services.json` re-synced), Google Sign-In will not complete on release-signed builds — confirmed live this release (opens the picker, returns to the sign-in screen with no error). Email Link sign-in is unaffected (it doesn't depend on the app's signing certificate).

## Firestore rules / indexes / storage rules
`firestore.rules`, `firestore.indexes.json`, `storage.rules` deploy via `firebase deploy --only firestore:rules,firestore:indexes,storage`. Not part of this release's commit — see `KNOWN_ISSUES.md`.
