/// The unit the user prefers for entering and viewing weights.
///
/// Weights are always stored in kilograms; this only affects display and
/// input, so changing it never rewrites history.
enum WeightUnit {
  kg('kg', 'KG'),
  lbs('lbs', 'LBS');

  const WeightUnit(this.dbValue, this.label);

  /// Value stored in the database (matches the Postgres `weight_unit` enum).
  final String dbValue;

  /// Short label shown in the UI.
  final String label;

  static WeightUnit fromDb(String? value) =>
      WeightUnit.values.firstWhere((u) => u.dbValue == value, orElse: () => WeightUnit.kg);
}
