# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this app is

Namma Bingo (package `namma_bingo`) is a Flutter networking-bingo app for events. Players generate a QR code; scanning someone else's QR fills a slot tied to a question prompt ("Find someone who…"). Targets Web, Android, iOS — all from one codebase.

Backend is Firebase: Anonymous Auth + Firestore + Crashlytics (mobile only). All persistent state lives in Firestore; SharedPreferences is no longer used. Firebase Storage was deliberately dropped — profile photos aren't stored; avatars are initial-letter circles via `ProfileAvatar`. Adding photos back later would mean re-introducing Storage and the Blaze plan requirement.

The deployed web build runs at `mako-bingo.web.app` under Firebase project `bingo-30ffd` (multi-site hosting; the project's default `bingo-30ffd.web.app` is unused).

## Commands

```bash
flutter pub get
dart run build_runner build --delete-conflicting-outputs   # freezed/json_serializable codegen
flutter run -d chrome                                       # primary dev target
flutter analyze
flutter test
flutter test test/qr_payload_test.dart                      # single file
flutter build web --release && firebase deploy --only hosting

# Firestore content seeding (one-time per project, re-runnable to update questions)
cd scripts && npm install
GOOGLE_APPLICATION_CREDENTIALS=./service-account.json npm run seed

# Rules + indexes (no storage — we dropped it)
firebase deploy --only firestore:rules,firestore:indexes
```

**Important**: model files (`lib/data/models/*.dart`) depend on generated `*.freezed.dart` and `*.g.dart` siblings. Re-run `build_runner` any time you edit a `@freezed` class or the build will fail. Generated files are gitignored — they're build artifacts.

## Architecture

```
lib/
  app/                       MaterialApp, router, bootstrap (Crashlytics + Firebase init + URL strategy)
  core/                      Result, AppException, Logger, Env
    platform/                conditional-import shims: file_saver, url_strategy
  data/
    models/                  freezed: UserModel, GameModel, QuestionModel, SessionModel, BoxSlot, ScanModel
    repositories/            UserRepo, GameRepo, QuestionRepo, SessionRepo
    sources/                 FirestoreService (collection refs)
  features/
    auth/                    AuthService + auth_providers (authState, currentUid, currentUser, authBootstrap)
    bingo/                   DashboardScreen, BingoSlotTile, bingo_providers (mySession, completedSlotCount)
    network/                 ConnectionsScreen
    onboarding/              OnboardingScreen + controller + validators
    profile/                 ProfileScreen (view + edit)
    qr/                      QrGeneratorScreen, QrScannerScreen, QrPayload
    scoreboard/              ScoreboardScreen + scoreboard_providers (kiosk view)
    shell/                   ShellScreen (bottom-nav)
    splash/                  SplashScreen
  shared/
    theme/                   AppColors, AppTypography, AppSpacing, AppRadius, AppTheme.dark()
    widgets/                 AppButton, AppCard, AppSkeleton, AppTextField, AppEmptyState, AppErrorState, ProfileAvatar
                             AnimatedEntry, AnimatedNumber, ConfettiBurst (reusable motion primitives)
  features/qr/widgets/       scan_success_overlay.dart (trophy moment shown after recordScan)
```

**State management**: Riverpod 2.x. Streams from Firestore use `StreamProvider`; mutating actions (auth bootstrap, onboarding submit) use `AsyncNotifier`. Repositories return `Result<T>` so callers must handle both branches.

**Routing**: `go_router` with `refreshListenable` bridged from Riverpod via a small `ChangeNotifier` adapter in `lib/app/router.dart`. The redirect function gates on `authStateProvider` + `currentUserProvider`:

- **`/scoreboard` always passes through unconditionally** — kiosk view, handles its own auth-loading state inside the widget so opening the URL on a never-onboarded device works.
- Either provider loading → `/splash`
- Auth resolved but no Firebase user → `/splash` (with retry)
- Auth resolved, no `users/{uid}` doc yet → `/onboarding` (forced)
- Both resolved → bottom-nav shell with `/`, `/connections`, `/qr-code`

Top-level (no shell): `/splash`, `/onboarding`, `/profile`, `/scan`, `/scoreboard`. The scanner route takes `{slotIndex, questionId, questionText}` via `state.extra`.

**URL strategy**: `bootstrap.dart` calls `configureUrlStrategy()` which on web enables `PathUrlStrategy` (clean `/scoreboard` URLs instead of `/#/scoreboard`). This requires Firebase Hosting's SPA rewrite (already configured in `firebase.json`) so deep links resolve. On non-web targets it's a no-op via the conditional-import shim.

**Firestore schema** is documented in `docs/SCHEMA.md`. Key idea: the player's session lives at `games/{gameId}/sessions/{uid}` so reads are O(1) and security rules trivially check `request.auth.uid == sessionDocId`. The scans collection is append-only for analytics.

**The scan transaction** (`SessionRepository.recordScan`) is the only place that mutates session state. It runs a Firestore transaction that: reads the session → validates no slot conflict and (optionally) no repeat-person conflict → writes the new slot + bumps `completedCount` → appends to `scans/`. All four steps commit atomically. Conflicts throw `ConflictException`, caught and returned as `Result.err`. The scanner's display name (`scannerName`) is denormalized into the session doc so the scoreboard doesn't need to join `users/`.

**QR protocol**: base64url-encoded JSON envelope with `app`/`type`/`signature` validation gates. Generator and scanner both go through `lib/features/qr/qr_payload.dart` so the format stays in lockstep. Bumping `QR_SIGNATURE` in `.env` invalidates every existing QR — useful to reset between events.

**Scoreboard**: `lib/features/scoreboard/` streams every session in the active game via `SessionRepository.watchAllSessions`, sorts client-side by `completedCount DESC, updatedAt ASC` (earliest finishers win ties), and renders a podium + leaderboard + winner banner. Bounded by attendee count (~200) so client-side sort is fine — no composite index needed. Designed for projector/fullscreen kiosk use; not linked from the bottom nav.

## Conventions

- **Theme**: never hard-code colors / spacing / radii. Pull from `lib/shared/theme/*`. The accent is `AppColors.accent` (neon green) and the surface palette is dark-first (`AppColors.background` / `surface` / `surfaceElevated`). If you find yourself reaching for `Color(0xFF...)` directly, add it to `AppColors` first.
- **Errors**: anything fallible at a boundary returns `Result<T>` (`lib/core/result.dart`). Inside the app, throw `AppException` subclasses (NotFoundException, ValidationException, ConflictException, etc.) — never raw `Exception`s.
- **Logging**: use `AppLogger.{d,i,w,e}` from `lib/core/logger.dart`. It defers to release-mode log-level rules and routes errors to Crashlytics on mobile.
- **Platform-specific code**: never `import 'dart:html'` or `'dart:io'` directly. Add a shim under `lib/core/platform/` with conditional imports (see `file_saver.dart` and `url_strategy.dart` for the pattern — facade, `_io.dart` for mobile/desktop, `_web.dart` guarded by `if (dart.library.html)`).
- **Models**: edits to any `@freezed` class require re-running `build_runner`. Adding fields with `@Default(...)` keeps existing Firestore docs readable without backfill.
- **`withOpacity` is intentional**, not a bug. The whole codebase uses it; analyze surfaces ~20 deprecation infos. Don't reflexively migrate to `withValues()` — leave the style consistent unless explicitly asked.
- **Animations**: stagger list/grid entries with `AnimatedEntry`. Tween counters on the kiosk with `AnimatedNumber`. One-shot celebrations use `ConfettiBurst`. Route transitions live in `lib/app/router.dart` as `_fadeSlidePage` / `_modalSlidePage` / `_shellFadePage` helpers — splash and scoreboard intentionally stay default.

## Environment knobs (.env)

| Key                            | Default          | Effect                                                  |
| ------------------------------ | ---------------- | ------------------------------------------------------- |
| `ACTIVE_GAME_ID`               | `default-game`   | Firestore doc id under `games/`                         |
| `ALLOW_REPETITIVE_PERSON_SCAN` | `false`          | If true, same person can fill multiple slots            |
| `QR_SIGNATURE`                 | `BINGO_USER_V1`  | Envelope signature; bump to invalidate all existing QRs |
| `VERBOSE_LOGGING`              | `false`          | Force debug-level logging in release builds             |

Restart the app after editing `.env` — hot reload doesn't re-read it.

## Things to know that aren't obvious from the code

- **Hosting site**: `firebase.json` pins `hosting.site` to `mako-bingo`. The site must exist (`firebase hosting:sites:create mako-bingo`); deploys with no `--only` deploy to that site only.
- **Web caching**: index.html is `no-cache`; hashed assets (`js`/`css`/fonts/images) are `max-age=31536000 immutable`. Forced hard refresh / service-worker unregister is needed after redeploys if the browser is sticky.
- **Crashlytics**: `firebase_crashlytics` doesn't support web — `bootstrap.dart` guards every Crashlytics call with `if (!kIsWeb)`.
- **`BoxSlot.questionText` is denormalized intentionally** — the question may be edited in Firestore later, but the player's board preserves what they actually saw at scan time.
- **`SessionModel.scannerName` is denormalized** for the scoreboard. Always set it from `currentUserProvider` when calling `recordScan` — falls back to `Player {first 4 of uid}` in the scoreboard if missing.
- **Slot count = number of active questions** in Firestore. There's no separate config — adding/removing questions grows/shrinks the board. The `slotCount` field on the game doc is metadata only; the UI uses `questions.length`.
- **The seed script (`scripts/seed_questions.mjs`)** is the only way to add or change questions. It uses `set({merge: true})` so re-runs overwrite by doc id; deleting questions requires manual cleanup or flipping `isActive: false`.
- **Camera on web requires HTTPS or localhost** — `flutter run -d chrome` is fine; deploying behind plain HTTP will silently break the scanner. Firebase Hosting is HTTPS by default.
- **`flutter_native_splash`** is configured in `pubspec.yaml` but isn't generated by default — run `dart run flutter_native_splash:create` when assets change.
- **`build.yaml` enables `explicit_to_json: true` globally** — required because Firestore's `StandardMessageCodec` doesn't recurse into nested Dart objects. Without this flag, writing a `SessionModel` (which contains `Map<String, BoxSlot>`) crashes with `Invalid argument: Instance of '_$BoxSlotImpl'`. Do NOT remove `build.yaml`. When adding a new `@freezed` model that nests other freezed types, you're already covered — just re-run `build_runner`.
- **QR scanner is tuned for reliability**, not detection breadth. `qr_scanner_screen.dart` uses `DetectionSpeed.noDuplicates` (not `normal`), forces `cameraResolution: 1920x1080`, and `_onDetect` *silently skips* QRs that don't decode as Bingo envelopes (no dialog interruption for noise QRs in frame). The QR payload deliberately excludes a `ts` field to keep modules sparse. Don't "fix" these to be more aggressive — each is a known reliability win.
- **Successful scans show a celebration overlay before popping** via `showScanSuccessOverlay()` (see `lib/features/qr/widgets/scan_success_overlay.dart`). The green flash on the camera is the lead-in; the overlay is the trophy moment; the dashboard tile pop is the closer. All three need to remain a single beat — don't insert async work between them.
