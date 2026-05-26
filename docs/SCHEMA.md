# Firestore Schema

## Layout

```
users/{uid}                              # public profile
games/{gameId}                           # event configuration
  questions/{questionId}                 # board prompts (ordered)
  sessions/{uid}                         # one player's progress
  scans/{scanId}                         # append-only scan log
```

The active game id is set via `.env` (`ACTIVE_GAME_ID`). Using a fixed id
keeps reads O(1) and avoids the composite index a `where isActive == true`
query would need.

## Collections

### `users/{uid}`

| Field         | Type      | Notes                                  |
| ------------- | --------- | -------------------------------------- |
| `name`        | string    | required, ≤80 chars                    |
| `email`       | string    | required, ≤120 chars                   |
| `company`     | string?   |                                        |
| `designation` | string?   |                                        |
| `linkedinUrl` | string?   | full URL                               |
| `createdAt`   | timestamp | set on first write                     |
| `updatedAt`   | timestamp | bumped on every write                  |

Profile photos are intentionally not stored — Firebase Storage was dropped
to avoid the Blaze-plan requirement for a one-day-event app. Avatars are
rendered as initial-letter circles via `ProfileAvatar`.

### `games/{gameId}`

| Field       | Type      | Notes                                          |
| ----------- | --------- | ---------------------------------------------- |
| `title`     | string    | event name (e.g. "Flutter Bengaluru Meetup")   |
| `isActive`  | bool      | drives whether the app accepts scans           |
| `slotCount` | int       | total bingo slots (e.g. 15)                    |
| `startsAt`  | timestamp |                                                |
| `endsAt`    | timestamp? |                                               |
| `createdAt` | timestamp |                                                |

### `games/{gameId}/questions/{questionId}`

| Field      | Type   | Notes                          |
| ---------- | ------ | ------------------------------ |
| `text`     | string | "Find someone who…"            |
| `order`    | int    | 1..N, used for stable ordering |
| `isActive` | bool   | hide without losing history    |

### `games/{gameId}/sessions/{uid}`

Doc id **is** the player's uid → O(1) "my progress" reads.

| Field            | Type                     | Notes                                       |
| ---------------- | ------------------------ | ------------------------------------------- |
| `uid`            | string                   | denormalized for security rules             |
| `gameId`         | string                   | denormalized for security rules             |
| `slots`          | map<string, BoxSlot>     | key = slot index as string ("1".."N")       |
| `completedCount` | int                      | denormalized — indexed for leaderboards     |
| `createdAt`      | timestamp                |                                             |
| `updatedAt`      | timestamp                |                                             |

`BoxSlot`:

| Field                  | Type      |
| ---------------------- | --------- |
| `slotIndex`            | int       |
| `scannedUid`           | string    |
| `scannedName`          | string    |
| `scannedLinkedinUrl`   | string?   |
| `questionId`           | string    |
| `questionText`         | string    |
| `scannedAt`            | timestamp |

`questionText` is denormalized intentionally — the question may be edited
in Firestore later, but the player's board should preserve what they
actually saw at scan time.

### `games/{gameId}/scans/{scanId}`

Append-only analytics log. Auto-id'd, written inside the same transaction
that updates the session.

| Field         | Type      |
| ------------- | --------- |
| `scannerUid`  | string    |
| `scannedUid`  | string    |
| `gameId`      | string    |
| `slotIndex`   | int       |
| `questionId`  | string    |
| `scannedAt`   | timestamp |

## Indexes

See `firestore.indexes.json`. Pre-declared composites:

- `questions`: `isActive ASC, order ASC` — drives the dashboard question list.
- `sessions`: `completedCount DESC, updatedAt DESC` — leaderboard.
- `scans`: `scannerUid ASC, scannedAt DESC` — "my recent connections".

## Seeding the first game

There is no in-app admin yet. Populate via Firebase Console or the CLI:

```bash
# Create the active game doc
firebase firestore:set games/default-game '{
  "title": "Namma Bingo",
  "isActive": true,
  "slotCount": 15,
  "createdAt": {"_seconds": 0, "_nanoseconds": 0}
}'
```

Then add 15 question docs at `games/default-game/questions/{questionId}`,
each with `{text, order, isActive: true}`. A small Node seed script is
the easiest path — see `scripts/seed_questions.mjs` (add when needed).

## Deploying rules and indexes

```bash
firebase deploy --only firestore:rules,firestore:indexes
```
