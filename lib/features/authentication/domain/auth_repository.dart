import 'auth_status.dart';

enum SignUpOutcome {
  /// The account is active and the user is signed in.
  signedIn,

  /// The project requires email confirmation; the user must open the link
  /// sent to their inbox before they can sign in.
  confirmationRequired,
}

/// Authentication operations. Implementations throw `AppFailure`s only.
abstract interface class AuthRepository {
  /// Current status, available synchronously (used by route guards).
  AuthStatus get currentStatus;

  /// Emits every status change (sign in, sign out, session expiry, password
  /// recovery link opened).
  Stream<AuthStatus> statusChanges();

  Future<void> signIn({required String email, required String password});

  Future<SignUpOutcome> signUp({
    required String displayName,
    required String email,
    required String password,
  });

  /// Sends a password reset email. Succeeds even if the email has no account,
  /// so the response never reveals which emails are registered.
  Future<void> sendPasswordResetEmail(String email);

  /// Sets a new password for the signed-in (or recovering) user.
  Future<void> updatePassword(String newPassword);

  /// Signs out on this device. Never deletes local data.
  Future<void> signOut();
}
