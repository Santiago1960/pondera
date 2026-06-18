import 'package:flutter_test/flutter_test.dart';
import 'package:pondera/features/scale_reading/domain/weight_converter.dart';
import 'package:pondera/features/scale_reading/domain/weight_unit.dart';

void main() {
  group('WeightUnit', () {
    test('recupera cada unidad desde su código persistido', () {
      for (final unit in WeightUnit.values) {
        expect(WeightUnit.fromCode(unit.code), unit);
      }
    });

    test('retorna null para un código desconocido', () {
      expect(WeightUnit.fromCode('unknown'), isNull);
      expect(WeightUnit.fromCode(null), isNull);
    });
  });

  group('WeightConverter', () {
    test('mantiene el valor cuando las unidades coinciden', () {
      expect(
        WeightConverter.convert(
          12.34,
          from: WeightUnit.kilogram,
          to: WeightUnit.kilogram,
        ),
        12.34,
      );
    });

    test('convierte kilogramos a todas las unidades de salida', () {
      const expectedValues = {
        WeightUnit.kilogram: 1.0,
        WeightUnit.pound: 1 / 0.45359237,
        WeightUnit.gram: 1000.0,
        WeightUnit.milligram: 1000000.0,
        WeightUnit.ounce: 35.27396195,
        WeightUnit.tonne: 0.001,
        WeightUnit.quintal: (1 / 0.45359237) / 100,
        WeightUnit.arroba: (1 / 0.45359237) / 25,
      };

      for (final entry in expectedValues.entries) {
        final result = WeightConverter.convert(
          1,
          from: WeightUnit.kilogram,
          to: entry.key,
        );
        expect(result, closeTo(entry.value, 1e-10));
      }
    });

    test('convierte libras usando la equivalencia existente', () {
      expect(
        WeightConverter.convert(
          1,
          from: WeightUnit.pound,
          to: WeightUnit.kilogram,
        ),
        closeTo(0.45359237, 1e-10),
      );
      expect(
        WeightConverter.convert(
          100,
          from: WeightUnit.pound,
          to: WeightUnit.quintal,
        ),
        closeTo(1, 1e-10),
      );
      expect(
        WeightConverter.convert(
          25,
          from: WeightUnit.pound,
          to: WeightUnit.arroba,
        ),
        closeTo(1, 1e-10),
      );
    });
  });
}
