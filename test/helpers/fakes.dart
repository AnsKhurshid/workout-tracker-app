import 'dart:async';

import 'package:gym_tracker/core/config/env_config.dart';
import 'package:gym_tracker/core/errors/app_failure.dart';
import 'package:gym_tracker/core/services/supabase_service.dart';
import 'package:gym_tracker/features/authentication/domain/auth_repository.dart';
import 'package:gym_tracker/features/authentication/domain/auth_status.dart';
import 'package:gym_tracker/features/profile/domain/profile_remote_data_source.dart';
import 'package:gym_tracker/models/auth_user.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show SupabaseClient;

const testUser = AuthUser(
  id: '0190f1d2-0000-7000-8000-000000000001',
  email: 'sam@example.com',
  displayName: 'Sam',
);

const validEnv = EnvConfig(
  supabaseUrl: 'https://abcd.supabase.co',
  supabasePublishableKey: 'sb_publishable_test',
);

/// In-memory [AuthRepository] for widget and controller tests.
class FakeAuthRepository implements AuthRepository {
  FakeAuthRepository([this._status = const Unauthenticated()]);

  AuthStatus _status;
  final _controller = StreamController<AuthStatus>.broadcast();
  final calls = <String>[];

  /// When set, the next call throws it.
  AppFailure? nextError;
  SignUpOutcome signUpOutcome = SignUpOutcome.confirmationRequired;

  void setStatus(AuthStatus status) {
    _status = status;
    _controller.add(status);
  }

  void _maybeThrow() {
    final error = nextError;
    if (error != null) {
      nextError = null;
      throw error;
    }
  }

  @override
  AuthStatus get currentStatus => _status;

  @override
  Stream<AuthStatus> statusChanges() => _controller.stream;

  @override
  Future<void> signIn({required String email, required String password}) async {
    calls.add('signIn:$email');
    _maybeThrow();
    setStatus(
      Authenticated(AuthUser(id: testUser.id, email: email, displayName: testUser.displayName)),
    );
  }

  @override
  Future<SignUpOutcome> signUp({
    required String displayName,
    required String email,
    required String password,
  }) async {
    calls.add('signUp:$displayName:$email');
    _maybeThrow();
    if (signUpOutcome == SignUpOutcome.signedIn) {
      setStatus(Authenticated(AuthUser(id: testUser.id, email: email, displayName: displayName)));
    }
    return signUpOutcome;
  }

  @override
  Future<void> sendPasswordResetEmail(String email) async {
    calls.add('reset:$email');
    _maybeThrow();
  }

  @override
  Future<void> updatePassword(String newPassword) async {
    calls.add('updatePassword');
    _maybeThrow();
    final user = _status.user;
    if (user != null) setStatus(Authenticated(user));
  }

  @override
  Future<void> signOut() async {
    calls.add('signOut');
    _maybeThrow();
    setStatus(const Unauthenticated());
  }
}

/// [SupabaseService] that never touches the network.
class FakeSupabaseService implements SupabaseService {
  int initializeCalls = 0;
  Object? initializeError;

  @override
  Future<void> initialize(EnvConfig env) async {
    initializeCalls++;
    final error = initializeError;
    if (error != null) throw error;
  }

  @override
  SupabaseClient get client => throw UnsupportedError('No Supabase client in tests');
}

/// In-memory stand-in for the `profiles` table on the server, including the
/// server's last-write-wins rule.
class FakeProfileRemote implements ProfileRemoteDataSource {
  final rows = <String, RemoteProfile>{};
  Object? fetchError;
  Object? upsertError;
  int upserts = 0;

  @override
  Future<RemoteProfile?> fetch(String userId) async {
    final error = fetchError;
    if (error != null) throw error;
    return rows[userId];
  }

  @override
  Future<void> upsert(RemoteProfile profile) async {
    final error = upsertError;
    if (error != null) throw error;
    upserts++;
    final existing = rows[profile.id];
    if (existing != null && profile.updatedAt.isBefore(existing.updatedAt)) return;
    rows[profile.id] = profile;
  }
}

RemoteProfile remoteProfile({
  String id = '0190f1d2-0000-7000-8000-000000000001',
  String? displayName = 'Sam',
  String weightUnit = 'kg',
  required DateTime updatedAt,
}) => RemoteProfile(
  id: id,
  displayName: displayName,
  weightUnit: weightUnit,
  defaultRestSeconds: 90,
  autoStartRestTimer: true,
  createdAt: DateTime.utc(2026, 1, 1),
  updatedAt: updatedAt,
);
