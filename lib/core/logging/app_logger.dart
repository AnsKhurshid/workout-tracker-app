import 'dart:developer' as developer;

import 'package:flutter/foundation.dart';

enum LogLevel { debug, info, warning, error }

/// Central logger.
///
/// Messages are redacted before they are written so that email addresses,
/// JWTs and other bearer tokens never end up in device logs. Technical detail
/// (exception type, stack trace) is kept for debugging.
class AppLogger {
  AppLogger({this.minLevel = kReleaseMode ? LogLevel.info : LogLevel.debug});

  final LogLevel minLevel;

  /// Records written in the current session, newest last. Kept small and in
  /// memory only; useful for tests and a future "send diagnostics" screen.
  final List<String> recent = <String>[];
  static const _recentLimit = 200;

  void debug(String message) => _log(LogLevel.debug, message);
  void info(String message) => _log(LogLevel.info, message);
  void warning(String message, [Object? error, StackTrace? stackTrace]) =>
      _log(LogLevel.warning, message, error, stackTrace);
  void error(String message, [Object? error, StackTrace? stackTrace]) =>
      _log(LogLevel.error, message, error, stackTrace);

  void _log(LogLevel level, String message, [Object? error, StackTrace? stackTrace]) {
    if (level.index < minLevel.index) return;
    final text = redact(error == null ? message : '$message | ${error.runtimeType}: $error');
    recent.add('[${level.name}] $text');
    if (recent.length > _recentLimit) recent.removeAt(0);
    developer.log(
      text,
      name: 'gym_tracker',
      level: switch (level) {
        LogLevel.debug => 500,
        LogLevel.info => 800,
        LogLevel.warning => 900,
        LogLevel.error => 1000,
      },
      stackTrace: stackTrace,
    );
  }

  static final _email = RegExp(r'[\w.+-]+@[\w-]+\.[\w.-]+');
  static final _jwt = RegExp(r'eyJ[\w-]+\.[\w-]+\.[\w-]+');
  static final _bearer = RegExp(r'(Bearer|apikey)\s*[:=]?\s*\S+', caseSensitive: false);
  static final _secretParam = RegExp(
    r'(access_token|refresh_token|token|password|code)=[^&\s]+',
    caseSensitive: false,
  );

  /// Removes personal data and credentials from [input].
  static String redact(String input) => input
      .replaceAll(_jwt, '<token>')
      .replaceAllMapped(_bearer, (m) => '${m.group(1)} <redacted>')
      .replaceAllMapped(_secretParam, (m) => '${m.group(1)}=<redacted>')
      .replaceAll(_email, '<email>');
}
