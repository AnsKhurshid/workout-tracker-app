import 'package:uuid/uuid.dart';

/// Generates primary keys on the device.
///
/// UUIDv7 is time-ordered, which keeps B-tree indexes compact, and is unique
/// across devices without coordination, so records created offline never
/// collide when they are synced.
class IdGenerator {
  const IdGenerator();

  static const _uuid = Uuid();

  String newId() => _uuid.v7();
}
