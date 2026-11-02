import '../errors/app_failure.dart';

/// Build-time configuration, supplied with `--dart-define-from-file=.env`.
///
/// Values are compiled into the app; nothing is read from a bundled file at
/// runtime. Only public values (the Supabase URL and publishable/anon key)
/// belong here.
class EnvConfig {
  const EnvConfig({required this.supabaseUrl, required this.supabasePublishableKey});

  /// Reads the values passed with `--dart-define` / `--dart-define-from-file`.
  factory EnvConfig.fromEnvironment() => const EnvConfig(
    supabaseUrl: String.fromEnvironment('SUPABASE_URL'),
    supabasePublishableKey: String.fromEnvironment('SUPABASE_PUBLISHABLE_KEY'),
  );

  final String supabaseUrl;
  final String supabasePublishableKey;

  /// Names of the settings that are missing or invalid. Empty when valid.
  List<String> get problems {
    final problems = <String>[];
    final uri = Uri.tryParse(supabaseUrl.trim());
    if (supabaseUrl.trim().isEmpty) {
      problems.add('SUPABASE_URL is not set');
    } else if (uri == null ||
        !(uri.scheme == 'https' || uri.scheme == 'http') ||
        uri.host.isEmpty) {
      problems.add('SUPABASE_URL is not a valid http(s) URL');
    } else if (supabaseUrl.contains('YOUR-PROJECT-REF')) {
      problems.add('SUPABASE_URL still contains the example placeholder');
    }
    if (supabasePublishableKey.trim().isEmpty) {
      problems.add('SUPABASE_PUBLISHABLE_KEY is not set');
    } else if (supabasePublishableKey.contains('YOUR-PUBLISHABLE')) {
      problems.add('SUPABASE_PUBLISHABLE_KEY still contains the example placeholder');
    }
    return problems;
  }

  bool get isValid => problems.isEmpty;

  /// Throws a [ConfigurationFailure] describing every problem found.
  void validate() {
    final found = problems;
    if (found.isNotEmpty) {
      throw ConfigurationFailure(found);
    }
  }
}
