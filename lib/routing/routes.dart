/// Route paths. Paths are deep-link compatible (`/profile` etc.).
abstract final class Routes {
  // Public (signed-out) routes.
  static const welcome = '/welcome';
  static const login = '/login';
  static const register = '/register';
  static const checkEmail = '/register/check-email';
  static const forgotPassword = '/forgot-password';

  // Password recovery (temporary session from the reset email link).
  static const resetPassword = '/reset-password';

  // Authenticated shell tabs.
  static const home = '/home';
  static const workouts = '/workouts';
  static const progress = '/progress';
  static const profile = '/profile';

  static const publicRoutes = {welcome, login, register, checkEmail, forgotPassword};
}
