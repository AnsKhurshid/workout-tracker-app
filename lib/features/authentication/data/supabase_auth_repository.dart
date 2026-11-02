import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart' as sb;

import '../../../core/constants/app_constants.dart';
import '../../../core/errors/app_failure.dart';
import '../../../core/errors/error_mapper.dart';
import '../../../core/logging/app_logger.dart';
import '../../../models/auth_user.dart';
import '../domain/auth_repository.dart';
import '../domain/auth_status.dart';

/// [AuthRepository] backed by Supabase Auth (GoTrue).
class SupabaseAuthRepository implements AuthRepository {
  SupabaseAuthRepository(this._auth, this._logger) {
    _status = _fromSession(_auth.currentSession);
    _subscription = _auth.onAuthStateChange.listen(
      _onAuthEvent,
      onError: (Object e, StackTrace st) {
        // Typically an invalid or expired deep link.
        _logger.warning('Auth state stream error', e, st);
      },
    );
  }

  final sb.GoTrueClient _auth;
  final AppLogger _logger;
  late final StreamSubscription<sb.AuthState> _subscription;
  final _controller = StreamController<AuthStatus>.broadcast();
  late AuthStatus _status;
  bool _inRecovery = false;

  @override
  AuthStatus get currentStatus => _status;

  @override
  Stream<AuthStatus> statusChanges() => _controller.stream;

  void _onAuthEvent(sb.AuthState state) {
    switch (state.event) {
      case sb.AuthChangeEvent.passwordRecovery:
        _inRecovery = true;
      case sb.AuthChangeEvent.signedOut:
      case sb.AuthChangeEvent.userUpdated:
        _inRecovery = false;
      default:
        break;
    }
    _logger.debug('Auth event: ${state.event.name}');
    final expired =
        state.event == sb.AuthChangeEvent.signedOut &&
        state.signOutReason != null &&
        state.signOutReason != sb.SignOutReason.userInitiated;
    _emit(_fromSession(state.session, sessionExpired: expired));
  }

  void _emit(AuthStatus status) {
    if (status == _status) return;
    _status = status;
    _controller.add(status);
  }

  AuthStatus _fromSession(sb.Session? session, {bool sessionExpired = false}) {
    if (session == null) return Unauthenticated(sessionExpired: sessionExpired);
    final user = _toUser(session.user);
    return _inRecovery ? PasswordRecovery(user) : Authenticated(user);
  }

  static AuthUser _toUser(sb.User user) {
    final name = user.userMetadata?['display_name'];
    return AuthUser(
      id: user.id,
      email: user.email ?? '',
      displayName: name is String && name.trim().isNotEmpty ? name.trim() : null,
    );
  }

  Future<T> _guard<T>(String action, Future<T> Function() body) async {
    try {
      return await body();
    } catch (e, st) {
      final failure = mapError(e);
      _logger.warning('Auth: $action failed (${failure.runtimeType})', e, st);
      throw failure;
    }
  }

  @override
  Future<void> signIn({required String email, required String password}) =>
      _guard('sign in', () async {
        await _auth.signInWithPassword(email: email.trim(), password: password);
      });

  @override
  Future<SignUpOutcome> signUp({
    required String displayName,
    required String email,
    required String password,
  }) => _guard('sign up', () async {
    final response = await _auth.signUp(
      email: email.trim(),
      password: password,
      // Read by the `handle_new_user` trigger to create the profile row.
      data: {'display_name': displayName.trim()},
      emailRedirectTo: AppConstants.authRedirectUrl,
    );
    if (response.session != null) return SignUpOutcome.signedIn;
    // With confirmation enabled and an email that is already registered,
    // Supabase returns a user with no identities instead of an error.
    final identities = response.user?.identities;
    if (identities != null && identities.isEmpty) {
      throw AuthFailure(
        AuthFailureKind.userAlreadyExists,
        debugMessage: 'signUp returned a user without identities',
      );
    }
    return SignUpOutcome.confirmationRequired;
  });

  @override
  Future<void> sendPasswordResetEmail(String email) => _guard(
    'password reset email',
    () => _auth.resetPasswordForEmail(email.trim(), redirectTo: AppConstants.authRedirectUrl),
  );

  @override
  Future<void> updatePassword(String newPassword) => _guard('update password', () async {
    await _auth.updateUser(sb.UserAttributes(password: newPassword));
    // userUpdated also arrives on the stream; clear recovery immediately so
    // the router does not wait for it.
    _inRecovery = false;
    _emit(_fromSession(_auth.currentSession));
  });

  @override
  Future<void> signOut() async {
    try {
      // Clears the session on this device first, then asks the server to
      // revoke it. Offline, only the revoke fails; the user is still signed
      // out here, which is what they asked for.
      await _auth.signOut();
    } catch (e, st) {
      _logger.warning('Server-side sign-out failed; session cleared on this device', e, st);
    }
    _inRecovery = false;
    _emit(const Unauthenticated());
  }

  Future<void> dispose() async {
    await _subscription.cancel();
    await _controller.close();
  }
}
