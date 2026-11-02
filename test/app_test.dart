import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gym_tracker/core/config/env_config.dart';
import 'package:gym_tracker/core/errors/app_failure.dart';
import 'package:gym_tracker/features/authentication/domain/auth_status.dart';
import 'package:gym_tracker/models/app_theme_preference.dart';

import 'helpers/fakes.dart';
import 'helpers/test_app.dart';

void main() {
  group('startup', () {
    testWidgets('missing configuration shows setup instructions, not a crash', (tester) async {
      final app = await pumpTestApp(
        tester,
        env: const EnvConfig(supabaseUrl: '', supabasePublishableKey: ''),
      );

      expect(find.text('Configuration required'), findsOneWidget);
      expect(find.textContaining('SUPABASE_URL is not set'), findsOneWidget);
      expect(find.textContaining('SUPABASE_PUBLISHABLE_KEY is not set'), findsOneWidget);
      expect(app.supabase.initializeCalls, 0);
    });

    testWidgets('a failed initialisation can be retried', (tester) async {
      final supabase = FakeSupabaseService()..initializeError = const NetworkFailure();
      await pumpTestApp(tester, supabase: supabase);

      expect(find.text("Couldn't start the app"), findsOneWidget);

      supabase.initializeError = null;
      await tester.tap(find.text('Try again'));
      await tester.pumpAndSettle();

      expect(find.text('Gym Tracker'), findsOneWidget); // welcome screen
      expect(supabase.initializeCalls, 2);
    });
  });

  group('signed out', () {
    testWidgets('shows the welcome screen with login and sign-up', (tester) async {
      await pumpTestApp(tester);
      expect(find.text('Gym Tracker'), findsOneWidget);
      expect(find.text('Create account'), findsOneWidget);
      expect(find.text('Log in'), findsOneWidget);
      expect(find.byType(NavigationBar), findsNothing);
    });

    testWidgets('login validates input, then signs in and opens Home', (tester) async {
      final app = await pumpTestApp(tester);
      await tester.tap(find.text('Log in'));
      await tester.pumpAndSettle();
      expect(find.text('Welcome back'), findsOneWidget);

      await tester.tap(find.widgetWithText(FilledButton, 'Log in'));
      await tester.pumpAndSettle();
      expect(find.text('Enter your email address.'), findsOneWidget);
      expect(find.text('Enter your password.'), findsOneWidget);
      expect(app.auth.calls, isEmpty);

      await tester.enterText(find.widgetWithText(TextFormField, 'Email'), 'sam@example.com');
      await tester.enterText(find.widgetWithText(TextFormField, 'Password'), 'liftHeavy1');
      await tester.tap(find.widgetWithText(FilledButton, 'Log in'));
      await tester.pumpAndSettle();

      expect(app.auth.calls, ['signIn:sam@example.com']);
      expect(find.byType(NavigationBar), findsOneWidget);
      expect(find.text("Today's workout"), findsOneWidget);
    });

    testWidgets('invalid credentials show an error and stay on login', (tester) async {
      final app = await pumpTestApp(tester);
      await tester.tap(find.text('Log in'));
      await tester.pumpAndSettle();
      app.auth.nextError = AuthFailure(AuthFailureKind.invalidCredentials);

      await tester.enterText(find.widgetWithText(TextFormField, 'Email'), 'sam@example.com');
      await tester.enterText(find.widgetWithText(TextFormField, 'Password'), 'nope');
      await tester.tap(find.widgetWithText(FilledButton, 'Log in'));
      await tester.pumpAndSettle();

      expect(find.text('Incorrect email or password.'), findsOneWidget);
      expect(find.byType(NavigationBar), findsNothing);
    });

    testWidgets('password visibility can be toggled', (tester) async {
      await pumpTestApp(tester);
      await tester.tap(find.text('Log in'));
      await tester.pumpAndSettle();

      EditableText field() => tester.widget<EditableText>(
        find.descendant(
          of: find.widgetWithText(TextFormField, 'Password'),
          matching: find.byType(EditableText),
        ),
      );
      expect(field().obscureText, isTrue);
      await tester.tap(find.byTooltip('Show password'));
      await tester.pump();
      expect(field().obscureText, isFalse);
    });

    testWidgets('registration validates fields and shows the confirm-email screen', (tester) async {
      final app = await pumpTestApp(tester);
      await tester.tap(find.text('Create account'));
      await tester.pumpAndSettle();

      await tester.enterText(find.widgetWithText(TextFormField, 'Display name'), 'Sam');
      await tester.enterText(find.widgetWithText(TextFormField, 'Email'), 'sam@example');
      await tester.enterText(find.widgetWithText(TextFormField, 'Password'), 'short');
      await tester.enterText(find.widgetWithText(TextFormField, 'Confirm password'), 'other');
      await tester.tap(find.widgetWithText(FilledButton, 'Create account'));
      await tester.pumpAndSettle();
      expect(find.text('Enter a valid email address.'), findsOneWidget);
      expect(find.text('Use at least 8 characters.'), findsOneWidget);
      expect(find.text("Passwords don't match."), findsOneWidget);
      expect(app.auth.calls, isEmpty);

      await tester.enterText(find.widgetWithText(TextFormField, 'Email'), 'sam@example.com');
      await tester.enterText(find.widgetWithText(TextFormField, 'Password'), 'liftHeavy1');
      await tester.enterText(find.widgetWithText(TextFormField, 'Confirm password'), 'liftHeavy1');
      await tester.tap(find.widgetWithText(FilledButton, 'Create account'));
      await tester.pumpAndSettle();

      expect(app.auth.calls, ['signUp:Sam:sam@example.com']);
      expect(find.text('Confirm your email'), findsOneWidget);
      expect(find.textContaining('sam@example.com'), findsOneWidget);
    });

    testWidgets('forgot password sends the email and confirms', (tester) async {
      final app = await pumpTestApp(tester);
      await tester.tap(find.text('Log in'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Forgot password?'));
      await tester.pumpAndSettle();

      await tester.enterText(find.widgetWithText(TextFormField, 'Email'), 'sam@example.com');
      await tester.tap(find.text('Send reset link'));
      await tester.pumpAndSettle();

      expect(app.auth.calls, ['reset:sam@example.com']);
      expect(find.text('Check your inbox'), findsOneWidget);
    });

    testWidgets('an expired session is explained on the welcome screen', (tester) async {
      await pumpTestApp(
        tester,
        auth: FakeAuthRepository(const Unauthenticated(sessionExpired: true)),
      );
      expect(find.text('Your session has expired. Please log in again.'), findsOneWidget);
    });
  });

  group('signed in', () {
    FakeAuthRepository signedIn() => FakeAuthRepository(const Authenticated(testUser));
    FakeProfileRemote serverProfile() => FakeProfileRemote()
      ..rows[testUser.id] = remoteProfile(displayName: 'Sam', updatedAt: DateTime.utc(2026, 10, 1));

    testWidgets('home greets the user and shows empty states, never sample data', (tester) async {
      await pumpTestApp(tester, auth: signedIn(), remote: serverProfile());

      expect(find.text('Welcome back, Sam'), findsOneWidget);
      expect(find.text('Create your first workout plan to get started.'), findsOneWidget);
      await tester.scrollUntilVisible(find.text('Nothing logged yet'), 200);
      expect(find.text('No activity this week'), findsOneWidget);
      expect(find.text('Nothing logged yet'), findsOneWidget);
      // No fabricated statistics anywhere on Home.
      final texts = tester.widgetList<Text>(find.byType(Text)).map((t) => t.data ?? '').join(' ');
      expect(RegExp(r'\d+\s*(sets|workouts|kg|lbs|day streak)').hasMatch(texts), isFalse);
    });

    testWidgets('bottom navigation switches between the four tabs', (tester) async {
      await pumpTestApp(tester, auth: signedIn(), remote: serverProfile());
      final nav = find.byType(NavigationBar);

      await tester.tap(find.descendant(of: nav, matching: find.text('Workouts')));
      await tester.pumpAndSettle();
      expect(find.text('No workout plans yet'), findsOneWidget);

      await tester.tap(find.descendant(of: nav, matching: find.text('Progress')));
      await tester.pumpAndSettle();
      expect(find.text('No progress to show yet'), findsOneWidget);

      await tester.tap(find.descendant(of: nav, matching: find.text('Profile')));
      await tester.pumpAndSettle();
      expect(find.text('sam@example.com'), findsOneWidget);

      await tester.tap(find.descendant(of: nav, matching: find.text('Home')));
      await tester.pumpAndSettle();
      expect(find.text('Welcome back, Sam'), findsOneWidget);
    });

    testWidgets('profile shows real account data; KG/LBS choice is saved and synced', (
      tester,
    ) async {
      final app = await pumpTestApp(tester, auth: signedIn(), remote: serverProfile());
      await tester.tap(
        find.descendant(of: find.byType(NavigationBar), matching: find.text('Profile')),
      );
      await tester.pumpAndSettle();

      expect(find.text('Sam'), findsOneWidget);
      expect(find.text('sam@example.com'), findsOneWidget);

      await tester.tap(find.text('LBS'));
      await tester.pumpAndSettle();

      final row = await app.db.select(app.db.profiles).getSingle();
      expect(row.weightUnit, 'lbs');
      expect(app.remote.rows[testUser.id]!.weightUnit, 'lbs');
    });

    testWidgets('theme can be switched to light and is remembered', (tester) async {
      final app = await pumpTestApp(tester, auth: signedIn(), remote: serverProfile());
      MaterialApp materialApp() => tester.widget<MaterialApp>(find.byType(MaterialApp));
      expect(materialApp().themeMode, ThemeMode.dark);

      await tester.tap(
        find.descendant(of: find.byType(NavigationBar), matching: find.text('Profile')),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Light'));
      await tester.pumpAndSettle();

      expect(materialApp().themeMode, ThemeMode.light);
      final stored = await app.db.select(app.db.appSettings).getSingle();
      expect(AppThemePreference.fromStorage(stored.value), AppThemePreference.light);
    });

    testWidgets('logging out asks for confirmation and returns to welcome', (tester) async {
      final app = await pumpTestApp(tester, auth: signedIn(), remote: serverProfile());
      await tester.tap(
        find.descendant(of: find.byType(NavigationBar), matching: find.text('Profile')),
      );
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.widgetWithText(OutlinedButton, 'Log out'));
      await tester.tap(find.widgetWithText(OutlinedButton, 'Log out'));
      await tester.pumpAndSettle();
      expect(find.text('Log out?'), findsOneWidget);
      await tester.tap(find.widgetWithText(TextButton, 'Log out'));
      await tester.pumpAndSettle();

      expect(app.auth.calls, ['signOut']);
      expect(find.text('Create account'), findsOneWidget);
      // Local data is kept for when the user logs back in.
      expect(await app.db.select(app.db.profiles).get(), hasLength(1));
    });

    testWidgets('auth changes elsewhere (e.g. session ended) redirect to welcome', (tester) async {
      final app = await pumpTestApp(tester, auth: signedIn(), remote: serverProfile());
      app.auth.setStatus(const Unauthenticated(sessionExpired: true));
      await tester.pumpAndSettle();
      expect(find.text('Your session has expired. Please log in again.'), findsOneWidget);
    });

    testWidgets('works offline with a placeholder profile from sign-up data', (tester) async {
      final remote = FakeProfileRemote()..fetchError = const NetworkFailure();
      await pumpTestApp(tester, auth: signedIn(), remote: remote);
      expect(find.text('Welcome back, Sam'), findsOneWidget);
    });
  });

  testWidgets('a password reset link opens the set-new-password screen', (tester) async {
    final app = await pumpTestApp(
      tester,
      auth: FakeAuthRepository(const PasswordRecovery(testUser)),
    );
    expect(find.text('Choose a new password'), findsOneWidget);

    await tester.enterText(find.widgetWithText(TextFormField, 'New password'), 'newPass123');
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Confirm new password'),
      'newPass123',
    );
    await tester.tap(find.text('Update password'));
    await tester.pumpAndSettle();

    expect(app.auth.calls, ['updatePassword']);
    expect(find.byType(NavigationBar), findsOneWidget);
  });
}
