import 'package:flutter_test/flutter_test.dart';
import 'package:gym_tracker/core/config/env_config.dart';
import 'package:gym_tracker/core/errors/app_failure.dart';

void main() {
  test('valid configuration has no problems', () {
    const env = EnvConfig(supabaseUrl: 'https://abcd.supabase.co', supabasePublishableKey: 'key');
    expect(env.isValid, isTrue);
    expect(env.validate, returnsNormally);
  });

  test('missing values are reported by name', () {
    const env = EnvConfig(supabaseUrl: '', supabasePublishableKey: ' ');
    expect(env.problems, ['SUPABASE_URL is not set', 'SUPABASE_PUBLISHABLE_KEY is not set']);
    expect(env.validate, throwsA(isA<ConfigurationFailure>()));
  });

  test('rejects invalid URLs and untouched placeholders', () {
    expect(
      const EnvConfig(supabaseUrl: 'not a url', supabasePublishableKey: 'k').problems.single,
      contains('not a valid'),
    );
    expect(
      const EnvConfig(
        supabaseUrl: 'https://YOUR-PROJECT-REF.supabase.co',
        supabasePublishableKey: 'YOUR-PUBLISHABLE-KEY',
      ).problems,
      hasLength(2),
    );
  });

  test('fromEnvironment is empty (invalid) when no defines are passed', () {
    expect(EnvConfig.fromEnvironment().isValid, isFalse);
  });
}
