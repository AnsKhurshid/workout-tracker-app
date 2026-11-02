import '../../../models/auth_user.dart';
import '../../../models/user_profile.dart';
import '../../../models/weight_unit.dart';

/// The signed-in user's profile. Reads and writes go to the local database
/// first; remote sync happens in the background.
abstract interface class ProfileRepository {
  /// Emits the locally stored profile for [userId] (null until loaded).
  Stream<UserProfile?> watchProfile(String userId);

  /// Makes sure a local profile exists for [user] and refreshes it from the
  /// server when possible. Safe to call offline.
  Future<void> loadProfile(AuthUser user);

  Future<void> updateWeightUnit(String userId, WeightUnit unit);

  Future<void> updateDisplayName(String userId, String displayName);

  /// True while this user has local changes not yet confirmed by the server.
  Stream<bool> watchHasPendingChanges(String userId);

  /// Tries to upload this user's pending profile change now.
  Future<void> pushPendingChanges(String userId);
}
