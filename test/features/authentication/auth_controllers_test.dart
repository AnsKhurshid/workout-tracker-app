import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gym_tracker/core/errors/app_failure.dart';
import 'package:gym_tracker/features/authentication/domain/auth_repository.dart';
import 'package:gym_tracker/features/authentication/domain/auth_status.dart';
import 'package:gym_tracker/features/authentication/presentation/auth_providers.dart';
import 'package:gym_tracker/features/authentication/presentation/controllers/auth_form_controllers.dart';

import '../../helpers/fakes.dart';

void main() {
  late FakeAuthRepository auth;
  late ProviderContainer container;

  setUp(() {
    auth = FakeAuthRepository();
    container = ProviderContainer(overrides: [authRepositoryProvider.overrideWithValue(auth)]);
  });
  tearDown(() => container.dispose());

  test('successful login updates the auth status', () async {
    final sub = container.listen(loginControllerProvider, (_, _) {});
    addTearDown(sub.close);

    final ok = await container
        .read(loginControllerProvider.notifier)
        .submit(email: 'sam@example.com', password: 'liftHeavy1');

    expect(ok, isTrue);
    expect(container.read(loginControllerProvider), const AsyncData<void>(null));
    expect(auth.currentStatus, isA<Authenticated>());
  });

  test('invalid credentials surface a friendly message', () async {
    final sub = container.listen(loginControllerProvider, (_, _) {});
    addTearDown(sub.close);
    auth.nextError = AuthFailure(AuthFailureKind.invalidCredentials);

    final ok = await container
        .read(loginControllerProvider.notifier)
        .submit(email: 'sam@example.com', password: 'wrong');

    expect(ok, isFalse);
    final state = container.read(loginControllerProvider);
    expect(state.failureMessage, 'Incorrect email or password.');
    expect(auth.currentStatus, isA<Unauthenticated>());
  });

  test('network failure while logging in is reported as such', () async {
    final sub = container.listen(loginControllerProvider, (_, _) {});
    addTearDown(sub.close);
    auth.nextError = const NetworkFailure();

    await container.read(loginControllerProvider.notifier).submit(email: 'a@b.co', password: 'x');

    expect(container.read(loginControllerProvider).failureMessage, contains('internet'));
  });

  test('registration reports when email confirmation is required', () async {
    final sub = container.listen(registerControllerProvider, (_, _) {});
    addTearDown(sub.close);

    final outcome = await container
        .read(registerControllerProvider.notifier)
        .submit(displayName: 'Sam', email: 'sam@example.com', password: 'liftHeavy1');

    expect(outcome, SignUpOutcome.confirmationRequired);
    expect(auth.calls, ['signUp:Sam:sam@example.com']);
    expect(auth.currentStatus, isA<Unauthenticated>());
  });

  test('registration signs in directly when confirmation is off', () async {
    final sub = container.listen(registerControllerProvider, (_, _) {});
    addTearDown(sub.close);
    auth.signUpOutcome = SignUpOutcome.signedIn;

    final outcome = await container
        .read(registerControllerProvider.notifier)
        .submit(displayName: 'Sam', email: 'sam@example.com', password: 'liftHeavy1');

    expect(outcome, SignUpOutcome.signedIn);
    expect(auth.currentStatus.user?.displayName, 'Sam');
  });

  test('duplicate account error on registration', () async {
    final sub = container.listen(registerControllerProvider, (_, _) {});
    addTearDown(sub.close);
    auth.nextError = AuthFailure(AuthFailureKind.userAlreadyExists);

    final outcome = await container
        .read(registerControllerProvider.notifier)
        .submit(displayName: 'Sam', email: 'sam@example.com', password: 'liftHeavy1');

    expect(outcome, isNull);
    expect(container.read(registerControllerProvider).failureMessage, contains('already exists'));
  });

  test('password reset request and new password', () async {
    final forgot = container.listen(forgotPasswordControllerProvider, (_, _) {});
    final reset = container.listen(resetPasswordControllerProvider, (_, _) {});
    addTearDown(forgot.close);
    addTearDown(reset.close);

    expect(
      await container.read(forgotPasswordControllerProvider.notifier).submit('sam@example.com'),
      isTrue,
    );

    auth.setStatus(const PasswordRecovery(testUser));
    expect(
      await container.read(resetPasswordControllerProvider.notifier).submit('newPass123'),
      isTrue,
    );
    expect(auth.currentStatus, const Authenticated(testUser));
    expect(auth.calls, ['reset:sam@example.com', 'updatePassword']);
  });

  test('sign out returns to unauthenticated', () async {
    final sub = container.listen(signOutControllerProvider, (_, _) {});
    addTearDown(sub.close);
    auth.setStatus(const Authenticated(testUser));

    expect(await container.read(signOutControllerProvider.notifier).signOut(), isTrue);
    expect(auth.currentStatus, isA<Unauthenticated>());
  });

  test('authStatusProvider follows repository changes', () async {
    final states = <AuthStatus?>[];
    final sub = container.listen(
      authStatusProvider,
      (_, next) => states.add(next.value),
      fireImmediately: true,
    );
    addTearDown(sub.close);
    await pumpEventQueue();

    auth.setStatus(const Authenticated(testUser));
    await pumpEventQueue();
    auth.setStatus(const Unauthenticated());
    await pumpEventQueue();

    expect(states.whereType<AuthStatus>().toList(), [
      const Unauthenticated(),
      const Authenticated(testUser),
      const Unauthenticated(),
    ]);
    expect(container.read(currentUserProvider), isNull);
  });
}
