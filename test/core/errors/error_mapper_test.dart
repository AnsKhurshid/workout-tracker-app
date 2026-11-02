import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:gym_tracker/core/errors/app_failure.dart';
import 'package:gym_tracker/core/errors/error_mapper.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  test('auth error codes map to specific failures', () {
    AuthFailureKind kind(AuthException e) => (mapError(e) as AuthFailure).kind;
    expect(
      kind(const AuthException('x', code: 'invalid_credentials')),
      AuthFailureKind.invalidCredentials,
    );
    expect(
      kind(const AuthException('x', code: 'email_not_confirmed')),
      AuthFailureKind.emailNotConfirmed,
    );
    expect(
      kind(const AuthException('x', code: 'user_already_exists')),
      AuthFailureKind.userAlreadyExists,
    );
    expect(kind(const AuthException('x', code: 'weak_password')), AuthFailureKind.weakPassword);
    expect(
      kind(const AuthException('x', code: 'over_email_send_rate_limit')),
      AuthFailureKind.rateLimited,
    );
    expect(
      kind(const AuthException('x', code: 'refresh_token_not_found')),
      AuthFailureKind.sessionExpired,
    );
    expect(
      kind(const AuthException('Invalid login credentials')),
      AuthFailureKind.invalidCredentials,
    );
    expect(kind(const AuthException('???')), AuthFailureKind.other);
  });

  test('connection problems map to NetworkFailure', () {
    expect(mapError(const SocketException('no route')), isA<NetworkFailure>());
    expect(mapError(TimeoutException('slow')), isA<NetworkFailure>());
    expect(mapError(AuthRetryableFetchException(message: 'offline')), isA<NetworkFailure>());
    expect(mapError(const PostgrestException(message: 'down', code: '503')), isA<NetworkFailure>());
  });

  test('unknown errors become UnexpectedFailure and AppFailures pass through', () {
    expect(mapError(StateError('bug')), isA<UnexpectedFailure>());
    const failure = ValidationFailure('bad');
    expect(identical(mapError(failure), failure), isTrue);
  });

  test('user messages never contain technical detail', () {
    final failure = mapError(
      const AuthException('secret internal detail', code: 'invalid_credentials'),
    );
    expect(failure.userMessage, isNot(contains('secret')));
    expect(failure.debugMessage, contains('secret internal detail'));
  });
}
