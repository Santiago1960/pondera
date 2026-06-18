import 'weight_unit.dart';

class WeightConverter {
  const WeightConverter._();

  static const _kilogramsPerPound = 0.45359237;

  static double convert(
    double weight, {
    required WeightUnit from,
    required WeightUnit to,
  }) {
    if (from == to) {
      return weight;
    }

    final weightInKilograms = _toKilograms(weight, from);
    return _fromKilograms(weightInKilograms, to);
  }

  static double _toKilograms(double weight, WeightUnit unit) {
    return switch (unit) {
      WeightUnit.kilogram => weight,
      WeightUnit.pound => weight * _kilogramsPerPound,
      WeightUnit.gram => weight / 1000,
      WeightUnit.milligram => weight / 1000000,
      WeightUnit.ounce => weight / 35.27396195,
      WeightUnit.tonne => weight * 1000,
      WeightUnit.quintal => weight * 100 * _kilogramsPerPound,
      WeightUnit.arroba => weight * 25 * _kilogramsPerPound,
    };
  }

  static double _fromKilograms(double weight, WeightUnit unit) {
    return switch (unit) {
      WeightUnit.kilogram => weight,
      WeightUnit.pound => weight / _kilogramsPerPound,
      WeightUnit.gram => weight * 1000,
      WeightUnit.milligram => weight * 1000000,
      WeightUnit.ounce => weight * 35.27396195,
      WeightUnit.tonne => weight / 1000,
      WeightUnit.quintal => (weight / _kilogramsPerPound) / 100,
      WeightUnit.arroba => (weight / _kilogramsPerPound) / 25,
    };
  }
}
