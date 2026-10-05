import 'weight_converter.dart';
import 'weight_unit.dart';

/// Session-only manual tare. Its physical weight is independent of output units.
class TareWeight {
  const TareWeight({this.value = 0, this.unit = WeightUnit.kilogram});

  final double value;
  final WeightUnit unit;

  static double? parse(String text) {
    final normalized = text.trim();
    if (!RegExp(r'^\d+(?:[.,]\d+)?$').hasMatch(normalized)) return null;
    final value = double.tryParse(normalized.replaceAll(',', '.'));
    return value != null && value.isFinite && value >= 0 ? value : null;
  }

  double inUnit(WeightUnit target) =>
      WeightConverter.convert(value, from: unit, to: target);

  double subtractFrom(double gross, WeightUnit grossUnit) =>
      value == 0 ? gross : gross - inUnit(grossUnit);
}
