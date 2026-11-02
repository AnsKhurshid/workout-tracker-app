import 'package:flutter/foundation.dart';

import 'weight_unit.dart';

/// The signed-in user's profile and preferences (mirrors `public.profiles`).
@immutable
class UserProfile {
  const UserProfile({
    required this.id,
    required this.displayName,
    required this.weightUnit,
    required this.defaultRestSeconds,
    required this.autoStartRestTimer,
    required this.updatedAt,
  });

  final String id;
  final String? displayName;
  final WeightUnit weightUnit;
  final int defaultRestSeconds;
  final bool autoStartRestTimer;
  final DateTime updatedAt;

  @override
  bool operator ==(Object other) =>
      other is UserProfile &&
      other.id == id &&
      other.displayName == displayName &&
      other.weightUnit == weightUnit &&
      other.defaultRestSeconds == defaultRestSeconds &&
      other.autoStartRestTimer == autoStartRestTimer &&
      other.updatedAt == updatedAt;

  @override
  int get hashCode =>
      Object.hash(id, displayName, weightUnit, defaultRestSeconds, autoStartRestTimer, updatedAt);
}
