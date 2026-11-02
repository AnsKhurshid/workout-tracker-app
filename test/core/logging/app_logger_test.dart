import 'package:flutter_test/flutter_test.dart';
import 'package:gym_tracker/core/logging/app_logger.dart';

void main() {
  test('redacts emails, JWTs and secrets', () {
    const jwt = 'eyJhbGciOiJIUzI1NiJ9.eyJzdWIiOiIxIn0.c2lnbmF0dXJl';
    final text = AppLogger.redact(
      'user sam@example.com token $jwt url ?access_token=abc&code=xyz Bearer abc.def apikey: sb_123',
    );
    expect(text, isNot(contains('sam@example.com')));
    expect(text, isNot(contains(jwt)));
    expect(text, isNot(contains('access_token=abc')));
    expect(text, isNot(contains('code=xyz')));
    expect(text, isNot(contains('sb_123')));
    expect(text, contains('<email>'));
    expect(text, contains('<token>'));
  });

  test('keeps redacted records and respects the minimum level', () {
    final logger = AppLogger(minLevel: LogLevel.info)
      ..debug('hidden')
      ..info('signed in as sam@example.com')
      ..error('failed', StateError('boom'));
    expect(logger.recent, hasLength(2));
    expect(logger.recent.first, '[info] signed in as <email>');
    expect(logger.recent.last, contains('StateError'));
  });
}
