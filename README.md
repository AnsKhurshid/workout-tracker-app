# Gym Tracker

A simple, modern, offline-first gym workout tracker built with Flutter and
Supabase. Create workout plans, log sets, reps and weights on a fast active
workout screen, see what you lifted last time, and track progress over time.

> **Status: Phase 2 (foundation and authentication) complete, awaiting approval.**
> The app launches, has the full design system, four-tab navigation, account
> registration, login, password reset, logout and a profile with KG/LBS and
> theme settings. Workout features (plans, logging, history, progress) are not
> built yet; their screens say so. See [DEVELOPMENT_PLAN.md](DEVELOPMENT_PLAN.md).

## What works today

| Area | Status |
|---|---|
| Welcome, registration, login, forgot/reset password, logout | Implemented. Tested with a fake backend; **not yet verified against a real Supabase project** |
| Email confirmation flow and auth deep link (Android + iOS) | Implemented. Needs a device test against a real project |
| Route protection (signed out / signed in / password recovery / session expired) | Implemented and tested |
| Profile: display name, email, KG/LBS, theme | Implemented. Saved on the device and uploaded to Supabase when reachable |
| Dark and light themes (dark by default) | Implemented |
| Local SQLite database (Drift) with sync outbox | Implemented (profile and settings only so far) |
| Home dashboard | Layout and empty states only. No workout data exists yet, so no statistics are shown |
| Workouts, Progress tabs | Placeholders describing what's coming |

## Documentation

| Document | What it covers |
|---|---|
| [ENVIRONMENT_SETUP.md](ENVIRONMENT_SETUP.md) | Toolchain, Supabase setup, `.env`, running, deep links, troubleshooting |
| [ARCHITECTURE.md](ARCHITECTURE.md) | Layers, structure, local-first data flow, sync design, auth, navigation, UI, decisions |
| [DATABASE_SCHEMA.md](DATABASE_SCHEMA.md) | Postgres tables, relationships, RLS, business rules, local SQLite schema |
| [DEVELOPMENT_PLAN.md](DEVELOPMENT_PLAN.md) | Phases, status, risks, open questions |
| [docs/phase-reports/](docs/phase-reports/) | Completion report for each phase |

## Tech stack

Flutter 3.47 / Dart 3.13 · Material 3 · Riverpod 3 · GoRouter 18 · Drift
(SQLite) · Supabase (Auth, Postgres with RLS) · Inter font

## Quick start

```bash
flutter pub get
cp .env.example .env        # then fill in your Supabase URL and publishable key
flutter run --dart-define-from-file=.env
```

You need a Supabase project with the migrations from `supabase/migrations/`
applied and the auth redirect URL configured. See
[ENVIRONMENT_SETUP.md](ENVIRONMENT_SETUP.md) for the full steps.

Without a `.env`, the app opens on a "Configuration required" screen that
lists what is missing.

## How it works (short version)

* **Local first.** Everything the user changes is written to the on-device
  SQLite database first, together with an outbox entry, in one transaction.
  Uploading to Supabase happens afterwards and retries when offline.
* **Authentication.** Supabase email/password with PKCE deep links. The
  router redirects based on one auth status stream: signed out → Welcome,
  signed in → Home, reset link → "Choose a new password".
* **Data isolation.** Supabase Row Level Security on every table. On the
  device, data is keyed by user id and is kept (not deleted) on logout.
* **Configuration.** Supabase URL and publishable key are compiled in from
  `.env` with `--dart-define-from-file`. No secrets live in the repository.

## Testing

```bash
dart format --set-exit-if-changed lib test
flutter analyze
flutter test
```

The Flutter tests use an in-memory database and fakes for Supabase, so they
need no credentials or network.

Database smoke test on a scratch PostgreSQL 15+ database (no Supabase needed):

```bash
psql -d scratch -v ON_ERROR_STOP=1 \
  -f supabase/tests/local_auth_stub.sql \
  -f supabase/migrations/20261102000100_core_schema.sql \
  -f supabase/migrations/20261102000200_row_level_security.sql \
  -f supabase/migrations/20261102000300_seed_system_exercises.sql
psql -d scratch -f supabase/tests/phase1_schema_smoke.sql
```

## Known limitations

* Auth and profile upload have not yet been run against a real Supabase
  project.
* Builds have not been run on a physical device or emulator yet.
* Supabase's built-in email service only sends to project team members and is
  rate-limited; configure SMTP to test sign-up with other addresses.
* The full background sync engine arrives in Phase 6. Until then, only the
  profile uploads its own changes.

## Project structure

```
lib/            Flutter app (feature-oriented; see ARCHITECTURE.md §4)
test/           Unit, repository, controller, router and widget tests
supabase/       SQL migrations and database smoke test
drift_schemas/  Local database schema snapshots
assets/fonts/   Inter font and licence
docs/           Phase reports
```
