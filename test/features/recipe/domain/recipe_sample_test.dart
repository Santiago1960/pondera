import 'package:flutter_test/flutter_test.dart';
import 'package:pondera/features/recipe/domain/recipe_sample.dart';

void main() {
  test('sugiere el único peso de la muestra BR-15 conservando decimales', () {
    expect(const RecipeSample('+000.562kg').suggestedExpectedValue, '0.562');
    expect(const RecipeSample('-000.562kg').suggestedExpectedValue, '-0.562');
    expect(
      const RecipeSample('+000,000kg\r\n').suggestedExpectedValue,
      '0,000',
    );
    expect(const RecipeSample('WT 00125 kg').suggestedExpectedValue, '125');
  });

  test('no sugiere un campo cuando la muestra contiene varios números', () {
    expect(
      const RecipeSample(
        '0001 000000 -B 0,20T 0,00N 0,20',
      ).suggestedExpectedValue,
      isNull,
    );
    expect(const RecipeSample('sin peso').suggestedExpectedValue, isNull);
  });

  test('muestra controles visibles sin modificar la trama enviada', () {
    const rawData = '\x02+000.562kg\x03\r\n';
    const sample = RecipeSample(rawData);
    expect(sample.visibleRawData, r'\x02+000.562kg\x03\r\n');
    expect(sample.rawData, rawData);
  });

  test('acepta el regex real de la IA para BR-15 y verifica el peso', () {
    const sample = RecipeSample('+000.563kg');
    const pattern = r'^(?<full_weight>[+-]?[0-9]+\.[0-9]{3})kg$';
    expect(sample.matchesPattern(pattern, expectedValue: '0.563'), isTrue);
    expect(sample.matchesPattern(pattern, expectedValue: '0,563'), isTrue);
    expect(sample.matchesPattern(pattern, expectedValue: '0.561'), isFalse);
  });

  test('mantiene el soporte del indicador anterior con signo separado', () {
    const sample = RecipeSample('\x020001 000000 -B 0,20T 0,00N 0,20 \x03\r\n');
    const pattern =
        r'^\x02[0-9]{4} [0-9]{6}[ \t]*(?<sign>[+-]?)B[ \t]*(?<weight>[0-9]+,[0-9]{2})T[ \t]*[0-9]+,[0-9]{2}N[ \t]*[0-9]+,[0-9]{2}[ \t]*\x03\r\n$';
    expect(sample.matchesPattern(pattern, expectedValue: '-0.20'), isTrue);
    expect(sample.matchesPattern(pattern, expectedValue: '0.20'), isFalse);
  });

  test('rechaza recetas incompatibles, ambiguas o sin captura numérica', () {
    const sample = RecipeSample('+000.562kg');
    for (final pattern in ['', '[', r'B (\d+,\d+)T', r'^(.+)$']) {
      expect(sample.matchesPattern(pattern, expectedValue: '0.562'), isFalse);
    }
    expect(
      const RecipeSample(
        'B 0.562T 0.562',
      ).matchesPattern(r'(\d+\.\d+)', expectedValue: '0.562'),
      isFalse,
    );
  });
}
