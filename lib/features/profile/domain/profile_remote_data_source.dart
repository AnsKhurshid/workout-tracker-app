import 'package:flutter/foundation.dart';

/// A `public.profiles` row as exchanged with the server.
@immutable
class RemoteProfile {
  const RemoteProfile({
    required this.id,
    required this.displayName,
    required this.weightUnit,
    required this.defaultRestSeconds,
    required this.autoStartRestTimer,
    required this.createdAt,
    required this.updatedAt,
    this.deletedAt,
    this.serverUpdatedAt,
  });

  factory RemoteProfile.fromJson(Map<String, dynamic> json) => RemoteProfile(
    id: json['id'] as String,
    displayName: json['display_name'] as String?,
    weightUnit: json['weight_unit'] as String? ?? 'kg',
    defaultRestSeconds: (json['default_rest_seconds'] as num?)?.toInt() ?? 90,
    autoStartRestTimer: json['auto_start_rest_timer'] as bool? ?? true,
    createdAt: DateTime.parse(json['created_at'] as String).toUtc(),
    updatedAt: DateTime.parse(json['updated_at'] as String).toUtc(),
    deletedAt: json['deleted_at'] == null
        ? null
        : DateTime.parse(json['deleted_at'] as String).toUtc(),
    serverUpdatedAt: json['server_updated_at'] == null
        ? null
        : DateTime.parse(json['server_updated_at'] as String).toUtc(),
  );

  final String id;
  final String? displayName;
  final String weightUnit;
  final int defaultRestSeconds;
  final bool autoStartRestTimer;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? deletedAt;
  final DateTime? serverUpdatedAt;

  /// Columns the client may write. `server_updated_at` is set by the server.
  Map<String, dynamic> toUpsertJson() => {
    'id': id,
    'display_name': displayName,
    'weight_unit': weightUnit,
    'default_rest_seconds': defaultRestSeconds,
    'auto_start_rest_timer': autoStartRestTimer,
    'created_at': createdAt.toUtc().toIso8601String(),
    'updated_at': updatedAt.toUtc().toIso8601String(),
    'deleted_at': deletedAt?.toUtc().toIso8601String(),
  };
}

/// Server access for profiles. Implementations throw raw exceptions; the
/// repository maps them.
abstract interface class ProfileRemoteDataSource {
  Future<RemoteProfile?> fetch(String userId);

  /// Idempotent upsert. The server ignores it if its copy is newer.
  Future<void> upsert(RemoteProfile profile);
}
