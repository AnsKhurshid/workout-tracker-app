# Environment setup

How to get Gym Tracker building and connected to your own Supabase project.

## 1. Toolchain

| Tool | Version | Notes |
|---|---|---|
| Flutter | **3.47.x stable** (built with 3.47.9) | `flutter --version` |
| Dart | **3.13.x** (bundled with Flutter) | `pubspec.yaml` requires `^3.13.7` |
| Android | Android Studio with SDK 36, an emulator or device on **Android 7.0 (API 24)+** | `minSdk = 24` |
| iOS (macOS only) | Xcode 16+, **iOS 15.0+** device or simulator, CocoaPods | |
| Supabase CLI (optional) | latest | Applies migrations; runs Supabase locally (needs Docker) |

Run `flutter doctor` and fix anything it reports for the platform you target.

## 2. Install dependencies

```bash
flutter pub get
```

Generated Drift code (`lib/core/database/app_database.g.dart`) is committed, so
you only need code generation after changing the database tables:

```bash
dart run build_runner build
```

## 3. Create and configure a Supabase project

1. Create a project at <https://supabase.com/dashboard> (the free tier is fine).
2. **Apply the database migrations** in `supabase/migrations/`, in filename order.
   * With the CLI: `supabase link --project-ref <project-ref>` then `supabase db push`.
   * Or paste each file into **SQL Editor** and run it, in order
     (`…000100_core_schema`, `…000200_row_level_security`,
     `…000300_seed_system_exercises`).
   * Check: **Table Editor** shows 8 tables, and `exercises` has 58 rows.
   * The `profiles` row for each user is created automatically by the
     `on_auth_user_created` trigger, using the display name entered at sign-up.
3. **Authentication → URL Configuration**
   * Add `com.anskhurshid.gymtracker://auth-callback` to **Redirect URLs**.
     Confirmation and password-reset emails send the user back into the app
     through this link. Without it, Supabase rejects the redirect.
4. **Authentication → Sign In / Providers → Email**
   * Email provider: enabled.
   * **Confirm email**: recommended on. The app handles both settings. When it
     is on, registration shows a "Confirm your email" screen. When it is off,
     the user is signed in straight away.
   * Minimum password length: 8 or lower. The app enforces at least 8
     characters with a letter and a number.
5. **Email delivery (important for testing).** Supabase's built-in email
   service only delivers to email addresses of your project's team members and
   is heavily rate-limited (a few emails per hour). To test sign-up and password
   reset with other addresses, set up custom SMTP under
   **Authentication → Emails → SMTP Settings**, or temporarily turn
   "Confirm email" off.

## 4. App configuration (`.env`)

The app reads two public values at build time. Nothing is hard-coded.

```bash
cp .env.example .env
```

Edit `.env` with values from **Project Settings → API Keys** (URL under
**Project Settings → Data API**):

```dotenv
SUPABASE_URL=https://<project-ref>.supabase.co
SUPABASE_PUBLISHABLE_KEY=sb_publishable_...
```

* The legacy **anon** key also works in `SUPABASE_PUBLISHABLE_KEY`.
* Never use the **secret** / **service_role** key. It bypasses Row Level
  Security.
* `.env` is git-ignored. Only `.env.example` is committed.
* The values are compiled in with `--dart-define-from-file`. The file is not
  bundled as an asset.

If the values are missing or still contain the placeholders, the app starts on
a **"Configuration required"** screen listing what is wrong, instead of
crashing.

## 5. Run

```bash
flutter run --dart-define-from-file=.env
```

In VS Code add `"toolArgs": ["--dart-define-from-file=.env"]` to your launch
configuration. In Android Studio add `--dart-define-from-file=.env` to
**Additional run args**.

## 6. Test

```bash
dart format --set-exit-if-changed lib test
flutter analyze
flutter test
```

Tests use an in-memory SQLite database and fake auth/remote services. They
**do not need Supabase credentials or a network**.

Database smoke test (plain PostgreSQL 15+, no Supabase needed): see
[README.md](README.md#testing).

## 7. Deep links (already configured)

| Platform | Where | What |
|---|---|---|
| Android | `android/app/src/main/AndroidManifest.xml` | `intent-filter` for `com.anskhurshid.gymtracker://auth-callback` |
| iOS | `ios/Runner/Info.plist` | `CFBundleURLTypes` with scheme `com.anskhurshid.gymtracker` |

`supabase_flutter` picks up the link, exchanges the PKCE code for a session,
and the app routes to Home (email confirmation) or "Choose a new password"
(password reset).

To trigger a deep link manually on an Android emulator:

```bash
adb shell am start -a android.intent.action.VIEW \
  -d "com.anskhurshid.gymtracker://auth-callback?code=TEST"
```

## 8. Troubleshooting

| Symptom | Likely cause |
|---|---|
| "Configuration required" screen | `.env` missing, or app not started with `--dart-define-from-file=.env` |
| "Can't reach the server" on login | No internet, wrong `SUPABASE_URL`, or the project is paused |
| Confirmation / reset email never arrives | Built-in email limits (see step 3.5) |
| Link opens the browser with an error | Redirect URL not added in step 3.3 |
| "Please confirm your email first" | Confirm email is on and the link was not opened yet |
| Profile shows "waiting to sync" | The change is saved on the device and will upload when the server is reachable |
