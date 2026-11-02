import '../../models/weight_unit.dart';

/// Converts between the canonical storage unit (kilograms) and display units.
abstract final class WeightConverter {
  /// Exact, by international definition.
  static const kgPerLb = 0.45359237;

  /// Stored weights keep 3 decimals (matches `numeric(8,3)` in Postgres).
  static double roundStored(double kg) => (kg * 1000).roundToDouble() / 1000;

  /// Converts a value the user entered in [unit] to kilograms for storage.
  static double toKg(double value, WeightUnit unit) => roundStored(switch (unit) {
    WeightUnit.kg => value,
    WeightUnit.lbs => value * kgPerLb,
  });

  /// Converts a stored kilogram value to [unit] for display.
  static double fromKg(double kg, WeightUnit unit) => switch (unit) {
    WeightUnit.kg => kg,
    WeightUnit.lbs => kg / kgPerLb,
  };

  /// Formats a stored kilogram value in [unit], trimming trailing zeros
  /// (e.g. 42.5, 45, 99.21).
  static String format(double kg, WeightUnit unit, {int maxDecimals = 2}) {
    final value = fromKg(kg, unit);
    var text = value.toStringAsFixed(maxDecimals);
    if (text.contains('.')) {
      text = text.replaceFirst(RegExp(r'0+$'), '').replaceFirst(RegExp(r'\.$'), '');
    }
    return text;
  }
}
