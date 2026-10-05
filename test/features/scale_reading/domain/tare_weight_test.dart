import 'package:flutter_test/flutter_test.dart';
import 'package:pondera/features/scale_reading/domain/tare_weight.dart';
import 'package:pondera/features/scale_reading/domain/weight_unit.dart';
import 'package:pondera/features/scale_reading/domain/weight_capture_controller.dart';

void main() {
  test(
    'Print y automático rechazan netos no positivos sin consumir el ciclo',
    () {
      for (final mode in [
        WeightCaptureMode.indicatorPrint,
        WeightCaptureMode.automaticStable,
      ]) {
        final controller = WeightCaptureController(
          configuration: WeightCaptureConfiguration(mode: mode),
        );
        final start = DateTime(2026);
        const zero = WeightCaptureReading(
          value: 0,
          unit: WeightUnit.kilogram,
          captureText: '-2',
          canCaptureNetWeight: false,
        );
        const invalid = WeightCaptureReading(
          value: 1,
          unit: WeightUnit.kilogram,
          captureText: '-1',
          canCaptureNetWeight: false,
        );
        controller.onReading(zero, receivedAt: start);
        controller.onReading(
          invalid,
          receivedAt: start.add(const Duration(seconds: 2)),
        );
        expect(
          controller
              .onReading(
                invalid,
                receivedAt: start.add(const Duration(seconds: 4)),
              )
              .outcome,
          WeightCaptureOutcome.netWeightRejected,
        );
        expect(controller.waitingForZero, isFalse);
      }
    },
  );
  test('tara cero conserva el peso y tara convierte unidades', () {
    expect(const TareWeight().subtractFrom(120, WeightUnit.kilogram), 120);
    expect(
      const TareWeight(value: 1.5).subtractFrom(120, WeightUnit.kilogram),
      118.5,
    );
    expect(
      const TareWeight(
        value: 1000,
        unit: WeightUnit.gram,
      ).subtractFrom(10, WeightUnit.kilogram),
      9,
    );
    expect(
      const TareWeight(value: 1).inUnit(WeightUnit.pound),
      closeTo(2.20462262, 1e-7),
    );
  });
  test('valida entradas sin aceptar negativos o separadores ambiguos', () {
    expect(TareWeight.parse('1,50'), 1.5);
    expect(TareWeight.parse('1.50'), 1.5);
    for (final value in ['', '-1', 'NaN', 'Infinity', '1,000.50']) {
      expect(TareWeight.parse(value), isNull);
    }
  });
  test('neto rechazado no consume el ciclo y el rearme sigue usando bruto', () {
    final controller = WeightCaptureController(
      configuration: const WeightCaptureConfiguration(
        mode: WeightCaptureMode.keyboardF12,
      ),
    );
    WeightCaptureReading reading(double gross, {bool valid = true}) =>
        WeightCaptureReading(
          value: gross,
          unit: WeightUnit.kilogram,
          captureText: '${gross - 2}',
          canCaptureNetWeight: valid,
        );
    controller.onReading(reading(0, valid: false), receivedAt: DateTime(2026));
    expect(controller.waitingForZero, isFalse);
    controller.onReading(reading(1, valid: false), receivedAt: DateTime(2026));
    expect(
      controller.onF12Pressed().outcome,
      WeightCaptureOutcome.netWeightRejected,
    );
    expect(controller.waitingForZero, isFalse);
    controller.onReading(reading(10), receivedAt: DateTime(2026));
    expect(controller.onF12Pressed().reading!.captureText, '8.0');
    controller.clearReading();
    expect(controller.waitingForZero, isTrue);
  });
}
