import '../features/authentication/domain/auth_status.dart';
import 'routes.dart';

/// Route guard, as a pure function so it can be unit-tested.
///
/// Returns the path to redirect to, or null to allow [location].
String? authRedirect(AuthStatus status, String location) {
  final path = Uri.parse(location).path;
  final isPublic = Routes.publicRoutes.contains(path);

  return switch (status) {
    // Signed out: only public routes; everything else goes to welcome.
    Unauthenticated() => isPublic ? null : Routes.welcome,
    // Reset link opened: the only allowed screen is "set new password".
    PasswordRecovery() => path == Routes.resetPassword ? null : Routes.resetPassword,
    // Signed in: keep out of the auth screens.
    Authenticated() =>
      (isPublic || path == Routes.resetPassword || path == '/') ? Routes.home : null,
  };
}
