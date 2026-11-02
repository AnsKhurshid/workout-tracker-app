import 'package:flutter_test/flutter_test.dart';
import 'package:gym_tracker/features/authentication/domain/auth_status.dart';
import 'package:gym_tracker/routing/auth_redirect.dart';
import 'package:gym_tracker/routing/routes.dart';

import '../helpers/fakes.dart';

void main() {
  const signedOut = Unauthenticated();
  const signedIn = Authenticated(testUser);
  const recovering = PasswordRecovery(testUser);

  test('signed-out users may only visit public routes', () {
    for (final route in Routes.publicRoutes) {
      expect(authRedirect(signedOut, route), isNull, reason: route);
    }
    expect(authRedirect(signedOut, '${Routes.checkEmail}?email=a%40b.c'), isNull);
    for (final route in [
      Routes.home,
      Routes.workouts,
      Routes.progress,
      Routes.profile,
      Routes.resetPassword,
      '/',
    ]) {
      expect(authRedirect(signedOut, route), Routes.welcome, reason: route);
    }
  });

  test('signed-in users are kept out of auth screens', () {
    for (final route in [...Routes.publicRoutes, Routes.resetPassword, '/']) {
      expect(authRedirect(signedIn, route), Routes.home, reason: route);
    }
    for (final route in [Routes.home, Routes.workouts, Routes.progress, Routes.profile]) {
      expect(authRedirect(signedIn, route), isNull, reason: route);
    }
  });

  test('password recovery only allows the reset screen', () {
    expect(authRedirect(recovering, Routes.resetPassword), isNull);
    expect(authRedirect(recovering, Routes.home), Routes.resetPassword);
    expect(authRedirect(recovering, Routes.login), Routes.resetPassword);
  });
}
