import 'package:flutter_test/flutter_test.dart';
import 'package:gym_tracker/core/utils/weight_converter.dart';
import 'package:gym_tracker/models/weight_unit.dart';

void main() {
  test('kg input is stored unchanged (rounded to 3 decimals)', () {
    expect(WeightConverter.toKg(42.5, WeightUnit.kg), 42.5);
    expect(WeightConverter.toKg(20.12345, WeightUnit.kg), 20.123);
  });

  test('lbs input is converted with the exact factor', () {
    expect(WeightConverter.toKg(100, WeightUnit.lbs), 45.359);
    expect(WeightConverter.toKg(45, WeightUnit.lbs), 20.412);
  });

  test('common lbs values survive a round trip at display precision', () {
    for (final lbs in [2.5, 5, 45, 135, 225, 315, 99.75]) {
      final stored = WeightConverter.toKg(lbs.toDouble(), WeightUnit.lbs);
      expect(
        WeightConverter.format(stored, WeightUnit.lbs),
        _trim(lbs.toDouble()),
        reason: '$lbs lb',
      );
    }
  });

  test('format trims trailing zeros', () {
    expect(WeightConverter.format(45, WeightUnit.kg), '45');
    expect(WeightConverter.format(42.5, WeightUnit.kg), '42.5');
    expect(WeightConverter.format(42.25, WeightUnit.kg), '42.25');
  });

  test('weight unit maps to and from the database value', () {
    expect(WeightUnit.fromDb('lbs'), WeightUnit.lbs);
    expect(WeightUnit.fromDb('kg'), WeightUnit.kg);
    expect(WeightUnit.fromDb(null), WeightUnit.kg);
    expect(WeightUnit.lbs.dbValue, 'lbs');
  });
}

String _trim(double v) {
  var s = v.toStringAsFixed(2);
  s = s.replaceFirst(RegExp(r'0+$'), '').replaceFirst(RegExp(r'\.$'), '');
  return s;
}
