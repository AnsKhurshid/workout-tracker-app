import '../constants/app_constants.dart';

/// Form validators. Each returns an error message, or null when valid, so they
/// plug straight into `TextFormField.validator`.
abstract final class Validators {
  static final _email = RegExp(
    r"^[A-Za-z0-9.!#$%&'*+/=?^_`{|}~-]+@[A-Za-z0-9-]+(\.[A-Za-z0-9-]+)+$",
  );
  static final _letter = RegExp('[A-Za-z]');
  static final _digit = RegExp('[0-9]');

  static String? email(String? value) {
    final v = value?.trim() ?? '';
    if (v.isEmpty) return 'Enter your email address.';
    if (v.length > 254 || !_email.hasMatch(v)) return 'Enter a valid email address.';
    return null;
  }

  /// Rules for a new password. Keep in sync with the Supabase project's
  /// password policy (Authentication -> Providers -> Email).
  static String? newPassword(String? value) {
    final v = value ?? '';
    if (v.isEmpty) return 'Enter a password.';
    if (v.length < AppConstants.passwordMinLength) {
      return 'Use at least ${AppConstants.passwordMinLength} characters.';
    }
    if (v.length > AppConstants.passwordMaxLength) {
      return 'Use at most ${AppConstants.passwordMaxLength} characters.';
    }
    if (!_letter.hasMatch(v) || !_digit.hasMatch(v)) {
      return 'Include at least one letter and one number.';
    }
    return null;
  }

  /// For the login form: only checks presence, never reveals the rules.
  static String? existingPassword(String? value) =>
      (value ?? '').isEmpty ? 'Enter your password.' : null;

  static String? Function(String?) confirmPassword(String Function() original) => (value) {
    if ((value ?? '').isEmpty) return 'Confirm your password.';
    if (value != original()) return "Passwords don't match.";
    return null;
  };

  static String? displayName(String? value) {
    final v = value?.trim() ?? '';
    if (v.isEmpty) return 'Enter your name.';
    if (v.length > AppConstants.displayNameMaxLength) {
      return 'Use at most ${AppConstants.displayNameMaxLength} characters.';
    }
    return null;
  }
}
