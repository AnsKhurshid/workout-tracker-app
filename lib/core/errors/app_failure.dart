/// A failure the app knows how to explain to the user.
///
/// [userMessage] is safe to show on screen. [debugMessage] keeps the technical
/// detail for logs (it is redacted by the logger before being written).
sealed class AppFailure implements Exception {
  const AppFailure(this.userMessage, {this.debugMessage, this.cause});

  final String userMessage;
  final String? debugMessage;
  final Object? cause;

  @override
  String toString() =>
      '$runtimeType: ${debugMessage ?? userMessage}${cause == null ? '' : ' (cause: ${cause.runtimeType})'}';
}

/// No connection, DNS failure, timeout, or a 5xx from the server.
final class NetworkFailure extends AppFailure {
  const NetworkFailure({super.debugMessage, super.cause})
    : super("Can't reach the server. Check your internet connection and try again.");
}

enum AuthFailureKind {
  invalidCredentials,
  emailNotConfirmed,
  userAlreadyExists,
  weakPassword,
  sessionExpired,
  rateLimited,
  samePassword,
  other,
}

final class AuthFailure extends AppFailure {
  AuthFailure(this.kind, {super.debugMessage, super.cause}) : super(_message(kind));

  final AuthFailureKind kind;

  static String _message(AuthFailureKind kind) => switch (kind) {
    AuthFailureKind.invalidCredentials => 'Incorrect email or password.',
    AuthFailureKind.emailNotConfirmed =>
      'Please confirm your email first. Check your inbox for the confirmation link.',
    AuthFailureKind.userAlreadyExists =>
      'An account with this email already exists. Try logging in instead.',
    AuthFailureKind.weakPassword =>
      'That password is too weak. Use a longer password with letters and numbers.',
    AuthFailureKind.sessionExpired => 'Your session has expired. Please log in again.',
    AuthFailureKind.rateLimited => 'Too many attempts. Please wait a minute and try again.',
    AuthFailureKind.samePassword =>
      'Your new password must be different from your current password.',
    AuthFailureKind.other => 'Something went wrong while signing in. Please try again.',
  };
}

final class ValidationFailure extends AppFailure {
  const ValidationFailure(super.userMessage, {super.debugMessage});
}

/// The local database could not be opened, read or written.
final class StorageFailure extends AppFailure {
  const StorageFailure({super.debugMessage, super.cause})
    : super(
        "Your data couldn't be saved on this device. Please try again. If this keeps happening, restart the app.",
      );
}

/// Required build-time configuration is missing or invalid.
final class ConfigurationFailure extends AppFailure {
  ConfigurationFailure(this.problems)
    : super('The app is not configured yet.', debugMessage: problems.join('; '));

  final List<String> problems;
}

final class UnexpectedFailure extends AppFailure {
  const UnexpectedFailure({super.debugMessage, super.cause})
    : super('Something unexpected went wrong. Please try again.');
}
