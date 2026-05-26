# Migration & Deployment Checklists

Two checklists. The first walks you through the cutover from the legacy
SharedPreferences-only app to the new Firebase-backed one. The second is
the gate you should pass before shipping a build to attendees.

---

## Migration checklist (legacy → Firebase backend)

The legacy app stored user + bingo state in `SharedPreferences`. This
codebase has dropped that path entirely; the steps below are what's
required for an existing install base to move over cleanly. Skip
anything that doesn't apply if you're starting fresh.

- [ ] **Snapshot any production data.** If real users ran the legacy
      build, capture their SharedPreferences dumps before pushing the
      new build — the new code doesn't read those keys.
- [ ] **Bump the QR signature.** Set `QR_SIGNATURE=BINGO_USER_V2` in
      `.env` so any pre-migration QR codes are rejected with the
      friendly "not from Namma Bingo" message instead of silently
      breaking.
- [ ] **Regenerate `firebase_options.dart`** if you changed Firebase
      projects (`flutterfire configure`).
- [ ] **Run `dart run build_runner build --delete-conflicting-outputs`.**
      The new models depend on generated `*.freezed.dart` /
      `*.g.dart` files.
- [ ] **Seed Firestore.** `scripts/seed_questions.mjs` creates
      `games/default-game` + 15 questions. The app shows
      "No active game" if this is missing.
- [ ] **Deploy security rules + indexes.** `firebase deploy --only
      firestore:rules,firestore:indexes`.
- [ ] **Enable Anonymous Auth.** Firebase Console → Authentication →
      Sign-in method → Anonymous → Enable.
- [ ] **Verify the redirect flow on a fresh device.** Splash →
      onboarding → dashboard. If onboarding sticks, the
      `users/{uid}` write is failing — check Firestore rules.

---

## Production deployment checklist

Run this before every event / release.

### Config

- [ ] `.env` has the correct `ACTIVE_GAME_ID` for this event.
- [ ] `ALLOW_REPETITIVE_PERSON_SCAN` is set deliberately (default
      false = each person fills exactly one of your slots).
- [ ] `QR_SIGNATURE` is unique per major release / event.
- [ ] Firebase project on the deployment matches `firebase_options.dart`
      and `.firebaserc`.

### Codegen + lint

- [ ] `dart run build_runner build --delete-conflicting-outputs` clean
      (no diff in `*.g.dart` / `*.freezed.dart` after running).
- [ ] `flutter analyze` clean.
- [ ] `flutter test` passes (when tests exist — see "Gaps" below).

### Firestore

- [ ] Rules deployed and reviewed: `firestore.rules`.
- [ ] Indexes deployed: `firestore.indexes.json`. Verify in console that
      the composite indexes are "Enabled" (not "Building").
- [ ] Questions seeded for the active game.
- [ ] `games/{ACTIVE_GAME_ID}.isActive == true`.
- [ ] `games/{ACTIVE_GAME_ID}.slotCount` matches the seeded question
      count.

### Auth

- [ ] Anonymous Auth enabled in Firebase Console.

### Mobile builds

- [ ] iOS: `NSCameraUsageDescription` present in `ios/Runner/Info.plist`.
      App built with a real bundle ID and provisioning profile.
- [ ] Android: `CAMERA`, `INTERNET` permissions in
      `android/app/src/main/AndroidManifest.xml`. Min SDK aligns with
      mobile_scanner / Firebase requirements.
- [ ] Crashlytics symbols uploaded (`flutter build apk --obfuscate
      --split-debug-info=…` then upload `*.symbols` to Firebase).

### Web

- [ ] Served over HTTPS (camera will not start over plain HTTP).
- [ ] `firebase deploy --only hosting` from a clean `flutter build web`.

### Smoke test (run on a real device for each target platform)

- [ ] Fresh install / cleared storage → splash → onboarding works,
      user lands on dashboard.
- [ ] Grid renders question text from Firestore, not hardcoded.
- [ ] Generate QR → scan from a second device → slot fills, the
      scanner gets a haptic + green flash, and dialog isn't
      shown for valid scans.
- [ ] Self-scan rejected with friendly message.
- [ ] Re-scan of the same person blocked when
      `ALLOW_REPETITIVE_PERSON_SCAN=false`.
- [ ] Background the app mid-scan; foreground; camera resumes (the
      `WidgetsBindingObserver` should handle this).
- [ ] Complete all slots → celebration dialog fires once and only once.
- [ ] LinkedIn URL on a connected player opens in the system browser.
- [ ] Profile edit persists after app relaunch.

### Observability

- [ ] Crashlytics receiving events (force a test crash with
      `FirebaseCrashlytics.instance.crash()` once, verify it appears).
- [ ] Analytics enabled (Firebase Console → Analytics → Dashboard shows
      live users after the smoke test).

---

## Known gaps to track

- No `flutter test` coverage yet — repositories and `QrPayload` are the
  easiest first targets (pure logic, no platform deps).
- No in-app admin UI for adding/editing questions — `scripts/seed_questions.mjs`
  is the workflow.
- Single-game model assumes one event at a time. Multi-game support
  would replace the fixed `ACTIVE_GAME_ID` with a Firestore query for
  `where isActive == true`.
- Crashlytics disabled on web (not supported by `firebase_crashlytics`).
