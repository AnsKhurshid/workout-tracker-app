/// Names of synced tables, as they appear in Postgres and in the outbox.
///
/// The order is the push order: parents before children, so foreign keys hold
/// on the server. Later phases add the workout tables here.
abstract final class SyncTables {
  static const profiles = 'profiles';

  static const pushOrder = <String>[profiles];
}
