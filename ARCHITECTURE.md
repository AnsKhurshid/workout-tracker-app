# Gym Tracker v1.0 — Architecture

Status: **Phase 2 implemented** (foundation and authentication). Sections
about workouts, sync engine and analytics describe the design for later
phases. Each section says what exists today where it matters. Changes made
during Phase 2 are listed in [§17](#17-phase-2-changes-to-the-phase-1-design).

Related documents: [DATABASE_SCHEMA.md](DATABASE_SCHEMA.md) ·
[DEVELOPMENT_PLAN.md](DEVELOPMENT_PLAN.md) ·
[ENVIRONMENT_SETUP.md](ENVIRONMENT_SETUP.md) · [README.md](README.md)

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

Toolchain: **Flutter 3.47.9, Dart 3.13.7**. Versions below are what Phase 2
installed (see `pubspec.yaml` / `pubspec.lock`).

### Installed in Phase 2

| Concern | Package | Version | Why |
|---|---|---|---|
| State management | `flutter_riverpod` | ^3.4.3 | Required by spec. Plain providers/notifiers, no code generation. |
| Navigation | `go_router` | ^18.1.2 | Required by spec. `StatefulShellRoute` keeps each tab's stack and state. |
| Local DB | `drift`, `drift_flutter` | ^2.35.3, ^0.3.1 | Typed SQL, reactive streams, transactions, migrations. `drift_flutter` opens SQLite on a background isolate and bundles SQLite through the `sqlite3` package's build hooks. |
| Backend | `supabase_flutter` | ^2.18.3 | Auth + PostgREST. Persists the session for offline startup; handles auth deep links (PKCE). |
| IDs | `uuid` | ^4.6.0 | Client-generated UUIDv7 (used from Phase 3). |
| Codegen (dev) | `build_runner`, `drift_dev` | ^2.17, ^2.35 | Drift code generation and schema dumps. |
| Testing (dev) | `flutter_test`, `mocktail` | ^1.0.5 | Mocks for the Supabase auth client. Drift runs in memory. |
| Lints (dev) | `flutter_lints` | ^6.0.0 | Plus stricter rules in `analysis_options.yaml`. |
| Font | Inter (bundled asset, SIL OFL) | 4.1 | Clear figures for workout data; bundled so it works offline. |

### Planned for later phases (added only when needed)

| Package | Phase | Purpose |
|---|---|---|
| `fl_chart` | 5 | Progress charts |
| `intl` | 4/5 | Locale-aware dates and decimals |
| `connectivity_plus` | 6 | Hint to trigger a sync when a network appears |
| `flutter_local_notifications` | 4 | Rest timer alert while the phone is locked (open question 6) |

Deliberately **not** used:

* `flutter_dotenv`: it ships the `.env` file as an app asset, so it hides
  nothing. `.env` is read by `flutter run --dart-define-from-file=.env` at build
  time instead.
* `shared_preferences`: device settings live in Drift (`app_settings`), so
  there is one storage engine.
* `riverpod_generator` and `freezed`: dropped for now (see §17). Plain Riverpod
  and small hand-written immutable models are enough, and codegen is kept to
  Drift only.
* Any background-sync plugin, Supabase Storage, Realtime: not needed for v1.

---

## 4. Project structure

As implemented in Phase 2 (later phases add folders inside `features/`):

```
lib/
  main.dart                       # global error handlers, ProviderScope
  app.dart                        # startup gate → MaterialApp.router, theme mode
  core/
    config/env_config.dart        # build-time config + validation
    constants/app_constants.dart  # limits, deep link, names
    database/
      tables.dart                 # Drift tables (profiles, app_settings, sync_outbox, sync_cursors)
      app_database.dart(.g.dart)  # database, migrations, open()
    errors/
      app_failure.dart            # sealed failure types with user/debug messages
      error_mapper.dart           # the only place that knows 3rd-party exceptions
    logging/app_logger.dart       # redacting logger
    services/
      clock.dart                  # injectable clock
      id_generator.dart           # UUIDv7
      supabase_service.dart       # Supabase init + single client access point
    settings/app_settings_repository.dart   # device-level settings (theme)
    startup/                      # appStartupProvider, splash/error screens
    sync/
      outbox.dart                 # enqueue/coalesce/backoff helpers
      sync_tables.dart            # synced table names + push order
    theme/                        # palette, tokens, spacing, typography, AppTheme
    widgets/                      # buttons, fields, empty/error/skeleton, dialogs …
    providers.dart                # app-level dependency providers
  models/                         # AuthUser, UserProfile, WeightUnit, AppThemePreference
  features/
    authentication/ {domain, data, presentation/{controllers, screens, widgets}}
    profile/        {domain, data, presentation}
    home/           presentation/   # empty-state dashboard
    workout_plans/  presentation/   # placeholder (Phase 3)
    progress/       presentation/   # placeholder (Phase 5)
  routing/
    routes.dart  auth_redirect.dart  app_router.dart  scaffold_with_nav_bar.dart

test/                             # mirrors lib/ + helpers/ (fakes, in-memory DB, test app)
drift_schemas/                    # Drift schema snapshots for migration tests
supabase/migrations/              # Postgres schema (Phase 1)
assets/fonts/                     # Inter + licence
```

Inside each feature:

* `domain/` — repository interfaces and feature types. Pure Dart, no Flutter
  or package imports beyond `foundation`.
* `data/` — implementations over Drift and Supabase.
* `presentation/` — screens, widgets, Riverpod providers and controllers.

Shared entities used by several features live in `lib/models/`.

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

*Changed in Phase 2 (was: wipe the local database on sign-out).*

Signing out **never deletes local data**. Instead, user data is isolated by
owner:

* every user-owned local row carries the owner's id (`profiles.id`,
  `sync_outbox.user_id`, `sync_cursors.user_id`, and `user_id` on all workout
  tables from Phase 3);
* every repository query filters by the signed-in user's id, and the Riverpod
  providers that expose user data are keyed on the current user, so they rebuild
  (and drop the previous user's data from memory) when the user changes;
* unsynced changes stay in the outbox and are uploaded the next time that user
  signs in on the device.

Device-level settings (`app_settings`, e.g. theme) are shared by everyone using
the device.

---

## 8. Authentication

Implemented in Phase 2.

* **Supabase email + password** behind the `AuthRepository` interface
  (`SupabaseAuthRepository`). Screens and controllers never see Supabase types.
* **Status model:** `Unauthenticated(sessionExpired)`, `Authenticated(user)`,
  `PasswordRecovery(user)`, derived from Supabase's auth event stream.
* **Registration:** `signUp` with `display_name` in user metadata and
  `emailRedirectTo` = `com.anskhurshid.gymtracker://auth-callback`. The
  `handle_new_user` trigger creates the `profiles` row. If the project
  requires email confirmation, the app shows "Confirm your email". Otherwise
  the user is signed in immediately. An already-registered email is detected
  even when Supabase hides it (empty `identities`).
* **Login:** `signInWithPassword`. Errors are mapped to friendly messages
  (invalid credentials, unconfirmed email, rate limit, offline).
* **Password reset:** `resetPasswordForEmail` with the same redirect. Opening
  the link fires `passwordRecovery`, and the router allows only the "Choose a
  new password" screen until `updateUser(password)` succeeds or the user
  cancels (signs out).
* **Flow type:** PKCE, so deep links carry a one-time code, not tokens.
* **Session:** persisted by `supabase_flutter` and auto-refreshed. A
  previously signed-in user can open the app offline. If the refresh token is
  rejected, Supabase signs out with a non-user reason, and the app returns to
  Welcome with "Your session has expired".
* **Logout:** clears the session on the device first, then revokes it on the
  server. Offline, the revoke fails quietly and the user is still signed out.
  Local data is kept (§7.7).
* **Route guards:** one pure function, `authRedirect(status, location)`, run by
  GoRouter on navigation and whenever the auth status changes (via
  `refreshListenable`). The router is created once and widgets never check
  auth themselves.

### Profile (Phase 2)

* `ProfileRepositoryImpl` is local-first. On sign-in it ensures a local row
  exists. Offline, it creates a placeholder from sign-up metadata, marked as
  older than any server row and never queued. It then refreshes from
  Supabase.
* Edits (display name, KG/LBS) update the local row and enqueue an outbox
  entry in one transaction, then try to upload right away. On failure the
  entry stays queued with exponential backoff. Network errors stay
  `pending`. Rejections are marked `failed` and kept, never dropped.
* A server row only replaces local data if no newer local change is waiting.
* Phase 6 replaces the direct upload with the general sync engine. The
  repository then only writes locally.

---

## 9. Navigation

Routes marked ✓ exist after Phase 2. The rest are planned.

```
✓ /welcome  /login  /register  /register/check-email  /forgot-password
✓ /reset-password                          (only reachable during password recovery)
  /syncing                                 (first pull after sign-in, Phase 6)
✓ StatefulShellRoute.indexedStack (bottom nav, each tab keeps its own stack)
✓ /home
✓ /workouts                                (placeholder until Phase 3)
      /workouts/plans/new
      /workouts/plans/:planId              (view/edit, reorder exercises)
      /workouts/plans/:planId/exercises/:planExerciseId
      /workouts/exercises                  (library: search + filter)
      /workouts/exercises/new
      /workouts/exercises/:exerciseId
      /workouts/history
      /workouts/history/:workoutId         (view/edit past workout)
✓ /progress                                (placeholder until Phase 5)
      /progress/exercises/:exerciseId
✓ /profile
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

* `SUPABASE_URL` and `SUPABASE_PUBLISHABLE_KEY` are passed at build time:
  `flutter run --dart-define-from-file=.env`, and read with
  `String.fromEnvironment` in `EnvConfig`.
* `.env.example` is committed. `.env` is git-ignored.
* The publishable (or legacy anon) key is designed to be public. Security comes
  from RLS. The secret/service-role key is **never** used in the app.
* Startup validates the configuration. If it is missing or still holds the
  placeholders, the app shows a "Configuration required" screen listing the
  problems instead of crashing or silently running without a backend.

### Startup sequence

`appStartupProvider` runs behind a splash screen:

1. validate `EnvConfig`;
2. open (and migrate) the local database on its background isolate;
3. initialise Supabase, which restores a saved session and works offline.

Any failure shows an error screen with **Try again**. A database failure never
deletes the database.

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

Implemented in Phase 2.

* `AppFailure` (sealed): `NetworkFailure`, `AuthFailure(kind)`,
  `ValidationFailure`, `StorageFailure`, `ConfigurationFailure`,
  `UnexpectedFailure`. Each has a `userMessage` (safe to show) and a
  `debugMessage` (for logs).
* `mapError()` is the only code that knows Supabase, socket, Postgrest and
  SQLite exception types. Repositories throw `AppFailure`s, controllers expose
  them as `AsyncError`, and widgets show `userMessage`.
* `AppLogger` redacts emails, JWTs, bearer/API keys and token query parameters
  before writing. `FlutterError.onError` and `PlatformDispatcher.onError`
  route uncaught errors to it, so nothing is swallowed silently.
* Validation rules are defined once (`Validators`, mirrored by database CHECK
  constraints).
* Sync errors never block the UI. A pending profile change shows "Saved on
  this device, waiting to sync".

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

## 17. Phase 2 changes to the Phase 1 design

| Change | Reason |
|---|---|
| Sign-out keeps local data, isolated by user id, instead of wiping the database. | Phase 2 requirement: "do not delete user data merely because the user logs out". It also avoids losing unsynced changes. |
| Config file is `.env` (via `--dart-define-from-file`), not `env/*.json`. | Phase 2 asked for `.env.example`. Flutter reads `.env` files natively, so no extra package is needed. |
| `SUPABASE_PUBLISHABLE_KEY` instead of `SUPABASE_ANON_KEY`. | `supabase_flutter` 2.18 deprecates `anonKey` in favour of `publishableKey`. The legacy anon key still works as the value. |
| No `riverpod_generator` / `freezed`. | Fewer dependencies and a single codegen step (Drift). Can be added later without restructuring. |
| Drift stores `DateTime` as ISO-8601 text (not integer milliseconds). | Drift's integer mode keeps only whole seconds. Text keeps milliseconds and stays sortable. |
| App id / bundle id `com.anskhurshid.gymtracker` (was `gym_tracker` / `gymTracker`). | URL schemes cannot contain underscores. Using one identifier everywhere keeps the deep link consistent. |
| Theme preference is per device, weight unit is per account. | Theme is needed before sign-in (welcome screen). Weight unit is part of the synced profile. |
