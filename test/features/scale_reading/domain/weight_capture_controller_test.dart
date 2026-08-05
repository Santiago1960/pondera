import 'package:flutter_test/flutter_test.dart';
import 'package:pondera/features/scale_reading/domain/weight_capture_controller.dart';
import 'package:pondera/features/scale_reading/domain/weight_unit.dart';

void main() {
  test('solo los modos continuos requieren polling activo', () {
    expect(
      WeightCaptureMode.indicatorPrint.requiresContinuousInput,
      isFalse,
    );
    expect(WeightCaptureMode.keyboardF12.requiresContinuousInput, isTrue);
    expect(WeightCaptureMode.automaticStable.requiresContinuousInput, isTrue);
  });

  final start = DateTime.utc(2026, 1, 1);

  WeightCaptureReading reading(
    double value, {
    String? text,
    WeightUnit unit = WeightUnit.kilogram,
  }) {
    return WeightCaptureReading(
      value: value,
      unit: unit,
      captureText: text ?? value.toStringAsFixed(3),
    );
  }

  group('WeightCaptureRange', () {
    test('acepta límites inclusivos y rechaza valores exteriores', () {
      const range = WeightCaptureRange.restricted(
        minimum: 0.150,
        maximum: 0.250,
        unit: WeightUnit.kilogram,
      );

      expect(range.accepts(0.149, WeightUnit.kilogram), isFalse);
      expect(range.accepts(0.150, WeightUnit.kilogram), isTrue);
      expect(range.accepts(0.250, WeightUnit.kilogram), isTrue);
      expect(range.accepts(0.251, WeightUnit.kilogram), isFalse);
    });

    test('convierte la lectura a la unidad propia del rango', () {
      const range = WeightCaptureRange.restricted(
        minimum: 0.150,
        maximum: 0.250,
        unit: WeightUnit.kilogram,
      );

      expect(range.accepts(0.44, WeightUnit.pound), isTrue);
      expect(
        range.convertedValue(0.44, WeightUnit.pound),
        closeTo(0.19958, 1e-5),
      );
    });

    test('la configuración restringida inválida falla de forma cerrada', () {
      const incomplete = WeightCaptureRange.restricted(
        minimum: null,
        maximum: 0.250,
        unit: WeightUnit.kilogram,
      );
      const reversed = WeightCaptureRange.restricted(
        minimum: 0.250,
        maximum: 0.150,
        unit: WeightUnit.kilogram,
      );

      expect(incomplete.validationError, isNotNull);
      expect(incomplete.accepts(0.200, WeightUnit.kilogram), isFalse);
      expect(reversed.validationError, isNotNull);
      expect(reversed.accepts(0.200, WeightUnit.kilogram), isFalse);
    });
  });

  group('modo Print del indicador', () {
    test('mantiene la captura actual y su pausa de 1500 ms', () {
      final controller = WeightCaptureController();

      expect(
        controller.onReading(reading(0.180), receivedAt: start).outcome,
        WeightCaptureOutcome.capture,
      );
      expect(
        controller
            .onReading(
              reading(0.181),
              receivedAt: start.add(const Duration(milliseconds: 1500)),
            )
            .outcome,
        WeightCaptureOutcome.none,
      );
      expect(
        controller
            .onReading(
              reading(0.182),
              receivedAt: start.add(const Duration(milliseconds: 1501)),
            )
            .outcome,
        WeightCaptureOutcome.capture,
      );
    });

    test('rechaza cero y rango inválido sin activar espera por cero', () {
      final controller = WeightCaptureController(
        configuration: const WeightCaptureConfiguration(
          range: WeightCaptureRange.restricted(
            minimum: 0.150,
            maximum: 0.250,
            unit: WeightUnit.kilogram,
          ),
        ),
      );

      expect(
        controller.onReading(reading(0), receivedAt: start).outcome,
        WeightCaptureOutcome.zeroRejected,
      );
      expect(
        controller
            .onReading(
              reading(0.120),
              receivedAt: start.add(const Duration(seconds: 2)),
            )
            .outcome,
        WeightCaptureOutcome.outOfRange,
      );
      expect(controller.waitingForZero, isFalse);
      expect(
        controller
            .onReading(
              reading(0.180),
              receivedAt: start.add(const Duration(seconds: 3)),
            )
            .outcome,
        WeightCaptureOutcome.capture,
      );
    });

    test('rechaza cada nuevo Print fuera de rango', () {
      final controller = WeightCaptureController(
        configuration: const WeightCaptureConfiguration(
          range: WeightCaptureRange.restricted(
            minimum: 0.150,
            maximum: 0.250,
            unit: WeightUnit.kilogram,
          ),
        ),
      );

      expect(
        controller.onReading(reading(0.120), receivedAt: start).outcome,
        WeightCaptureOutcome.outOfRange,
      );
      expect(
        controller
            .onReading(
              reading(0.120),
              receivedAt: start.add(const Duration(seconds: 2)),
            )
            .outcome,
        WeightCaptureOutcome.outOfRange,
      );
    });

    test('detecta una ráfaga continua y bloquea nuevas capturas', () {
      final controller = WeightCaptureController();

      expect(
        controller.onReading(reading(0.180), receivedAt: start).outcome,
        WeightCaptureOutcome.capture,
      );
      expect(
        controller
            .onReading(
              reading(0.180),
              receivedAt: start.add(const Duration(milliseconds: 400)),
            )
            .outcome,
        WeightCaptureOutcome.none,
      );
      expect(
        controller
            .onReading(
              reading(0.180),
              receivedAt: start.add(const Duration(milliseconds: 800)),
            )
            .outcome,
        WeightCaptureOutcome.none,
      );
      expect(
        controller
            .onReading(
              reading(0.180),
              receivedAt: start.add(const Duration(milliseconds: 1200)),
            )
            .outcome,
        WeightCaptureOutcome.continuousInputDetected,
      );
      expect(
        controller
            .onReading(
              reading(0.180),
              receivedAt: start.add(const Duration(milliseconds: 1600)),
            )
            .outcome,
        WeightCaptureOutcome.none,
      );
    });

    test('se recupera después de que cesa la trama continua', () {
      final controller = WeightCaptureController();
      for (var index = 0; index < 4; index++) {
        controller.onReading(
          reading(0.180),
          receivedAt: start.add(Duration(milliseconds: index * 400)),
        );
      }

      expect(
        controller
            .onReading(
              reading(0.200),
              receivedAt: start.add(const Duration(seconds: 4)),
            )
            .outcome,
        WeightCaptureOutcome.capture,
      );
    });
  });

  group('modo F12', () {
    test('requiere cero, captura una vez y vuelve a bloquearse', () {
      final controller = WeightCaptureController(
        configuration: const WeightCaptureConfiguration(
          mode: WeightCaptureMode.keyboardF12,
          range: WeightCaptureRange.restricted(
            minimum: 0.150,
            maximum: 0.250,
            unit: WeightUnit.kilogram,
          ),
        ),
      );

      controller.onReading(reading(0.180), receivedAt: start);
      expect(
        controller.onF12Pressed().outcome,
        WeightCaptureOutcome.waitingForZero,
      );

      controller.onReading(
        reading(0),
        receivedAt: start.add(const Duration(milliseconds: 1)),
      );
      expect(
        controller.onF12Pressed().outcome,
        WeightCaptureOutcome.zeroRejected,
      );

      controller.onReading(
        reading(0.120),
        receivedAt: start.add(const Duration(milliseconds: 2)),
      );
      expect(
        controller.onF12Pressed().outcome,
        WeightCaptureOutcome.outOfRange,
      );
      expect(controller.waitingForZero, isFalse);

      controller.onReading(
        reading(0.180),
        receivedAt: start.add(const Duration(milliseconds: 3)),
      );
      expect(controller.onF12Pressed().outcome, WeightCaptureOutcome.capture);
      expect(controller.waitingForZero, isTrue);
      expect(
        controller.onF12Pressed().outcome,
        WeightCaptureOutcome.waitingForZero,
      );
    });

    test('informa cuando todavía no existe una lectura', () {
      final controller = WeightCaptureController(
        configuration: const WeightCaptureConfiguration(
          mode: WeightCaptureMode.keyboardF12,
        ),
      );

      expect(controller.onF12Pressed().outcome, WeightCaptureOutcome.noReading);
    });
  });

  group('modo automático', () {
    test('captura al completar estabilidad y solo se rearma con cero', () {
      final controller = WeightCaptureController(
        configuration: const WeightCaptureConfiguration(
          mode: WeightCaptureMode.automaticStable,
          stableDuration: Duration(seconds: 1),
        ),
      );

      controller.onReading(reading(0), receivedAt: start);
      expect(
        controller
            .onReading(
              reading(0.180),
              receivedAt: start.add(const Duration(milliseconds: 1)),
            )
            .outcome,
        WeightCaptureOutcome.none,
      );
      expect(
        controller
            .onReading(
              reading(0.180),
              receivedAt: start.add(const Duration(milliseconds: 1000)),
            )
            .outcome,
        WeightCaptureOutcome.none,
      );
      expect(
        controller
            .onReading(
              reading(0.180),
              receivedAt: start.add(const Duration(milliseconds: 1001)),
            )
            .outcome,
        WeightCaptureOutcome.capture,
      );
      expect(controller.waitingForZero, isTrue);
      expect(
        controller
            .onReading(
              reading(0.180),
              receivedAt: start.add(const Duration(seconds: 3)),
            )
            .outcome,
        WeightCaptureOutcome.none,
      );

      controller.onReading(
        reading(0),
        receivedAt: start.add(const Duration(seconds: 4)),
      );
      expect(controller.waitingForZero, isFalse);
    });

    test('reinicia el tiempo solo cuando cambia el peso normalizado', () {
      final controller = WeightCaptureController(
        configuration: const WeightCaptureConfiguration(
          mode: WeightCaptureMode.automaticStable,
          stableDuration: Duration(seconds: 1),
        ),
      );
      controller.onReading(reading(0), receivedAt: start);

      controller.onReading(
        reading(0.181, text: '0.18'),
        receivedAt: start.add(const Duration(milliseconds: 1)),
      );
      final decision = controller.onReading(
        reading(0.182, text: '0.18'),
        receivedAt: start.add(const Duration(milliseconds: 1001)),
      );

      expect(decision.outcome, WeightCaptureOutcome.capture);
    });

    test('avisa una vez por peso estable fuera de rango', () {
      final controller = WeightCaptureController(
        configuration: const WeightCaptureConfiguration(
          mode: WeightCaptureMode.automaticStable,
          stableDuration: Duration(milliseconds: 500),
          range: WeightCaptureRange.restricted(
            minimum: 0.150,
            maximum: 0.250,
            unit: WeightUnit.kilogram,
          ),
        ),
      );
      controller.onReading(reading(0), receivedAt: start);

      controller.onReading(
        reading(0.120),
        receivedAt: start.add(const Duration(milliseconds: 1)),
      );
      expect(
        controller
            .onReading(
              reading(0.120),
              receivedAt: start.add(const Duration(milliseconds: 501)),
            )
            .outcome,
        WeightCaptureOutcome.outOfRange,
      );
      expect(
        controller
            .onReading(
              reading(0.120),
              receivedAt: start.add(const Duration(seconds: 2)),
            )
            .outcome,
        WeightCaptureOutcome.none,
      );

      controller.onReading(
        reading(0.180),
        receivedAt: start.add(const Duration(milliseconds: 2001)),
      );
      controller.onReading(
        reading(0.120),
        receivedAt: start.add(const Duration(milliseconds: 2002)),
      );
      expect(
        controller
            .onReading(
              reading(0.120),
              receivedAt: start.add(const Duration(milliseconds: 2502)),
            )
            .outcome,
        WeightCaptureOutcome.outOfRange,
      );
    });

    test('reporta una configuración inválida una sola vez por ciclo', () {
      final controller = WeightCaptureController(
        configuration: const WeightCaptureConfiguration(
          mode: WeightCaptureMode.automaticStable,
          stableDuration: Duration.zero,
        ),
      );
      controller.onReading(reading(0), receivedAt: start);

      expect(
        controller
            .onReading(
              reading(0.180),
              receivedAt: start.add(const Duration(milliseconds: 1)),
            )
            .outcome,
        WeightCaptureOutcome.invalidConfiguration,
      );
      expect(
        controller
            .onReading(
              reading(0.180),
              receivedAt: start.add(const Duration(milliseconds: 2)),
            )
            .outcome,
        WeightCaptureOutcome.none,
      );
    });
  });

  test('cambiar configuración reinicia y exige un nuevo cero', () {
    final controller = WeightCaptureController();
    controller.onReading(reading(0.180), receivedAt: start);

    controller.updateConfiguration(
      const WeightCaptureConfiguration(mode: WeightCaptureMode.keyboardF12),
    );

    expect(controller.latestReading, isNull);
    expect(controller.waitingForZero, isTrue);
    expect(controller.onF12Pressed().outcome, WeightCaptureOutcome.noReading);
  });

  test('descarta una lectura inválida antes de F12', () {
    final controller = WeightCaptureController(
      configuration: const WeightCaptureConfiguration(
        mode: WeightCaptureMode.keyboardF12,
      ),
    );
    controller.onReading(reading(0), receivedAt: start);
    controller.onReading(
      reading(0.180),
      receivedAt: start.add(const Duration(milliseconds: 1)),
    );

    controller.clearReading();

    expect(controller.latestReading, isNull);
    expect(controller.onF12Pressed().outcome, WeightCaptureOutcome.noReading);
  });
}
