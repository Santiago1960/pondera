import 'package:flutter_test/flutter_test.dart';
import 'package:pondera/features/scale_reading/domain/reading_parser.dart';
import 'package:pondera/features/scale_reading/domain/weight_capture_controller.dart';
import 'package:pondera/features/scale_reading/domain/weight_unit.dart';

void main() {
  final start = DateTime.utc(2026, 1, 1);

  void receive(
    WeightCaptureController controller,
    String rawData,
    String pattern,
    String expectedValue,
    int seconds,
  ) {
    final parsed = ReadingParser.parse(
      rawData,
      pattern: pattern,
      expectedValue: expectedValue,
    );
    expect(parsed, isNotNull);
    controller.onReading(
      WeightCaptureReading(
        value: parsed!.numericValue!,
        unit: WeightUnit.kilogram,
        captureText: parsed.formattedWeight,
      ),
      receivedAt: start.add(Duration(seconds: seconds)),
    );
  }

  test(
    'GI-410: muestra con tara, peso positivo, retorno negativo y nuevo peso',
    () {
      const expected = '-0.20';
      const pattern =
          r'(?<sign>[+-]?)[ \t]*B[ \t]*(?<![0-9.,])(?<weight>[0-9]+,[0-9]{2})(?![0-9.,])T';
      final controller = WeightCaptureController(
        configuration: WeightCaptureConfiguration(
          mode: WeightCaptureMode.keyboardF12,
          returnWeight:
              WeightCaptureConfiguration.returnWeightFromExpectedValue(
                expected,
              ),
        ),
      );
      receive(
        controller,
        '\x020001 000000  -B  0,20T  0,00N  0,20',
        pattern,
        expected,
        0,
      );
      receive(
        controller,
        '\x020001 000000   B  0,38T  0,00N  0,38',
        pattern,
        expected,
        1,
      );
      expect(controller.latestReading!.captureText, '0.38');
      expect(controller.onF12Pressed().outcome, WeightCaptureOutcome.capture);
      receive(
        controller,
        '\x020001 000000   B  0,00T  0,00N  0,00',
        pattern,
        expected,
        2,
      );
      expect(controller.waitingForZero, isTrue);
      receive(
        controller,
        '\x020001 000000   B  0,45T  0,00N  0,45',
        pattern,
        expected,
        3,
      );
      expect(
        controller.onF12Pressed().outcome,
        WeightCaptureOutcome.waitingForZero,
      );
      receive(
        controller,
        '\x020001 000000  -B  0,20T  0,00N  0,20',
        pattern,
        expected,
        4,
      );
      receive(
        controller,
        '\x020001 000000   B  0,45T  0,00N  0,45',
        pattern,
        expected,
        5,
      );
      final next = controller.onF12Pressed();
      expect(next.outcome, WeightCaptureOutcome.capture);
      expect(next.reading!.captureText, '0.45');
    },
  );

  test('recetas de n8n extraen peso sin exigir encabezado ni final de trama', () {
    const gi410Pattern =
        r'(?<sign>[+-]?)[ \t]*B[ \t]*(?<![0-9.,])(?<weight>[0-9]+,[0-9]{2})(?![0-9.,])T';
    for (final frame in [
      '\x020001 000000   B  0,38T  0,00N  0,38',
      '\x020001 000000   B  0,38T  0,00N  0,38 \x03\r\n',
      ' B  0,38T  0,00N  0,38',
    ]) {
      final parsed = ReadingParser.parse(
        frame,
        pattern: gi410Pattern,
        expectedValue: '-0.20',
      );
      expect(parsed?.numericValue, 0.38);
      expect(parsed?.formattedWeight, '0.38');
    }
    const br15Pattern = r'(?<![0-9.,])(?<weight>[0-9]+\.[0-9]{3})(?![0-9.,])kg';
    final br15 = ReadingParser.parse(
      '\x02+000.562kg\x03\r\n',
      pattern: br15Pattern,
      expectedValue: '0.562',
    );
    expect(br15?.numericValue, 0.562);
    expect(br15?.formattedWeight, '000.562');
    expect(
      ReadingParser.parse(
        '+000.5627kg',
        pattern: br15Pattern,
        expectedValue: '0.562',
      ),
      isNull,
    );
  });

  test('BR-15 sin tara: sigue requiriendo cero entre pesos positivos', () {
    const expected = '0.562';
    const pattern = r'^([+-]?[0-9]+\.[0-9]{3})kg$';
    final controller = WeightCaptureController(
      configuration: WeightCaptureConfiguration(
        mode: WeightCaptureMode.keyboardF12,
        returnWeight: WeightCaptureConfiguration.returnWeightFromExpectedValue(
          expected,
        ),
      ),
    );
    receive(controller, '+000.000kg', pattern, expected, 0);
    receive(controller, '+000.562kg', pattern, expected, 1);
    expect(controller.onF12Pressed().outcome, WeightCaptureOutcome.capture);
    receive(controller, '+000.600kg', pattern, expected, 2);
    expect(
      controller.onF12Pressed().outcome,
      WeightCaptureOutcome.waitingForZero,
    );
    receive(controller, '+000.000kg', pattern, expected, 3);
    receive(controller, '+000.600kg', pattern, expected, 4);
    expect(controller.onF12Pressed().outcome, WeightCaptureOutcome.capture);
  });
}
