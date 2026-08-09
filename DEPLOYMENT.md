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

**Google Sign-In on release builds — resolved and verified.** The release keystore's SHA-1 (`6E:83:3D:FE:55:26:81:18:C6:1E:84:53:A6:73:13:B6:CA:87:24:E8`) has been registered with the Google Cloud OAuth client. Re-sync `google-services.json` after registering a new SHA-1 with:
```bash
firebase apps:sdkconfig ANDROID 1:295770188338:android:c4059d4c4a09ee92dcaa2b --project vikzar-prod --out android/app/google-services.json
```
Confirmed live this release: fresh install of the release APK, real Google Sign-In completed, landed in an authenticated Player home screen.

```bash
flutter build appbundle --release
```
Output: `build/app/outputs/bundle/release/app-release.aab`, signed with the same release keystore.

## iOS release build

```bash
flutter build ios --release --no-codesign
```
Output: `build/ios/iphoneos/Runner.app` (unsigned — see below). Requires `IPHONEOS_DEPLOYMENT_TARGET = 15.0` (already set in `Runner.xcodeproj`; Firebase's iOS SDKs reject anything lower) and `ios/Podfile`'s `platform :ios, '15.0'` line to match.

**No Apple Developer Team is configured** (`DEVELOPMENT_TEAM` unset in `Runner.xcodeproj`, `CODE_SIGN_STYLE = Automatic` with nothing to resolve against). This build is real and compiles clean, but it is **not signed for distribution** — App Store/TestFlight submission needs a real Apple Developer Program Team ID and provisioning profile supplied manually; this repo will not fabricate one.

**iOS Google Sign-In is not fully provisioned.** `ios/Runner/GoogleService-Info.plist` has no `CLIENT_ID`/`REVERSED_CLIENT_ID` — generate/verify the iOS OAuth client in Firebase Console and re-download the plist before Google Sign-In can be expected to work on iOS.

## macOS release build

```bash
flutter build macos --release
```
Output: `build/macos/Build/Products/Release/vikzar.app`. Builds and runs, but is only **ad-hoc signed** (`codesign -dv` shows `flags=0x2(adhoc)`) — not notarizable or distributable outside this machine without a real Apple Developer Team, same as iOS above.

## Windows release build
**Not buildable from this repository's current environment.** `flutter build windows` requires a Windows host with Visual Studio installed; this deployment record was produced on macOS. The `windows/` project scaffold exists (`CMakeLists.txt`, `flutter/`, `runner/`) but has never been built or tested. Attempt from an actual Windows machine.

## Firestore rules / indexes / storage rules
`firestore.rules`, `firestore.indexes.json`, `storage.rules` deploy via `firebase deploy --only firestore:rules,firestore:indexes,storage`. Not part of this release's commit — see `KNOWN_ISSUES.md`.
