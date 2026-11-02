import 'package:flutter/foundation.dart';

/// The authenticated account, independent of the auth provider's types.
@immutable
class AuthUser {
  const AuthUser({required this.id, required this.email, this.displayName});

  final String id;
  final String email;

  /// Display name given at sign-up (auth metadata). The profile's display
  /// name takes precedence once it is loaded.
  final String? displayName;

  @override
  bool operator ==(Object other) =>
      other is AuthUser &&
      other.id == id &&
      other.email == email &&
      other.displayName == displayName;

  @override
  int get hashCode => Object.hash(id, email, displayName);
}
