import 'package:flutter/foundation.dart';

import '../../../models/auth_user.dart';

/// Where the user is in the authentication lifecycle. Drives route guards.
@immutable
sealed class AuthStatus {
  const AuthStatus();

  AuthUser? get user => switch (this) {
    Authenticated(:final user) => user,
    PasswordRecovery(:final user) => user,
    Unauthenticated() => null,
  };
}

final class Unauthenticated extends AuthStatus {
  const Unauthenticated({this.sessionExpired = false});

  /// True when the user was signed out involuntarily because their session
  /// could no longer be refreshed (not because they tapped "Log out").
  final bool sessionExpired;

  @override
  bool operator ==(Object other) =>
      other is Unauthenticated && other.sessionExpired == sessionExpired;

  @override
  int get hashCode => sessionExpired.hashCode;
}

final class Authenticated extends AuthStatus {
  const Authenticated(this.user);

  @override
  final AuthUser user;

  @override
  bool operator ==(Object other) => other is Authenticated && other.user == user;

  @override
  int get hashCode => user.hashCode;
}

/// The user opened a password-reset link. They hold a temporary session that
/// may only be used to set a new password.
final class PasswordRecovery extends AuthStatus {
  const PasswordRecovery(this.user);

  @override
  final AuthUser user;

  @override
  bool operator ==(Object other) => other is PasswordRecovery && other.user == user;

  @override
  int get hashCode => Object.hash('recovery', user);
}
