# Gym Tracker v1.0 — Development Plan

Work proceeds in seven phases. Each phase ends with a pull request, a summary
(what was built, files changed, test results, outstanding items) and **explicit
approval before the next phase starts**.

Status legend: ✅ done · 🟡 in review · ⬜ not started

| Phase | Scope | Status |
|---|---|---|
| 1 | Analysis and planning | 🟡 |
| 2 | Foundation | ⬜ |
| 3 | Workout management | ⬜ |
| 4 | Workout execution | ⬜ |
| 5 | History and analytics | ⬜ |
| 6 | Offline synchronisation | ⬜ |
| 7 | Testing and polishing | ⬜ |

---

## Phase 1 — Analysis and planning 🟡

**Findings from inspection (2026-11-02)**

* The GitHub repository `AnsKhurshid/workout-tracker-app` was empty (no
  commits).
* The local folder `C:\Users\Kavtech\Desktop\gym-tracker` could not be inspected
  because the computer was not reachable at the time. If it contains existing
  work, it should be compared with this repository before Phase 2.

**Delivered**

* Flutter project initialised: `flutter create --org com.anskhurshid
  --project-name gym_tracker --platforms android,ios` (Flutter 3.47.9 stable,
  Dart 3.13.7). The default counter app is left untouched; it is replaced in
  Phase 2.
* `ARCHITECTURE.md`, `DATABASE_SCHEMA.md`, this plan, `README.md`.
* Draft Supabase migrations in `supabase/migrations/` and a smoke test in
  `supabase/tests/`, verified on PostgreSQL 16.
* `env/example.json` and `.gitignore` rules for environment files.

---

## Phase 2 — Foundation ⬜

Goal: an app that launches, signs users in and out, and has the database,
theme, navigation and sync plumbing every later phase builds on.

1. Dependencies and tooling: add the packages in ARCHITECTURE §3, `build.yaml`,
   `analysis_options.yaml` (with `riverpod_lint`), CI-friendly scripts.
2. Configuration: `Env` class reading `--dart-define-from-file`, fail-fast check.
3. Theme: `AppTokens` ThemeExtension, `AppTheme.dark()` / `.light()`, typography
   scale, dark as default.
4. Core widgets: card, buttons, text/number fields, empty/error/skeleton states,
   confirm dialog.
5. Drift database: all eight mirrored tables + `sync_outbox`, `sync_cursors`,
   `app_state`; type converters; schema snapshot v1; `Clock` and UUIDv7 services.
6. Outbox helper used by repositories (enqueue + coalesce in-transaction). The
   push/pull engine itself is Phase 6, but every write from Phase 2 onwards is
   already queued, so no data written before Phase 6 is left unsynced.
7. Supabase initialisation; apply migrations to a real project (needs
   credentials, see README).
8. Authentication: register, login, logout, forgot/reset password with deep link,
   session persistence, GoRouter redirects.
9. Profile: view/edit display name, weight unit, default rest, auto-start timer.
10. Navigation shell: 4 tabs with placeholder screens clearly labelled
    "Coming in Phase N".
11. Tests: auth controller and redirect logic, Drift database opens and migrates,
    outbox enqueue/coalesce, unit conversion.

**Exit criteria:** a user can register, log in, edit profile settings, log out;
`flutter analyze` clean; tests pass.

## Phase 3 — Workout management ⬜

1. Exercise library: list with search and muscle-group filter, details,
   create/edit/delete custom exercises (system ones read-only), duplicate-name
   warning.
2. Workout plans: list (active and inactive), create, edit, delete (soft,
   confirmed), duplicate (deep copy with new IDs), activate/deactivate.
3. Plan editor: add/remove exercises from the library, drag to reorder, per
   exercise: set template (quick "N × reps @ weight" plus per-set edit, warm-up
   or working), rest duration, notes.
4. Tests: plan CRUD, duplication independence (editing a copy never changes the
   original), exercise assignment, reordering, system-exercise protection,
   validation.

**Exit criteria:** plans fully manageable offline; every change queued in the outbox.

## Phase 4 — Workout execution ⬜

1. Start from a plan (snapshot transaction) or Quick Start (empty).
2. Active workout screen per ARCHITECTURE §10: inline previous performance
   (the query ships here; history UI comes in Phase 5), set rows with numeric
   input, one-tap complete, add/remove sets, warm-up vs working, per-set weight,
   bodyweight exercises, skip, add exercise mid-workout, reorder, exercise notes.
3. Autosave of every change; restore on app restart; resume bar on all tabs.
4. Rest timer: start/pause/resume/skip/±15 s, auto-start, persisted and
   wall-clock based; optional notification (open question 6).
5. Finish workout (summary, confirm if sets are incomplete) and abandon
   (confirmed).
6. Tests: snapshot independence from later plan edits, set logging and
   validation, previous performance selection, completion/abandon state
   transitions, restore after "restart" (re-open database), timer maths across
   simulated background time.

**Exit criteria:** a full workout can be logged offline and survives app kill.

## Phase 5 — History and analytics ⬜

1. History list (date, duration, plan name, sets count) with filters; detail
   view; edit past workouts (sets, notes, times); delete with confirmation.
2. Home: welcome, today's workout (open question 2), quick start, recent
   activity, weekly workout count, weekly completed sets, streak (open question 3).
3. Progress: exercise picker (exercises the user has performed), charts for top
   weight, reps, volume and estimated 1RM, plus estimated PR list.
4. Tests: 1RM (Epley), volume rules, aggregation per session, weekly stats and
   streak with time-zone edge cases, history edit/delete.

## Phase 6 — Offline synchronisation ⬜

1. Supabase remote data source per table (batched upsert, paginated pull).
2. Sync engine: dependency-ordered push, pull with cursors and overlap, merge
   rules, single-flight lock, triggers (write, start, resume, connectivity,
   manual), exponential backoff, failure isolation.
3. First sign-in full pull with progress; sign-out wipe with unsynced-data guard.
4. Sync status UI (last synced, pending count, failed rows with retry).
5. Tests with a fake remote: idempotent retries, no duplicates, older edit
   cannot overwrite newer, tombstones, partial failure, recovery after restart;
   against local Supabase: end-to-end push/pull between two simulated devices.

## Phase 7 — Testing and polishing ⬜

1. pgTAP RLS and constraint tests (`supabase test db`).
2. Widget tests for the active workout and plan editor; integration test of the
   main flow.
3. Error-state and empty-state review across all screens; accessibility
   (text scaling, contrast, tap targets); performance pass (long histories).
4. Final documentation update; "Definition of Done" checklist walk-through.

---

## Risks and mitigations

| Risk | Mitigation |
|---|---|
| Device clock wrong → LWW picks the wrong edit | Server clamps future timestamps; per-row granularity keeps conflicts rare; single user. |
| Schema drift between Drift and Postgres | One mapping per table in the sync registry with a round-trip test per table. |
| Password-reset deep link misconfigured | Documented setup; tested manually on both platforms in Phase 2. |
| Package churn (Riverpod 3, go_router 18) | Pin versions; upgrade only between phases. |
| Large local history slowing charts | Indexed queries, per-session aggregation in SQL, measured in Phase 7. |

---

## Open questions for approval

These affect behaviour or architecture. Each has a recommendation that will be
used unless you decide otherwise.

1. **Category vs primary muscle group.** The spec lists both, and the default
   categories (Chest, Back, …, Cardio, Other) are muscle groups. *Recommendation:*
   treat them as one field (`primary_muscle_group`), used for filtering, with
   optional secondary muscle groups.
2. **"Today's workout" on Home.** v1 has no plan scheduling. *Recommendation:*
   suggest the active plan done least recently ("Up next"), clearly labelled as
   a suggestion; no scheduling table in v1.
3. **Workout streak definition.** *Recommendation:* consecutive calendar weeks
   (Mon–Sun, device time zone) with at least one completed workout. Daily
   streaks punish rest days.
4. **Abandoned workouts.** *Recommendation:* keep them with status `abandoned`
   (never silently delete data), hide them from history by default with a
   filter to show them, exclude them from stats and previous performance, and
   allow deleting them.
5. **Pre-filling set values.** *Recommendation:* pre-fill each set's weight and
   reps from the previous performance for the same set position, falling back to
   the plan target, falling back to empty. Values are editable suggestions and
   a set only counts once ticked.
6. **Rest timer notification.** Alerting while the phone is locked needs
   `flutter_local_notifications` and a notification permission prompt.
   *Recommendation:* include it, with a toggle in Profile.
7. **Platforms.** The project was created for Android and iOS only.
   *Recommendation:* keep it mobile-only for v1. Say if web or desktop matters.
8. **Account deletion.** Not in the spec, but the Apple App Store requires
   in-app account deletion for apps with sign-up. *Recommendation:* if App
   Store release is planned, add a small Supabase Edge Function in Phase 2/7;
   otherwise defer.
9. **Email confirmation on sign-up.** *Recommendation:* enable it in Supabase
   (safer), and show a "check your inbox" screen after registration.
10. **Supabase project.** Phase 2 needs a Supabase project URL and anon key in a
    local `env/dev.json` (never committed) and the password-reset redirect URL
    configured. Do you already have a project, or should the setup steps be
    written for you to create one?
