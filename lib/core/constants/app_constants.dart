/// App-wide constants. Values that are business rules (validation limits)
/// mirror the CHECK constraints in `supabase/migrations`.
abstract final class AppConstants {
  static const appName = 'Gym Tracker';

  /// Deep link that Supabase redirects to from confirmation and password
  /// reset emails. Must be listed under Authentication -> URL Configuration
  /// -> Redirect URLs in the Supabase dashboard.
  static const authRedirectUrl = 'com.anskhurshid.gymtracker://auth-callback';

  /// Local SQLite database file name (without extension).
  static const databaseName = 'gym_tracker';

  static const displayNameMaxLength = 50;
  static const passwordMinLength = 8;
  static const passwordMaxLength = 72; // bcrypt limit used by Supabase Auth

  static const defaultRestSeconds = 90;
}
