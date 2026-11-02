# Phase 2 completion report: foundation and authentication

Date: 2026-11-02 · Branch: `claude/project-thread-svcjr1` · Toolchain:
Flutter 3.47.9 / Dart 3.13.7

## Summary

The app now has a working foundation: startup with configuration and error
handling, a dark-first Material 3 design system with a light theme, four-tab
navigation with route guards, a local Drift database with a sync outbox,
Supabase integration, the full email/password authentication flow, and a
profile backed by real account data. **87 tests pass**, `flutter analyze`
reports **no issues**, and `dart format` leaves the code unchanged.

**Not yet verified externally:** authentication and profile upload against a
real Supabase project (no credentials were available), and running on a real
Android or iOS device or emulator (no mobile SDKs in the build environment).
Everything below marked "tested" was tested with fakes for Supabase.

## 1. Phase 1 check

| Item | Finding | Action |
|---|---|---|
| Flutter project, docs, migrations | Present and consistent | Kept |
| `env/example.json` config template | Phase 2 asks for `.env.example` | Replaced with `.env.example` (`--dart-define-from-file` reads `.env` natively) |
| Bundle ids `gym_tracker` / `gymTracker` | Underscores are invalid in URL schemes, so the deep link could not use them | Unified to `com.anskhurshid.gymtracker` |
| "Wipe local DB on logout" (ARCHITECTURE §7.7) | Conflicts with "do not delete user data on logout" | Changed to user-id isolation; data kept |
| Open questions 1–10 | Unanswered | None blocked Phase 2. Registration handles both email-confirmation settings (Q9). Platforms stay Android + iOS (Q7) |
| Local folder `C:\Users\Kavtech\Desktop\gym-tracker` | Computer not reachable (tried again in Phase 2) | Still unchecked |

## 2. Features implemented

**App setup.** Display name "Gym Tracker". Android `applicationId`/namespace and
iOS bundle id `com.anskhurshid.gymtracker`. Android `minSdk 24`, iOS 15.0.
INTERNET permission. Auth deep link `com.anskhurshid.gymtracker://auth-callback`
registered on both platforms. Inter font bundled for offline use.

**Configuration.** `EnvConfig` reads `SUPABASE_URL` and
`SUPABASE_PUBLISHABLE_KEY` from `--dart-define-from-file=.env` and validates
them. Missing or placeholder values show a "Configuration required" screen.

**Design system.** One palette (lime accent on near-black), the `AppTokens`
theme extension (success, warning, info, border, muted text, skeleton),
spacing/radius/size scales, and an Inter type scale (minimum 12 pt). Dark and
light `ThemeData` come from one builder, with app bar, card, buttons, inputs,
dialog, bottom sheet, navigation bar, segmented button, list tile, divider,
snackbar, progress and chip themes. Dark is the default. Theme (System / Dark /
Light) is chosen in Profile and stored per device.

**Reusable widgets.** Primary/secondary buttons with a loading state; text and
password fields (visibility toggle, autofill hints); empty, error, loading,
skeleton and form-message states; section card; confirm dialog; snackbar
helper; logo; content width constraint; planned-feature placeholder.

**Startup.** A splash screen, then: validate config → open and migrate the
database (background isolate) → initialise Supabase (restores the saved
session, works offline). A failure shows a retryable error screen. A database
failure never deletes data.

**State management.** Riverpod 3. App-level dependency providers live in
`core/providers.dart`. Feature providers wrap repositories. Form controllers
are `Notifier<AsyncValue<void>>` with loading and error states. Widgets never
touch Drift or Supabase.

**Local database (Drift, schema v1).**

| Table | Purpose |
|---|---|
| `profiles` | Mirror of `public.profiles` (same columns + `server_updated_at`) |
| `app_settings` | Device key/value settings (theme) |
| `sync_outbox` | Pending uploads: one entry per (table, record), attempts, backoff, state `pending`/`failed` |
| `sync_cursors` | Per-user, per-table pull cursor (used from Phase 6) |

File location: the app support directory (`gym_tracker.sqlite`), managed by
`drift_flutter`. Foreign keys are on. Migrations go through
`MigrationStrategy`, and a schema snapshot is in
`drift_schemas/drift_schema_v1.json`.

**Supabase.** `SupabaseService` is the only place that initialises Supabase
and exposes the client (PKCE auth flow, auto refresh). Only data-layer classes
use it.

**Authentication.**

* Welcome: branding, short description, Create account / Log in.
* Registration: display name, email, password, confirm password, with
  validation (required, email format, 8+ characters with a letter and a number,
  match). `signUp` sends the display name as metadata, and the database trigger
  creates the profile. Supports both confirmation settings: "Confirm your
  email" screen, or immediate sign-in. Detects an already-registered email.
* Login: validation, loading state, password toggle, friendly errors (wrong
  credentials, unconfirmed email, offline, rate limit), forgot-password link.
* Forgot password: sends the reset email and shows a confirmation with
  "Send again". The response never reveals whether an email is registered.
* Reset password: the deep link puts the app in recovery mode, and the router
  only allows "Choose a new password" until it succeeds or the user cancels.
* Logout: confirmation dialog. The session is cleared on the device even if
  the server is unreachable. Local data is kept.
* Session expiry: an involuntary sign-out returns to Welcome with "Your
  session has expired. Please log in again."

**Route protection.** GoRouter, created once. A pure `authRedirect` function
handles signed out, signed in and recovery. `refreshListenable` re-runs it on
auth changes without rebuilding widgets. `StatefulShellRoute.indexedStack`
keeps each tab's state. There is a 404 page.

**Profile.** Shows the real display name (editable) and email, KG/LBS, theme
and logout, plus "Saved on this device, waiting to sync" while an upload is
pending. Changes are written locally and queued in one transaction, then
uploaded. Offline changes are retried with backoff. Newer local edits are not
overwritten by older server data. The weight unit survives app restarts.

**Home.** Date and "Welcome back, {name}". Sections for Today's workout (empty
state with "Create your first workout plan to get started" and a link to
Workouts), Quick start (button disabled with an explanation), This week, and
Recent activity. No numbers or sample data.

**Workouts / Progress.** Placeholders that say the section is in development
and list what will appear there.

**Error handling and logging.** `AppFailure` sealed hierarchy with user and
debug messages. `mapError` translates Supabase, socket, Postgrest and SQLite
errors. `AppLogger` redacts emails, JWTs, keys and tokens. Global Flutter and
platform error handlers route to the logger.

## 3. Files

**Created (app):**
`lib/app.dart`,
`lib/core/config/env_config.dart`,
`lib/core/constants/app_constants.dart`,
`lib/core/database/{tables.dart, app_database.dart, app_database.g.dart}`,
`lib/core/errors/{app_failure.dart, error_mapper.dart}`,
`lib/core/logging/app_logger.dart`,
`lib/core/providers.dart`,
`lib/core/services/{clock.dart, id_generator.dart, supabase_service.dart}`,
`lib/core/settings/app_settings_repository.dart`,
`lib/core/startup/{app_startup.dart, startup_screens.dart}`,
`lib/core/sync/{outbox.dart, sync_tables.dart}`,
`lib/core/theme/{app_palette.dart, app_spacing.dart, app_theme.dart, app_tokens.dart, app_typography.dart, theme_extensions.dart}`,
`lib/core/utils/{validators.dart, weight_converter.dart}`,
`lib/core/widgets/{app_buttons.dart, app_logo.dart, app_text_field.dart, confirm_dialog.dart, planned_feature_view.dart, section_card.dart, state_views.dart}`,
`lib/models/{app_theme_preference.dart, auth_user.dart, user_profile.dart, weight_unit.dart}`,
`lib/features/authentication/domain/{auth_repository.dart, auth_status.dart}`,
`lib/features/authentication/data/supabase_auth_repository.dart`,
`lib/features/authentication/presentation/{auth_providers.dart, controllers/auth_form_controllers.dart, widgets/auth_scaffold.dart}`,
`lib/features/authentication/presentation/screens/{welcome, login, register, check_email, forgot_password, reset_password}_screen.dart`,
`lib/features/profile/domain/{profile_repository.dart, profile_remote_data_source.dart}`,
`lib/features/profile/data/{profile_repository_impl.dart, supabase_profile_remote_data_source.dart}`,
`lib/features/profile/presentation/{profile_providers.dart, profile_screen.dart}`,
`lib/features/home/presentation/home_screen.dart`,
`lib/features/workout_plans/presentation/workouts_screen.dart`,
`lib/features/progress/presentation/progress_screen.dart`,
`lib/routing/{routes.dart, auth_redirect.dart, app_router.dart, scaffold_with_nav_bar.dart}`.

**Created (other):** `.env.example`, `build.yaml`, `ENVIRONMENT_SETUP.md`,
`drift_schemas/drift_schema_v1.json`, `assets/fonts/Inter-{Regular,Medium,SemiBold,Bold}.ttf`,
`assets/fonts/Inter-LICENSE.txt`, this report, and 14 test files plus 3 test
helpers under `test/`.

**Modified:** `lib/main.dart`, `pubspec.yaml`, `pubspec.lock`,
`analysis_options.yaml`, `.gitignore`, `android/app/build.gradle.kts`,
`android/app/src/main/AndroidManifest.xml`, `MainActivity.kt` (moved to the
`gymtracker` package), `ios/Runner/Info.plist`,
`ios/Runner.xcodeproj/project.pbxproj`, `README.md`, `ARCHITECTURE.md`,
`DATABASE_SCHEMA.md`, `DEVELOPMENT_PLAN.md`.

**Removed:** `env/example.json`, `test/widget_test.dart` (counter scaffold).

## 4. Packages

| Package | Version | Type |
|---|---|---|
| flutter_riverpod | ^3.4.3 | runtime |
| go_router | ^18.1.2 | runtime |
| drift | ^2.35.3 | runtime |
| drift_flutter | ^0.3.1 | runtime |
| supabase_flutter | ^2.18.3 | runtime |
| uuid | ^4.6.0 | runtime |
| drift_dev | ^2.35.2 | dev |
| build_runner | ^2.17.1 | dev |
| mocktail | ^1.0.5 | dev |

Removed: `cupertino_icons` (unused). Not added, compared with the Phase 1
plan: `riverpod_generator`, `freezed` (not needed; see ARCHITECTURE §17).

## 5. Database changes

* **Supabase/Postgres:** none. The Phase 1 migrations are unchanged.
* **Local SQLite:** new database, schema version 1 (tables in §2).

## 6. Supabase configuration required

Full steps are in [ENVIRONMENT_SETUP.md](../../ENVIRONMENT_SETUP.md):

1. Create a project and apply the three migrations in `supabase/migrations/`.
2. Authentication → URL Configuration → Redirect URLs: add
   `com.anskhurshid.gymtracker://auth-callback`.
3. Authentication → Email provider enabled. "Confirm email" on is
   recommended. Minimum password length 8 or lower.
4. For testing with non-team email addresses: configure custom SMTP (the
   built-in sender only delivers to team members and is rate-limited).
5. Copy `.env.example` to `.env` with the project URL and publishable (or
   anon) key, then run `flutter run --dart-define-from-file=.env`.

## 7. Tests

Commands run: `flutter pub get`, `dart format lib test` (no changes),
`flutter analyze` (**No issues found**), `flutter test` (**87 passed, 0 failed**).

| Area required | Test file(s) |
|---|---|
| Application initialisation | `app_test.dart` (config missing, init failure + retry, normal start) |
| Theme configuration | `core/theme/app_theme_test.dart` (M3, tokens, font, component themes, contrast ratios), theme switch in `app_test.dart` |
| Navigation | `app_test.dart` (four tabs, redirects), `routing/auth_redirect_test.dart` |
| Authentication validation | `core/utils/validators_test.dart`, form validation in `app_test.dart` |
| Authentication state handling | `features/authentication/supabase_auth_repository_test.dart` (event mapping, recovery, session expiry, offline logout, sign-up edge cases), `auth_controllers_test.dart` |
| Profile settings | `app_test.dart` (real data shown, KG/LBS saved and uploaded, logout keeps data) |
| Weight unit persistence | `features/profile/profile_repository_test.dart` (reopen database file, offline queue, conflict rules) |
| Local database initialisation | `core/database/app_database_test.dart` (schema, foreign keys, CHECKs, persistence) |
| Repository behaviour | `profile_repository_test.dart`, `core/sync/outbox_test.dart`, `core/settings/app_settings_repository_test.dart` |
| Other | error mapping, log redaction, env validation, weight conversion |

No test needs Supabase credentials or a network.

## 8. Outstanding issues

* **Real-backend verification:** register, confirm email, login, reset
  password, logout and the profile upload need a run against a real Supabase
  project. Needs your project URL and publishable key in a local `.env`.
* **Device verification:** run on an Android emulator/device and an iOS
  simulator. Check the deep link opens the app and the reset screen appears.
* **Open questions 1–6, 8, 10** from DEVELOPMENT_PLAN.md are still open. None
  blocks Phase 3 except Q1 (category vs primary muscle group), which shapes the
  exercise library.

## 9. Known limitations

* Only the profile uploads to Supabase so far, using its own push. The general
  sync engine (pull of all tables, retry triggers on connectivity and resume)
  is Phase 6.
* A profile change that the server permanently rejects is kept as `failed`.
  There is no UI to retry it yet (Phase 6 sync status screen).
* Theme preference is per device; weight unit is per account.
* Startup screens are always dark, because the saved theme loads after the
  database opens.
* Account deletion is not implemented (open question 8).
* Supabase's built-in email limits apply until custom SMTP is set up.

## 10. Recommended next steps

1. Create the Supabase project, apply the migrations, and run the app with
   `.env` to verify the auth flows on a device. Report anything that differs.
2. Answer open question 1 (and ideally 4, 5).
3. Approve Phase 3: exercise library and workout plan management.
