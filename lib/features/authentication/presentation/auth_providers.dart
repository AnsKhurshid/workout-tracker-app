import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers.dart';
import '../../../models/auth_user.dart';
import '../data/supabase_auth_repository.dart';
import '../domain/auth_repository.dart';
import '../domain/auth_status.dart';

/// Only created after app startup has initialised Supabase.
final authRepositoryProvider = Provider<AuthRepository>((ref) {
  final repository = SupabaseAuthRepository(
    ref.watch(supabaseServiceProvider).client.auth,
    ref.watch(appLoggerProvider),
  );
  ref.onDispose(repository.dispose);
  return repository;
});

/// Current [AuthStatus], updated on every auth event.
final authStatusProvider = StreamProvider<AuthStatus>((ref) async* {
  final repository = ref.watch(authRepositoryProvider);
  yield repository.currentStatus;
  yield* repository.statusChanges();
});

/// The signed-in user, or null. Screens inside the authenticated shell can
/// rely on this being non-null.
final currentUserProvider = Provider<AuthUser?>((ref) {
  final status = ref.watch(authStatusProvider);
  return status.value?.user ?? ref.watch(authRepositoryProvider).currentStatus.user;
});
