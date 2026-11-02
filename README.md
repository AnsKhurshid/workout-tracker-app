# Gym Tracker

A simple, modern, offline-first gym workout tracker built with Flutter and
Supabase. Create workout plans, log sets, reps and weights in a fast active
workout screen, see what you lifted last time, and track progress over time.

> **Status: Phase 1 (planning) complete, awaiting approval.**
> The repository currently contains the Flutter scaffold, the design documents
> and draft database migrations. No app features are implemented yet. See
> [DEVELOPMENT_PLAN.md](DEVELOPMENT_PLAN.md) for progress.

## Documentation

| Document | What it covers |
|---|---|
| [ARCHITECTURE.md](ARCHITECTURE.md) | Layers, project structure, local-first data flow, sync design, navigation, UI, key decisions |
| [DATABASE_SCHEMA.md](DATABASE_SCHEMA.md) | Tables, relationships, constraints, RLS, business-rule mapping, local SQLite schema |
| [DEVELOPMENT_PLAN.md](DEVELOPMENT_PLAN.md) | Phases, exit criteria, risks, open questions |

## Version 1.0 features (planned)

* Email/password accounts with password reset and a basic profile (KG/LBS)
* Exercise library with search, muscle-group filters and custom exercises
* Multiple workout plans with per-exercise set templates, rest and notes
* Active workout logging with warm-up/working sets, per-set weights, notes,
  skip/add/reorder, and inline previous performance
* Rest timer that stays accurate in the background
* Workout history with editing and deletion
* Progress charts: weight, reps, volume and estimated 1RM (Epley)
* Works fully offline; syncs to Supabase when online

## Tech stack

Flutter (Material 3) · Riverpod · GoRouter · Drift (SQLite) · Supabase (Auth,
Postgres with RLS) · fl_chart

## Prerequisites

* Flutter **3.47.x** stable (Dart 3.13)
* Android Studio / Xcode for device builds
* A Supabase project (free tier is fine)
* Optional: [Supabase CLI](https://supabase.com/docs/guides/cli) and Docker for
  running Supabase locally and for database tests

## Setup

### 1. Supabase

1. Create a project at [supabase.com](https://supabase.com).
2. Apply the migrations in `supabase/migrations/` in filename order, either with
   the CLI (`supabase link --project-ref <ref>` then `supabase db push`) or by
   pasting each file into the SQL editor.
3. Authentication → URL Configuration: add
   `com.anskhurshid.gymtracker://auth-callback` to **Redirect URLs** (used by
   password reset). The app-side deep link is configured in Phase 2.
4. Authentication → Providers → Email: enabled (email confirmation recommended).

### 2. App configuration

Secrets are never committed. Copy the template and fill in your project values
(Project Settings → API):

```bash
cp env/example.json env/dev.json
```

```json
{
  "SUPABASE_URL": "https://<project-ref>.supabase.co",
  "SUPABASE_ANON_KEY": "<anon public key>"
}
```

Only the **anon** key belongs in the app; data is protected by Row Level
Security. Never put the service-role key in this file.

### 3. Run

```bash
flutter pub get
flutter run --dart-define-from-file=env/dev.json
```

(Code generation, `dart run build_runner build`, is introduced in Phase 2.)

## Testing

```bash
flutter analyze
flutter test
```

Database smoke test on a scratch PostgreSQL 15+ database (no Supabase needed):

```bash
psql -d scratch -v ON_ERROR_STOP=1 \
  -f supabase/tests/local_auth_stub.sql \
  -f supabase/migrations/20261102000100_core_schema.sql \
  -f supabase/migrations/20261102000200_row_level_security.sql \
  -f supabase/migrations/20261102000300_seed_system_exercises.sql
psql -d scratch -f supabase/tests/phase1_schema_smoke.sql
```

## Project structure

```
lib/          Flutter app (feature-oriented; see ARCHITECTURE.md §4)
test/         Unit and widget tests
supabase/     SQL migrations and database tests
env/          Build-time configuration templates
```
