# Namma Bingo

A networking bingo for events. Each player generates a personal QR code;
scanning someone else's fills a slot tied to a prompt ("Find someone who…").
Backend is Firebase (Anonymous Auth + Firestore), client is Flutter
targeting Web, Android, and iOS. Profile photos are intentionally not
stored — see SCHEMA.md for the rationale.

## Stack

- **Flutter** + Material 3 dark theme.
- **Riverpod 2** for state — `StreamProvider` for Firestore streams,
  `AsyncNotifier` for write actions.
- **go_router** with auth-aware redirects and custom page transitions
  (fade/slide for top-level routes, cross-fade for shell tab swaps).
- **Firebase**: Anonymous Auth, Firestore (rules + indexes committed),
  Crashlytics (mobile only — Web isn't supported).
- **QR**: `mobile_scanner` (ML Kit on Android, AVFoundation on iOS,
  Barcode Detection API on Web) for scanning; `qr_flutter` for generation.
  Scanner uses `DetectionSpeed.noDuplicates` + 1080p capture and silently
  ignores non-Bingo QRs in frame for fewer false-positive dialogs.
- **Models**: `freezed` + `json_serializable` with `explicit_to_json: true`
  enabled globally via `build.yaml` (required so Firestore writes
  recursively serialize nested freezed objects). Run codegen before the
  first build.

## Setup

```bash
# 1. Install Flutter deps
flutter pub get

# 2. Run code generators (freezed/json_serializable)
dart run build_runner build --delete-conflicting-outputs

# 3. Configure Firebase (firebase_options.dart is committed; if you fork,
#    regenerate with `flutterfire configure`)

# 4. Seed the first game's questions into Firestore (one-time)
#    – Download a service account key from Firebase Console
cd scripts && npm install
GOOGLE_APPLICATION_CREDENTIALS=./service-account.json npm run seed

# 5. Deploy security rules + indexes
firebase deploy --only firestore:rules,firestore:indexes
```

## Run

```bash
flutter run -d chrome                          # web (camera needs HTTPS or localhost)
flutter run -d <android-device-id>             # android
flutter run -d <ios-device-id>                 # ios
flutter analyze                                # lint
flutter test                                   # unit + widget tests
flutter test test/widget_test.dart             # single file
flutter build web                              # production web build
firebase deploy --only hosting                 # deploy build/web
```

After codegen, the `*.freezed.dart` and `*.g.dart` siblings of model files
must exist or the build fails. Re-run `dart run build_runner build` any
time you edit a `@freezed` class.

## Project layout

```
lib/
  app/                       MaterialApp, router, bootstrap
  core/                      Result, AppException, Logger, Env, platform shims
  data/
    models/                  freezed + json_serializable
    repositories/            UserRepo, GameRepo, QuestionRepo, SessionRepo
    sources/                 firestore_service
  features/
    auth/                    anonymous auth, providers, splash gate
    bingo/                   dashboard, slot grid, providers
    network/                 connections list
    onboarding/              required first-run profile
    profile/                 view/edit profile
    qr/                      generator + scanner + payload
      widgets/               scan_success_overlay (celebration after a scan)
    scoreboard/              kiosk view at /scoreboard (podium + leaderboard)
    shell/                   bottom-nav shell
    splash/                  splash screen
  shared/
    theme/                   AppColors, AppTypography, AppSpacing, AppRadius, AppTheme
    widgets/                 AppButton, AppCard, AppSkeleton, AppTextField,
                             AppEmptyState, AppErrorState, ProfileAvatar,
                             AnimatedEntry, AnimatedNumber, ConfettiBurst
  main.dart                  → bootstrap()

scripts/
  seed_questions.mjs         one-shot Firestore seeder (firebase-admin)
docs/
  SCHEMA.md                  Firestore collections + indexes reference
firestore.rules              security rules (deploy with firebase CLI)
firestore.indexes.json       composite indexes
build.yaml                   forces explicit_to_json so Firestore writes
                             recursively serialize nested freezed types
```

## How the QR protocol works

The generator emits a base64url-encoded JSON envelope:

```json
{
  "app": "namma_bingo_app",
  "signature": "BINGO_USER_V1",
  "type": "bingo_user",
  "uid": "...",
  "name": "...",
  "linkedinUrl": "..."
}
```

The scanner validates `app`/`type`/`signature` before accepting the
payload. Anything that doesn't decode as a Bingo envelope is silently
skipped (no dialog) so noise QRs in frame don't interrupt aiming —
only "real" errors (own QR, slot conflict) surface as dialogs. To
invalidate every existing QR (e.g. before a new event), bump
`QR_SIGNATURE` in `.env`.

After a successful scan, a green flash plays over the camera, a
full-screen celebration overlay (`showScanSuccessOverlay`) shows the
scanned person's avatar + name + the prompt they satisfied, and the
matching dashboard tile pops with a scale animation. The three are
choreographed as one beat — don't insert async work between them.

## How state stays consistent

Every scan goes through `SessionRepository.recordScan`, which runs a
Firestore transaction that:

1. Reads the player's session doc.
2. Checks the target slot isn't filled and the person isn't already
   scanned (unless `ALLOW_REPETITIVE_PERSON_SCAN=true`).
3. Writes the new slot + bumps `completedCount`.
4. Appends to `games/{gameId}/scans/` for analytics.

All four steps commit atomically. Conflicts surface as
`ConflictException` and become a friendly retry dialog.

## Live scoreboard

Open `/scoreboard` in a separate browser window (typically projected
fullscreen at events) for a kiosk view: gold/silver/bronze podium for
the top three, real-time leaderboard for ranks 4+, animated number
counters, a one-shot winner banner with a confetti burst, and an
ambient accent-gradient background. The route bypasses the standard
auth redirect — it handles its own loading state, so opening the URL
on a fresh device works. Bounded by attendee count (~200), so sorting
client-side stays cheap; no composite index needed.

## License

Educational / demo project. Not licensed for production redistribution.
