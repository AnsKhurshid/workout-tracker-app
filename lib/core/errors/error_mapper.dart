import 'dart:async';
import 'dart:io';

import 'package:drift/drift.dart' show DriftWrappedException, InvalidDataException;
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app_failure.dart';

/// Converts any thrown object into an [AppFailure].
///
/// This is the single place that knows about third-party exception types, so
/// controllers and widgets only ever deal with [AppFailure].
AppFailure mapError(Object error) {
  if (error is AppFailure) return error;

  if (error is AuthRetryableFetchException) {
    return NetworkFailure(debugMessage: error.message, cause: error);
  }
  if (error is AuthException) return _mapAuth(error);

  if (error is PostgrestException) {
    final status = int.tryParse(error.code ?? '');
    if (status != null && status >= 500) {
      return NetworkFailure(debugMessage: error.message, cause: error);
    }
    if (error.code == 'PGRST301' || error.code == '401') {
      return AuthFailure(AuthFailureKind.sessionExpired, debugMessage: error.message, cause: error);
    }
    return UnexpectedFailure(
      debugMessage: 'Postgrest ${error.code}: ${error.message}',
      cause: error,
    );
  }

  if (error is SocketException ||
      error is TimeoutException ||
      error is HttpException ||
      error is HandshakeException) {
    return NetworkFailure(debugMessage: error.toString(), cause: error);
  }
  // package:http ClientException (thrown by supabase on connection errors).
  if (error.runtimeType.toString() == 'ClientException') {
    return NetworkFailure(debugMessage: error.toString(), cause: error);
  }

  if (error is DriftWrappedException || error is InvalidDataException) {
    return StorageFailure(debugMessage: error.toString(), cause: error);
  }
  if (error.runtimeType.toString() == 'SqliteException') {
    return StorageFailure(debugMessage: error.toString(), cause: error);
  }

  return UnexpectedFailure(debugMessage: error.toString(), cause: error);
}

AuthFailure _mapAuth(AuthException error) {
  final code = error.code;
  final message = error.message.toLowerCase();
  final kind = switch (code) {
    'invalid_credentials' => AuthFailureKind.invalidCredentials,
    'email_not_confirmed' => AuthFailureKind.emailNotConfirmed,
    'user_already_exists' || 'email_exists' => AuthFailureKind.userAlreadyExists,
    'weak_password' => AuthFailureKind.weakPassword,
    'same_password' => AuthFailureKind.samePassword,
    'session_expired' ||
    'session_not_found' ||
    'refresh_token_not_found' ||
    'refresh_token_already_used' => AuthFailureKind.sessionExpired,
    'over_request_rate_limit' ||
    'over_email_send_rate_limit' ||
    'over_sms_send_rate_limit' => AuthFailureKind.rateLimited,
    _ when message.contains('invalid login credentials') => AuthFailureKind.invalidCredentials,
    _ when message.contains('email not confirmed') => AuthFailureKind.emailNotConfirmed,
    _ when message.contains('already registered') => AuthFailureKind.userAlreadyExists,
    _ when error.statusCode == '429' => AuthFailureKind.rateLimited,
    _ => AuthFailureKind.other,
  };
  return AuthFailure(
    kind,
    debugMessage: 'Auth ${error.statusCode ?? ''} ${code ?? ''}: ${error.message}',
    cause: error,
  );
}
