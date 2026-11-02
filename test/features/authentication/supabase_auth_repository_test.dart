import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:gym_tracker/core/errors/app_failure.dart';
import 'package:gym_tracker/core/logging/app_logger.dart';
import 'package:gym_tracker/features/authentication/data/supabase_auth_repository.dart';
import 'package:gym_tracker/features/authentication/domain/auth_repository.dart';
import 'package:gym_tracker/features/authentication/domain/auth_status.dart';
import 'package:mocktail/mocktail.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class MockGoTrueClient extends Mock implements GoTrueClient {}

User _user({List<UserIdentity>? identities}) => User(
  id: 'user-1',
  appMetadata: const {},
  userMetadata: const {'display_name': 'Sam'},
  aud: 'authenticated',
  email: 'sam@example.com',
  createdAt: '2026-11-02T00:00:00Z',
  identities: identities,
);

Session _session() => Session(accessToken: 'token', tokenType: 'bearer', user: _user());

void main() {
  late MockGoTrueClient client;
  late StreamController<AuthState> events;
  late SupabaseAuthRepository repo;

  setUpAll(() => registerFallbackValue(UserAttributes()));

  setUp(() {
    client = MockGoTrueClient();
    events = StreamController<AuthState>.broadcast();
    when(() => client.onAuthStateChange).thenAnswer((_) => events.stream);
    when(() => client.currentSession).thenReturn(null);
    repo = SupabaseAuthRepository(client, AppLogger(minLevel: LogLevel.error));
  });

  tearDown(() async {
    await repo.dispose();
    await events.close();
  });

  test('starts from the stored session', () async {
    when(() => client.currentSession).thenReturn(_session());
    final restored = SupabaseAuthRepository(client, AppLogger(minLevel: LogLevel.error));
    addTearDown(restored.dispose);
    expect(restored.currentStatus, isA<Authenticated>());
    expect(restored.currentStatus.user!.displayName, 'Sam');
    expect(repo.currentStatus, const Unauthenticated());
  });

  test('maps auth events to statuses, including password recovery', () async {
    final statuses = <AuthStatus>[];
    final sub = repo.statusChanges().listen(statuses.add);
    addTearDown(sub.cancel);

    events.add(AuthState(AuthChangeEvent.signedIn, _session()));
    events.add(AuthState(AuthChangeEvent.passwordRecovery, _session()));
    events.add(AuthState(AuthChangeEvent.userUpdated, _session()));
    events.add(
      const AuthState(AuthChangeEvent.signedOut, null, signOutReason: SignOutReason.userInitiated),
    );
    await pumpEventQueue();

    expect(statuses.map((s) => s.runtimeType).toList(), [
      Authenticated,
      PasswordRecovery,
      Authenticated,
      Unauthenticated,
    ]);
    expect((statuses.last as Unauthenticated).sessionExpired, isFalse);
  });

  test('an involuntary sign-out is reported as an expired session', () async {
    events.add(AuthState(AuthChangeEvent.signedIn, _session()));
    events.add(
      const AuthState(AuthChangeEvent.signedOut, null, signOutReason: SignOutReason.sessionExpired),
    );
    await pumpEventQueue();
    expect(repo.currentStatus, const Unauthenticated(sessionExpired: true));
  });

  test('token refreshes do not emit duplicate statuses', () async {
    final statuses = <AuthStatus>[];
    final sub = repo.statusChanges().listen(statuses.add);
    addTearDown(sub.cancel);
    events.add(AuthState(AuthChangeEvent.signedIn, _session()));
    events.add(AuthState(AuthChangeEvent.tokenRefreshed, _session()));
    await pumpEventQueue();
    expect(statuses, hasLength(1));
  });

  test('sign-up passes the display name and redirect, and detects confirmation', () async {
    when(
      () => client.signUp(
        email: any(named: 'email'),
        password: any(named: 'password'),
        data: any(named: 'data'),
        emailRedirectTo: any(named: 'emailRedirectTo'),
      ),
    ).thenAnswer((_) async => AuthResponse(user: _user(identities: [_identity()])));

    final outcome = await repo.signUp(
      displayName: ' Sam ',
      email: ' sam@example.com ',
      password: 'liftHeavy1',
    );

    expect(outcome, SignUpOutcome.confirmationRequired);
    verify(
      () => client.signUp(
        email: 'sam@example.com',
        password: 'liftHeavy1',
        data: {'display_name': 'Sam'},
        emailRedirectTo: 'com.anskhurshid.gymtracker://auth-callback',
      ),
    ).called(1);
  });

  test('sign-up for an existing email (no identities) is reported', () async {
    when(
      () => client.signUp(
        email: any(named: 'email'),
        password: any(named: 'password'),
        data: any(named: 'data'),
        emailRedirectTo: any(named: 'emailRedirectTo'),
      ),
    ).thenAnswer((_) async => AuthResponse(user: _user(identities: const [])));

    expect(
      () => repo.signUp(displayName: 'Sam', email: 'sam@example.com', password: 'liftHeavy1'),
      throwsA(isA<AuthFailure>().having((f) => f.kind, 'kind', AuthFailureKind.userAlreadyExists)),
    );
  });

  test('sign-in errors are mapped to AppFailures', () async {
    when(
      () => client.signInWithPassword(
        email: any(named: 'email'),
        password: any(named: 'password'),
      ),
    ).thenThrow(const AuthException('Invalid login credentials', code: 'invalid_credentials'));
    expect(
      () => repo.signIn(email: 'sam@example.com', password: 'x'),
      throwsA(isA<AuthFailure>().having((f) => f.kind, 'kind', AuthFailureKind.invalidCredentials)),
    );

    when(
      () => client.signInWithPassword(
        email: any(named: 'email'),
        password: any(named: 'password'),
      ),
    ).thenThrow(const SocketException('offline'));
    expect(
      () => repo.signIn(email: 'sam@example.com', password: 'x'),
      throwsA(isA<NetworkFailure>()),
    );
  });

  test('sign-out still signs out locally when the server is unreachable', () async {
    events.add(AuthState(AuthChangeEvent.signedIn, _session()));
    await pumpEventQueue();
    when(() => client.signOut()).thenThrow(AuthRetryableFetchException(message: 'offline'));

    await repo.signOut();

    expect(repo.currentStatus, const Unauthenticated());
  });

  test('password reset uses the app redirect URL', () async {
    when(() => client.resetPasswordForEmail(any(), redirectTo: any(named: 'redirectTo')))
        .thenAnswer((_) async {});
    await repo.sendPasswordResetEmail(' sam@example.com ');
    verify(
      () => client.resetPasswordForEmail(
        'sam@example.com',
        redirectTo: 'com.anskhurshid.gymtracker://auth-callback',
      ),
    ).called(1);
  });

  test('updating the password ends recovery mode', () async {
    events.add(AuthState(AuthChangeEvent.passwordRecovery, _session()));
    await pumpEventQueue();
    expect(repo.currentStatus, isA<PasswordRecovery>());
    when(() => client.updateUser(any())).thenAnswer((_) async => UserResponse.fromJson(const {}));
    when(() => client.currentSession).thenReturn(_session());

    await repo.updatePassword('newPass123');

    expect(repo.currentStatus, isA<Authenticated>());
  });
}

UserIdentity _identity() => const UserIdentity(
  id: 'i1',
  userId: 'user-1',
  identityData: {},
  identityId: 'i1',
  provider: 'email',
  createdAt: null,
  lastSignInAt: null,
);
