import 'package:flutter_test/flutter_test.dart';
import 'package:pondera/features/recipe/domain/recipe_sample.dart';
import 'package:pondera/features/scale_reading/domain/reading_parser.dart';
import 'package:pondera/features/scale_reading/domain/weight_capture_controller.dart';
import 'package:pondera/features/scale_reading/domain/weight_converter.dart';
import 'package:pondera/features/scale_reading/domain/weight_output_format.dart';
import 'package:pondera/features/scale_reading/domain/weight_unit.dart';

String output(
  double value,
  WeightOutputFormat format, {
  int sourcePlaces = 3,
}) => format.format(
  value,
  sourceDecimalPlaces: sourcePlaces,
  sourceWeight: '0.508',
);

void main() {
  test('usa el separador del indicador mientras no se configure otro', () {
    const format = WeightOutputFormat();
    expect(output(0.508, format), '0.508');
    expect(
      format.format(0.508, sourceDecimalPlaces: 3, sourceWeight: '0,508'),
      '0,508',
    );
    expect(output(125, format, sourcePlaces: 2), '125.00');
  });

  test(
    'el formato automático sigue la lectura aunque la receta use otro separador',
    () {
      for (final source in ['+001.238', '-001,238']) {
        final reading = ReadingParser.parse(
          '${source}kg',
          pattern: r'^([+-]?\d+[.,]\d+)kg$',
          expectedValue: source.contains('.') ? '0,100' : '0.100',
        )!;
        final format = const WeightOutputFormat(decimalPlaces: 2);
        expect(
          format.formatReading(
            reading,
            inputUnit: WeightUnit.kilogram,
            outputUnit: WeightUnit.kilogram,
          ),
          source.contains('.') ? '1.24' : '-1,24',
        );
        expect(
          format.formatReading(
            reading,
            inputUnit: WeightUnit.kilogram,
            outputUnit: WeightUnit.gram,
          ),
          source.contains('.') ? '1238.00' : '-1238,00',
        );
      }
    },
  );

  test('selecciona separador, decimales y reducción independientemente', () {
    for (final separator in [
      WeightDecimalSeparator.dot,
      WeightDecimalSeparator.comma,
    ]) {
      for (final mode in WeightRoundingMode.values) {
        final format = WeightOutputFormat(
          separator: separator,
          decimalPlaces: 2,
          roundingMode: mode,
        );
        final expected = mode == WeightRoundingMode.round ? '0.51' : '0.50';
        expect(
          output(0.508, format),
          separator == WeightDecimalSeparator.comma
              ? expected.replaceAll('.', ',')
              : expected,
        );
        expect(
          output(0.5, format),
          separator == WeightDecimalSeparator.comma ? '0,50' : '0.50',
        );
      }
    }
  });

  test('redondea mitades alejándose de cero y recorta hacia cero', () {
    const round = WeightOutputFormat(decimalPlaces: 2);
    const truncate = WeightOutputFormat(
      decimalPlaces: 2,
      roundingMode: WeightRoundingMode.truncate,
    );
    for (final (value, rounded, truncated) in [
      (1.005, '1.01', '1.00'),
      (-1.005, '-1.01', '-1.00'),
      (0.29, '0.29', '0.29'),
      (9.999, '10.00', '9.99'),
      (-0.508, '-0.51', '-0.50'),
      (-0.004, '0.00', '0.00'),
      (-0.0, '0.00', '0.00'),
    ]) {
      expect(output(value, round), rounded);
      expect(output(value, truncate), truncated);
    }
  });

  test('admite enteros, seis decimales y notación científica', () {
    expect(output(0.508, const WeightOutputFormat(decimalPlaces: 0)), '1');
    expect(
      output(
        -0.508,
        const WeightOutputFormat(
          decimalPlaces: 0,
          roundingMode: WeightRoundingMode.truncate,
        ),
      ),
      '0',
    );
    expect(
      output(0.508, const WeightOutputFormat(decimalPlaces: 6)),
      '0.508000',
    );
    expect(
      output(5e-7, const WeightOutputFormat(decimalPlaces: 6)),
      '0.000001',
    );
    expect(
      output(
        5e-7,
        const WeightOutputFormat(
          decimalPlaces: 6,
          roundingMode: WeightRoundingMode.truncate,
        ),
      ),
      '0.000000',
    );
    expect(
      output(1e21, const WeightOutputFormat(decimalPlaces: 2)),
      '1000000000000000000000.00',
    );
    expect(
      output(double.nan, const WeightOutputFormat(decimalPlaces: 2)),
      '---',
    );
    expect(output(double.infinity, const WeightOutputFormat()), '---');
  });

  test('aplica el formato después de convertir las unidades', () {
    final converted = WeightConverter.convert(
      0.508,
      from: WeightUnit.kilogram,
      to: WeightUnit.gram,
    );
    expect(
      output(
        converted,
        const WeightOutputFormat(
          separator: WeightDecimalSeparator.comma,
          decimalPlaces: 2,
        ),
      ),
      '508,00',
    );
  });

  test(
    'mantiene la validación exacta, el rango y el retorno con el peso completo',
    () {
      const sample = RecipeSample('+000.508kg');
      const pattern = r'^([+-]?\d+\.\d{3})kg$';
      expect(sample.matchesPattern(pattern, expectedValue: '0,508'), isTrue);
      expect(sample.matchesPattern(pattern, expectedValue: '0,50'), isFalse);
      final reading = ReadingParser.parse(
        sample.rawData,
        pattern: pattern,
        expectedValue: '0,508',
      )!;
      expect(reading.numericValue, 0.508);
      expect(reading.decimalPlaces, 3);
      const format = WeightOutputFormat(
        separator: WeightDecimalSeparator.comma,
        decimalPlaces: 2,
        roundingMode: WeightRoundingMode.truncate,
      );
      final controller = WeightCaptureController(
        configuration: const WeightCaptureConfiguration(
          mode: WeightCaptureMode.indicatorPrint,
          range: WeightCaptureRange.restricted(
            minimum: 0.1,
            maximum: 0.505,
            unit: WeightUnit.kilogram,
          ),
        ),
      );
      final decision = controller.onReading(
        WeightCaptureReading(
          value: reading.numericValue!,
          unit: WeightUnit.kilogram,
          captureText: output(reading.numericValue!, format),
        ),
        receivedAt: DateTime(2026, 10, 28),
      );
      expect(decision.outcome, WeightCaptureOutcome.outOfRange);
      expect(decision.reading!.captureText, '0,50');
      final smallWeight = WeightCaptureController(
        configuration: const WeightCaptureConfiguration(
          mode: WeightCaptureMode.indicatorPrint,
        ),
      );
      final nonzero = smallWeight.onReading(
        WeightCaptureReading(
          value: 0.004,
          unit: WeightUnit.kilogram,
          captureText: output(0.004, format),
        ),
        receivedAt: DateTime(2026, 10, 28),
      );
      expect(nonzero.shouldCapture, isTrue);
      expect(nonzero.reading!.value, 0.004);
      expect(nonzero.reading!.captureText, '0,00');
      final tare = WeightCaptureController(
        configuration: const WeightCaptureConfiguration(returnWeight: -0.508),
      );
      final atRest = tare.onReading(
        WeightCaptureReading(
          value: -0.508,
          unit: WeightUnit.kilogram,
          captureText: output(-0.508, format),
        ),
        receivedAt: DateTime(2026, 10, 28),
      );
      expect(atRest.outcome, WeightCaptureOutcome.zeroRejected);
      expect(atRest.reading!.captureText, '-0,50');
    },
  );
}
