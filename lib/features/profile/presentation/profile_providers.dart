import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/error_mapper.dart';
import '../../../core/providers.dart';
import '../../../models/user_profile.dart';
import '../../../models/weight_unit.dart';
import '../../authentication/presentation/auth_providers.dart';
import '../data/profile_repository_impl.dart';
import '../data/supabase_profile_remote_data_source.dart';
import '../domain/profile_remote_data_source.dart';
import '../domain/profile_repository.dart';

final profileRemoteDataSourceProvider = Provider<ProfileRemoteDataSource>(
  (ref) => SupabaseProfileRemoteDataSource(ref.watch(supabaseServiceProvider).client),
);

final profileRepositoryProvider = Provider<ProfileRepository>(
  (ref) => ProfileRepositoryImpl(
    db: ref.watch(appDatabaseProvider),
    outbox: ref.watch(outboxProvider),
    remote: ref.watch(profileRemoteDataSourceProvider),
    clock: ref.watch(clockProvider),
    logger: ref.watch(appLoggerProvider),
  ),
);

/// The current user's profile from the local database. Starts a background
/// refresh from the server whenever the signed-in user changes.
final currentProfileProvider = StreamProvider<UserProfile?>((ref) {
  final user = ref.watch(currentUserProvider);
  if (user == null) return Stream.value(null);
  final repository = ref.watch(profileRepositoryProvider);
  unawaited(
    repository.loadProfile(user).catchError((Object e, StackTrace st) {
      ref.read(appLoggerProvider).error('Loading profile failed', e, st);
    }),
  );
  return repository.watchProfile(user.id);
});

final profileHasPendingChangesProvider = StreamProvider<bool>((ref) {
  final user = ref.watch(currentUserProvider);
  if (user == null) return Stream.value(false);
  return ref.watch(profileRepositoryProvider).watchHasPendingChanges(user.id);
});

/// Profile edits. Returns null on success or a user-facing error message.
class ProfileActions {
  ProfileActions(this._ref);

  final Ref _ref;

  Future<String?> _run(Future<void> Function(ProfileRepository repo, String userId) action) async {
    final user = _ref.read(currentUserProvider);
    if (user == null) return 'You are not signed in.';
    try {
      await action(_ref.read(profileRepositoryProvider), user.id);
      return null;
    } catch (e) {
      return mapError(e).userMessage;
    }
  }

  Future<String?> setWeightUnit(WeightUnit unit) =>
      _run((repo, id) => repo.updateWeightUnit(id, unit));

  Future<String?> setDisplayName(String name) =>
      _run((repo, id) => repo.updateDisplayName(id, name));
}

final profileActionsProvider = Provider<ProfileActions>(ProfileActions.new);
