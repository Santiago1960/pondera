import 'package:flutter_test/flutter_test.dart';
import 'package:pondera/features/scale_reading/domain/reading_parser.dart';

void main() {
  group('ReadingParser.isValidExpectedValue', () {
    test('acepta enteros y decimales con punto o coma', () {
      expect(ReadingParser.isValidExpectedValue('130'), isTrue);
      expect(ReadingParser.isValidExpectedValue('0.130'), isTrue);
      expect(ReadingParser.isValidExpectedValue('0,130'), isTrue);
      expect(ReadingParser.isValidExpectedValue(' 0,130 '), isTrue);
    });

    test('rechaza valores vacíos o con separadores ambiguos', () {
      expect(ReadingParser.isValidExpectedValue(''), isFalse);
      expect(ReadingParser.isValidExpectedValue('0,1.30'), isFalse);
      expect(ReadingParser.isValidExpectedValue('peso 0.130'), isFalse);
    });
  });

  group('ReadingParser.formatWeight', () {
    test('normaliza punto decimal y elimina separadores de miles', () {
      expect(
        ReadingParser.formatWeight('1.234,56', expectedValue: '0.130'),
        '1234.56',
      );
      expect(
        ReadingParser.formatWeight('1,234.56', expectedValue: '0.130'),
        '1234.56',
      );
    });

    test('normaliza coma decimal cuando el valor esperado usa coma', () {
      expect(
        ReadingParser.formatWeight('1,234.56', expectedValue: '0,130'),
        '1234,56',
      );
    });

    test('conserva valores enteros', () {
      expect(ReadingParser.formatWeight('125', expectedValue: '0.130'), '125');
    });

    test('representa entradas vacías como lectura ausente', () {
      expect(ReadingParser.formatWeight(null, expectedValue: '0.130'), '---');
      expect(ReadingParser.formatWeight('  ', expectedValue: '0.130'), '---');
      expect(ReadingParser.formatWeight('---', expectedValue: '0.130'), '---');
    });
  });

  group('ReadingParser.parse', () {
    test('extrae y convierte una lectura usando la receta', () {
      final result = ReadingParser.parse(
        r'ST,+0012,50kg',
        pattern: r'\d+[.,]\d+',
        expectedValue: '0.130',
      );

      expect(result, isNotNull);
      expect(result!.formattedWeight, '0012.50');
      expect(result.numericValue, 12.5);
      expect(result.decimalPlaces, 2);
    });

    test('reconoce una lectura de cero', () {
      final result = ReadingParser.parse(
        'WT 0.000 kg',
        pattern: r'\d+[.,]\d+',
        expectedValue: '0.130',
      );

      expect(result, isNotNull);
      expect(result!.numericValue, 0);
      expect(result.decimalPlaces, 3);
    });

    test('usa dos decimales por defecto para lecturas enteras', () {
      final result = ReadingParser.parse(
        'WT 125 kg',
        pattern: r'\d+',
        expectedValue: '0.130',
      );

      expect(result, isNotNull);
      expect(result!.numericValue, 125);
      expect(result.decimalPlaces, 2);
    });

    test('retorna null cuando la receta no coincide', () {
      expect(
        ReadingParser.parse(
          'sin lectura',
          pattern: r'\d+[.,]\d+',
          expectedValue: '0.130',
        ),
        isNull,
      );
    });
  });
}
