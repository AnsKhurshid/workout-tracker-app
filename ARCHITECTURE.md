# Gym Tracker v1.0 — Architecture

Status: **Proposed (Phase 1)**. Nothing in this document is implemented yet
except the Flutter scaffold and the draft SQL migrations. Sections marked
**Open question** need a product decision before the relevant phase starts.

Related documents: [DATABASE_SCHEMA.md](DATABASE_SCHEMA.md) ·
[DEVELOPMENT_PLAN.md](DEVELOPMENT_PLAN.md) · [README.md](README.md)

---

## 1. Goals that drive the design

| Principle | What it means for the architecture |
|---|---|
| **Reliability** | The on-device SQLite database is the source of truth for everything the user does. Every change is written locally first, inside a transaction, before anything else happens. The network is an optional, asynchronous side effect. |
| **Simplicity** | Logging a set is one tap on the active workout screen. The UI reads reactive streams from the local database, so it never waits for the network. |
| **Flexibility** | Templates (plans) and history (sessions) are separate tables. A session is a snapshot copied from a plan at start, so plans can change freely. |
| **Extensibility** | Feature modules with a fixed internal layering; a generic sync engine driven by a table registry; theme tokens instead of hard-coded styles. New features (v2 supersets, body weight, etc.) add modules and tables rather than restructuring. |

---

## 2. System overview

```
┌──────────────────────────── Flutter app ─────────────────────────────┐
│                                                                      │
│  Presentation      Screens & widgets  ──watch──▶  Riverpod providers │
│  (features/*/presentation)                        (controllers)      │
│                                                        │             │
│  Domain            Models · repository interfaces · pure services    │
│  (models/, features/*/domain)   (1RM, volume, unit conversion, ...)  │
│                                                        │             │
│  Data              Repository implementations ──▶ Drift DAOs         │
│  (features/*/data)            (every write also enqueues an          │
│                                outbox entry in the same transaction) │
│                                                        │             │
│  Core              Drift database (SQLite)   ◀──▶   Sync engine      │
│                                                        │             │
└────────────────────────────────────────────────────────┼─────────────┘
                                                         │ HTTPS (PostgREST)
                                               ┌─────────▼─────────┐
                                               │     Supabase      │
                                               │  Auth · Postgres  │
                                               │  (RLS on all      │
                                               │   tables)         │
                                               └───────────────────┘
```

Rules that keep this clean:

1. **Widgets never touch Drift or Supabase.** They watch Riverpod providers.
2. **Controllers never touch Drift or Supabase.** They call repositories.
3. **Repositories only touch the local database.** They never call Supabase for
   data. This is what makes every feature work offline by construction.
4. **Only the sync engine talks to Supabase PostgREST.** Only the auth service
   talks to Supabase Auth.
5. **Business rules live in the domain layer** as plain Dart (no Flutter
   imports), so they are unit-testable without widgets or a database.

---

## 3. Technology choices

All versions were checked against pub.dev on 2026-11-02 and are compatible with
the installed toolchain (**Flutter 3.47.9, Dart 3.13.7**). Exact constraints are
added to `pubspec.yaml` in Phase 2.

| Concern | Package | Version | Why |
|---|---|---|---|
| State management | `flutter_riverpod`, `riverpod_annotation` | ^3.4, ^4.0 | Required by spec. Riverpod 3 with code-generated providers gives compile-time safety and automatic disposal. |
| Navigation | `go_router` | ^18.1 | Required by spec. `StatefulShellRoute` preserves each tab's stack. |
| Local DB | `drift`, `drift_flutter` | ^2.35, ^0.3 | Typed SQL, reactive `watch()` streams, real transactions, migrations with schema verification. `drift_flutter` bundles SQLite via the `sqlite3` native-assets build (the old `sqlite3_flutter_libs` is end-of-life). |
| Backend | `supabase_flutter` | ^2.18 | Auth + PostgREST client; persists the session securely for offline startup. |
| Charts | `fl_chart` | ^1.3 | Mature, no native deps, enough for line/bar progress charts. |
| IDs | `uuid` | ^4.6 | Client-generated **UUIDv7** (time-ordered, so B-tree indexes stay compact). |
| Immutable models | `freezed`, `freezed_annotation` | ^4.0, ^3.1 | `copyWith`/equality for domain models without hand-written boilerplate. |
| Connectivity hint | `connectivity_plus` | ^7.3 | Triggers a sync attempt when a network appears. It is only a hint: sync success is decided by the actual request. |
| Formatting | `intl` | ^0.20 | Dates, durations, decimal weights in the user's locale. |
| Rest timer alert | `flutter_local_notifications` | ^22.3 | **Open question 6.** Lets the timer alert when the app is backgrounded. |
| Codegen (dev) | `build_runner`, `drift_dev`, `riverpod_generator`, `freezed` | | One `build_runner` pipeline for all generated code. |
| Testing (dev) | `flutter_test`, `mocktail` | ^1.0 | Mocks for repository/service boundaries; Drift runs in-memory for repository tests. |
| Lints (dev) | `flutter_lints` (already present), `riverpod_lint` | ^6.0, ^3.1 | |

Deliberately **not** used:

* `flutter_dotenv`: it ships the `.env` file as an app asset, so it hides
  nothing. We use `--dart-define-from-file` instead (see §11).
* `shared_preferences`: small settings and timer state live in Drift, so there
  is one storage engine with transactional guarantees.
* Any background-sync plugin (`workmanager` etc.): sync runs while the app is in
  the foreground and on resume, which covers the v1 requirement without extra
  platform setup.
* Supabase Storage and Realtime: not needed for v1.

---

## 4. Project structure

```
lib/
  main.dart                     # bootstrap: env, Supabase.initialize, ProviderScope
  app.dart                      # MaterialApp.router, theme, router
  core/
    constants/                  # limits (max reps, max weight), durations, keys
    theme/                      # AppTheme (dark + light), AppTokens ThemeExtension
    database/
      app_database.dart         # @DriftDatabase, migrations
      tables/                   # one file per table (mirrors Postgres + local-only)
      daos/                     # query groups per aggregate
    sync/
      sync_engine.dart          # push/pull loop, retry/backoff
      sync_registry.dart        # table order + (de)serialisers
      outbox.dart               # enqueue/coalesce helpers used by repositories
    services/
      auth_service.dart         # wraps Supabase Auth
      connectivity_service.dart
      clock.dart                # injectable clock (testable timestamps)
      id_generator.dart         # UUIDv7
    utils/                      # weight conversion, formatting, Result type
    widgets/                    # AppCard, PrimaryButton, EmptyState, ErrorState,
                                # Skeleton, ConfirmDialog, NumberStepperField ...
  models/                       # shared domain models (Exercise, WorkoutPlan,
                                # PlanExercise, Workout, WorkoutSet, Weight, ...)
  features/
    authentication/   {data, domain, presentation}
    home/             {domain, presentation}
    workout_plans/    {data, domain, presentation}
    exercise_library/ {data, domain, presentation}
    active_workout/   {data, domain, presentation}   # incl. rest timer
    workout_history/  {data, domain, presentation}
    progress/         {data, domain, presentation}
    profile/          {data, domain, presentation}
  routing/
    app_router.dart             # GoRouter + redirects
    routes.dart                 # typed route names/paths

test/                           # mirrors lib/; unit + widget tests
integration_test/               # end-to-end flows on device/emulator
supabase/
  migrations/                   # ordered SQL migrations (Supabase CLI layout)
  tests/                        # SQL tests for RLS and constraints
env/
  example.json                  # template for --dart-define-from-file
```

Inside each feature:

* `domain/` — repository interface(s), use-case style services with business
  rules, feature-only models. Pure Dart.
* `data/` — repository implementation over Drift DAOs, mapping DB rows ⇄
  domain models.
* `presentation/` — screens, widgets, Riverpod controllers (`Notifier` /
  `AsyncNotifier`) and providers.

Shared entities used by several features (an `Exercise` appears in the library,
plans, workouts and progress) live in `lib/models/` to avoid duplicate types.

---

## 5. Domain model: templates vs sessions vs history

This is the most important separation in the app.

```
TEMPLATES (editable any time)          SESSIONS / HISTORY (snapshot)

WorkoutPlan                             Workout  (status: in_progress | completed | abandoned)
  └─ PlanExercise ─────┐                  └─ WorkoutExercise  (name, weight flag, rest,
       (exercise ref,  │   copied at          instructions copied from plan)
        rest, notes)   │   workout start        └─ WorkoutSet   (target_* copied from plan,
       └─ PlanExerciseSet ──────────────────────▶   weight/reps = what the user did)
            (type, target reps,
             target weight)
```

* **A plan is a template.** Editing, reordering or deleting anything in it
  affects only future workouts.
* **Starting a workout copies the template** into `workouts` →
  `workout_exercises` → `workout_sets` in a single local transaction. The copy
  includes the exercise name, the weight flag, rest seconds, instructions and
  the per-set targets. From that moment the session has no live dependency on
  the plan; `plan_id` / `plan_exercise_id` are kept only as provenance links
  (and are nulled, not cascaded, if the plan row is ever hard-deleted).
* **An in-progress workout and a completed workout are the same rows** with a
  different `status`. Completing a workout is a status change plus `ended_at`,
  so there is no risky "move to history" step that could lose data.
* **Quick Start** creates a workout with no plan; exercises are added during the
  session.
* **Editing history** edits the session rows directly. It never touches plans.
* **Deleting** plans, custom exercises and workouts is a soft delete
  (`deleted_at`), which is what lets the delete sync and lets history keep its
  references.

### Weight handling

* Stored canonically as **kilograms**, `numeric(8,3)` on the server and `REAL`
  rounded to 3 decimals locally, wrapped in a `Weight` value object in Dart.
* Input and display convert using the profile's unit (1 lb = 0.45359237 kg
  exactly). 3 decimals of kg round-trips any 0.01 lb input exactly at display
  precision.
* Changing the preferred unit only changes display; historical rows are never
  rewritten (business rule 10).
* `weight_kg` is nullable: exercises without external weight store `null`.

### Calculations (domain services, pure Dart)

| Metric | Definition |
|---|---|
| Estimated 1RM | Epley: `weight × (1 + reps / 30)`, per completed working set; the session's best value is plotted. Labelled "Estimated 1RM" everywhere. Not computed for bodyweight exercises or reps = 0. |
| Volume | `Σ weight_kg × reps` over **completed working sets** (warm-ups excluded). For exercises without external weight, the progress screen shows total reps instead. |
| Weight progression | Heaviest completed working-set weight per session. |
| Rep progression | Best reps per session (and total reps for bodyweight). |
| Previous performance | All completed sets (ordered) from the **most recent completed, non-deleted** workout that contains the same `exercise_id`, excluding the current workout. |

---

## 6. Local-first data flow

Every user action follows the same path:

```
UI event
  → Controller.method()
    → Repository.method()
      → db.transaction(() {
           write domain rows (with new updated_at)
           outbox.enqueue(table, id)        // same transaction
         })
  → Drift watch() streams emit → UI rebuilds
  → SyncEngine.schedule()                    // fire-and-forget, debounced
```

Because the local write and its outbox entry commit together, there is no
window where a change exists locally but is not queued for sync, or vice versa.

### Active workout specifics

* Each set edit is persisted when the field is committed (debounced ~300 ms while
  typing, immediately on "complete set"). Killing the app loses at most the
  in-flight keystrokes of one field.
* On launch, the router checks for a local `in_progress` workout. If one exists,
  a persistent "Resume workout" bar appears on every tab, and the active workout
  screen restores exactly where the user was.
* Only one `in_progress` workout is allowed per user. This is enforced in the
  local repository, not as a server constraint, so two offline devices can never
  produce a sync error that blocks data. If the server ever ends up with two,
  the app shows both and lets the user finish or abandon each.

---

## 7. Synchronisation design

### 7.1 Principles

* **Idempotent pushes.** Every row has a client-generated UUID and is pushed as
  an `upsert` on `id`. Retrying a push can never create a duplicate.
* **Row-level last-write-wins on `updated_at`,** enforced by the server trigger
  `sync_guard()`: an upsert older than the stored row becomes a no-op, so an old
  offline edit cannot overwrite a newer one. Future-dated timestamps are clamped
  to server time to limit damage from a wrong device clock.
* **Fine-grained rows limit conflicts.** Sets, exercises and sessions are
  separate rows, so editing set 2 on one device and set 3 on another never
  conflicts.
* **Deletes are tombstones** (`deleted_at`) and are sticky on the server: a
  stale device cannot resurrect a deleted row.
* **Nothing is silently dropped.** Rows the server rejects permanently are kept
  locally, marked failed, and surfaced in Profile → Sync status.

### 7.2 Local bookkeeping tables (SQLite only)

| Table | Purpose |
|---|---|
| `sync_outbox` | One row per *(table, record_id)* awaiting push: `enqueued_at`, `attempts`, `next_attempt_at`, `last_error`, `state` (`pending`/`failed`). Re-editing a queued row just bumps the existing entry (coalescing). |
| `sync_cursors` | Per table: the last `server_updated_at` seen by pull. |
| `app_state` | Key/value for local-only state: rest timer, last sync time, onboarding flags. |

### 7.3 Push

1. Read up to N pending outbox entries whose `next_attempt_at` has passed.
2. Group by table and push **in dependency order**: `profiles`, `exercises`,
   `workout_plans`, `plan_exercises`, `plan_exercise_sets`, `workouts`,
   `workout_exercises`, `workout_sets`. Parents always reach the server before
   children, so foreign keys hold.
3. For each table, read the *current* local rows (not a stored payload) and
   send one batched `upsert`.
4. On success, delete those outbox entries **only if** the row's `updated_at`
   has not changed since it was read (otherwise a newer edit is waiting and the
   entry stays).
5. On failure, classify:
   * network / 5xx / timeout → retry with exponential backoff plus jitter
     (5 s → 10 min cap);
   * auth (401) → refresh session, retry; if refresh fails, pause sync and ask
     the user to sign in again (local data is kept);
   * constraint / RLS (4xx) → fall back to row-by-row to isolate the bad row,
     mark only that one `failed` with the error, and continue with the rest.

### 7.4 Pull

1. For each table in the same order, request rows with
   `server_updated_at > cursor − 2 min` (a small overlap window, safe because
   applying a row is idempotent), paginated by `server_updated_at, id`.
2. For each incoming row:
   * if there is **no pending outbox entry** for it, write it locally;
   * if there **is** one, keep whichever has the newer `updated_at` (the local
     one will be pushed; the server would ignore an older one anyway).
3. Advance the cursor to the max `server_updated_at` received.

RLS limits pulls to the user's own rows plus system exercises.

### 7.5 When sync runs

* After every local write (debounced ~2 s).
* On app start and on resume from background.
* When `connectivity_plus` reports a network.
* Manually via pull-to-refresh / "Sync now" in Profile.

A single-flight lock ensures only one sync runs at a time.

### 7.6 Initial sign-in

After sign-in the app pulls everything (system exercises, then the user's data)
with a progress indicator. The full history is kept locally: even heavy use
produces only a few thousand set rows per year, and having it locally makes
history, previous performance and progress charts instant and fully offline.

### 7.7 Sign-out and multiple accounts

User-specific data isolation on a shared device: on sign-out the local
database is wiped. If unsynced changes exist, the app first tries to sync and,
if that fails, warns the user and requires explicit confirmation before
discarding them (never silently).

---

## 8. Authentication

* Supabase email + password: register, log in, log out, password reset.
* A profile row is created by a database trigger on sign-up
  (`handle_new_user`), using the display name passed as sign-up metadata.
* The Supabase session is persisted on device, so a previously signed-in user
  can open and use the app fully offline. Sign-in and registration themselves
  require a network.
* Password reset uses Supabase's email link with a deep link back into the app
  (`com.anskhurshid.gymtracker://auth-callback`), which opens a "set new
  password" screen. Needs redirect URL configuration (see README).
* GoRouter `redirect` guards: unauthenticated → `/auth/*`; authenticated and
  first sync pending → `/syncing`; otherwise the shell.

---

## 9. Navigation

```
/auth/login  /auth/register  /auth/forgot-password  /auth/reset-password
/syncing                                   (first pull after sign-in)
StatefulShellRoute (bottom nav, each tab keeps its own stack)
  /home
  /workouts
      /workouts/plans/new
      /workouts/plans/:planId              (view/edit, reorder exercises)
      /workouts/plans/:planId/exercises/:planExerciseId
      /workouts/exercises                  (library: search + filter)
      /workouts/exercises/new
      /workouts/exercises/:exerciseId
      /workouts/history
      /workouts/history/:workoutId         (view/edit past workout)
  /progress
      /progress/exercises/:exerciseId
  /profile
      /profile/settings
      /profile/sync
/workout/active                            (full-screen, outside the shell)
```

Workout history lives under the Workouts tab (it is reachable from Home's
"Recent activity" too), since the spec fixes the four tabs.

A compact "active workout bar" (workout name, elapsed time, rest timer) sits
above the bottom nav whenever a workout is in progress, so the user can browse
freely and jump back in one tap.

---

## 10. UI architecture

* **Material 3**, dark-first. `AppTheme.dark()` and `AppTheme.light()` are both
  built from the same seed and the same `AppTokens` `ThemeExtension` (spacing
  scale, radii, semantic colours such as `setCompleted`, `warmup`, `pr`). v1
  ships dark; switching to light later is a `ThemeMode` change, not a refactor.
* Proposed accent: a vivid lime/green (`#B6F36A` family) on near-black surfaces;
  it reads well in a gym and distinguishes "completed" states clearly. Easy to
  change in one place.
* Shared widgets in `core/widgets`: cards, buttons, numeric input with steppers,
  empty/error states, skeleton loaders, confirm dialogs, section headers.
* Every screen is built from an `AsyncValue` and handles loading, empty, error
  and data states explicitly.

### Active workout screen (highest priority)

One scrollable page; no navigation needed to log a set.

```
┌───────────────────────────────────────┐
│ Push Day            00:42:15   Finish │  header: name, elapsed, finish
├───────────────────────────────────────┤
│ Barbell Bench Press            ⋮      │  1. exercise name (menu: notes,
│ Last time: 40×12 · 45×10 · 45×8       │     skip, reorder, remove)
│                                       │  2. previous performance inline
│  SET  PREV     KG      REPS     ✓     │
│  W    20×10   [ 20 ]  [ 10 ]   (✓)    │  3. set rows: big tap targets,
│  1    40×12   [ 42.5] [ 12 ]   (✓)    │     numeric keypad, per-set weight
│  2    45×10   [ 45 ]  [ 10 ]   ( )    │  4. one tap completes the set
│  + Add set                            │
├───────────────────────────────────────┤
│ Next: Incline Dumbbell Press          │  6. next exercise preview
├───────────────────────────────────────┤
│ Rest 01:12   ▌▌  +15s  Skip           │  5. rest timer (sticky)
└───────────────────────────────────────┘
```

---

## 11. Configuration and secrets

* Supabase URL and anon key are passed at build time:
  `flutter run --dart-define-from-file=env/dev.json`.
* `env/example.json` is committed; real `env/*.json` files are git-ignored.
* The anon key is designed to be public; security comes from RLS. The service
  role key is **never** used in the app.
* The app refuses to start (with a clear developer error) if the defines are
  missing, rather than silently running without a backend.

---

## 12. Rest timer

* State: `{ totalSeconds, endsAt | null, pausedRemaining | null }`, persisted in
  `app_state` on every change.
* Remaining time is always computed as `endsAt − now`, never by counting ticks,
  so it stays accurate across backgrounding, process death and restarts.
* A UI ticker (once per second while visible) only triggers repaints.
* Auto-start after completing a set uses the exercise's `rest_seconds` if
  `auto_start_rest_timer` is enabled in the profile.
* Controls: start, pause, resume, skip, ±15 s.
* **Open question 6:** schedule a local notification at `endsAt` so the user is
  alerted while the phone is locked.

---

## 13. Error handling

* Repositories return typed results/throw typed failures (`ValidationFailure`,
  `NotFoundFailure`, `StorageFailure`); controllers convert them to user-facing
  messages.
* Validation (reps 0–999, weight 0–2000 kg, name lengths) is defined once in
  the domain layer and mirrored by database CHECK constraints as a safety net.
* Sync errors never block the UI; they show as a small status indicator and in
  Profile → Sync status.
* Unexpected errors are caught at the zone/`FlutterError.onError` level and
  logged (crash reporting service is out of scope for v1).

---

## 14. Testing strategy

| Layer | How |
|---|---|
| Domain (1RM, volume, unit conversion, validation, previous performance selection, streaks) | Pure Dart unit tests. |
| Repositories (plan CRUD, duplication, snapshotting, set logging, completion, history edits, outbox enqueueing) | Drift `NativeDatabase.memory()` — real SQL, no mocks. |
| Sync engine (ordering, idempotency, LWW, retry/backoff, failure isolation, pull merge) | Fake remote data source implementing the same interface as the Supabase one; injectable clock. |
| Auth | `AuthService` behind an interface; controllers tested with mocks; redirect logic unit-tested. |
| RLS and constraints | SQL tests in `supabase/tests/` run against a local Supabase (`supabase start` + `supabase test db`, pgTAP). |
| Widgets | Key screens (active workout, plan editor) with provider overrides. |
| Integration | `integration_test/`: register → create plan → start workout → log sets → kill/restore → complete → history, against a local Supabase. |

---

## 15. Key decisions (summary)

| # | Decision | Alternatives considered |
|---|---|---|
| D1 | Local SQLite is the source of truth; repositories never call the network. | Online-first with cache: fails the reliability goal. |
| D2 | Sessions are snapshots of plans; in-progress and completed workouts share tables, distinguished by `status`. | Separate "active" tables moved to history on completion: more code, a risky move step. |
| D3 | Client-generated UUIDv7 primary keys everywhere. | Server serial IDs: impossible offline. |
| D4 | Transactional outbox + row-level LWW (server-enforced) + tombstones. | Field-level merge / CRDTs: unnecessary for single-user data at this granularity. |
| D5 | `user_id` on every table plus composite `(parent_id, user_id)` FKs. | RLS via joins to parents: slower and easier to get wrong. |
| D6 | Weights canonical in kg, unit is display-only. | Store as entered + unit: complicates every aggregate. |
| D7 | `plan_exercise_sets` table for per-set templates. | `default_sets`/`default_reps` columns: cannot express warm-ups or pyramids. |
| D8 | No unique constraints on user-entered names on the server. | Unique names: permanent sync failures when two devices create the same name offline. |
| D9 | `--dart-define-from-file` for config. | `flutter_dotenv`: no real secrecy, extra dependency. |
| D10 | Full history synced locally. | Paginated remote history: breaks offline history/progress. |

## 16. Open questions

See the list at the end of [DEVELOPMENT_PLAN.md](DEVELOPMENT_PLAN.md#open-questions-for-approval).
