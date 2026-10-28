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

    test('acepta negativos con signo inicial y cero', () {
      for (final value in ['-130', '-0.130', ' -0,130 ', '0', '0.000']) {
        expect(ReadingParser.isValidExpectedValue(value), isTrue);
      }
    });

    test('rechaza signos incompletos, repetidos o dentro del número', () {
      for (final value in ['-', '--0.130', '0-130', '0.130-', '-0,1.30']) {
        expect(ReadingParser.isValidExpectedValue(value), isFalse);
      }
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
      expect(ReadingParser.formatWeight('0.28', expectedValue: '0,28'), '0,28');
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
    test(
      'conserva el texto del indicador antes de cambiar el separador de la receta',
      () {
        for (final source in ['+001.238', '-001,238', '0.000', '125']) {
          final result = ReadingParser.parse(
            '${source}kg',
            pattern: r'^([+-]?\d+(?:[.,]\d+)?)kg$',
            expectedValue: '0,100',
          )!;
          expect(result.sourceWeight, source);
          expect(
            result.numericValue,
            double.parse(source.replaceAll(',', '.')),
          );
        }
      },
    );

    test('GI-410 cambia de negativo a positivo con relleno en el signo', () {
      const pattern =
          r'^\x02[+-]?[0-9]+[ \t]+[+-]?[0-9]+[ \t]+(?<sign>[+-]?)[ \t]*B[ \t]+(?<weight>[0-9]+,[0-9]{2})T[ \t]+[+-]?[0-9]+,[0-9]{2}N[ \t]+[+-]?[0-9]+,[0-9]{2}$';
      for (final sample in [
        ('\x020001 000000  -B  0,20T  0,00N  0,20', -0.20),
        ('\x020001 000000   B  0,38T  0,00N  0,38', 0.38),
        ('\x020001 000000   B  0,00T  0,00N  0,00', 0.0),
        ('\x020001 000000  +B  12345,67T  0,00N  12345,67', 12345.67),
      ]) {
        final reading = ReadingParser.parse(
          sample.$1,
          pattern: pattern,
          expectedValue: '-0.20',
        );
        expect(reading, isNotNull);
        expect(reading!.numericValue, sample.$2);
        expect(reading.decimalPlaces, 2);
      }
    });

    test('interpreta la receta devuelta por n8n en la ejecución 1575', () {
      const pattern =
          r'^\x02[0-9]{4} [0-9]{6}[ \t]*(?<sign>[+-]?)B[ \t]*(?<weight>[0-9]+,[0-9]{2})T[ \t]*[0-9]+,[0-9]{2}N[ \t]*[0-9]+,[0-9]{2}[ \t]*\x03\r\n$';
      for (final sample in [
        ('-B 0,20', -0.20),
        ('B 0,00', 0.0),
        ('+B 1,25', 1.25),
        ('B 1,25', 1.25),
      ]) {
        final reading = ReadingParser.parse(
          '\x020001 000000 ${sample.$1}T 0,00N 0,20 \x03\r\n',
          pattern: pattern,
          expectedValue: '-0.20',
        );
        expect(reading, isNotNull);
        expect(reading!.numericValue, sample.$2);
      }
    });

    test('combina signo separado sin depender del formato del indicador', () {
      for (final sample in [
        (r'(?<sign>[+-]?)B\s+(?<weight>\d+,\d{2})T', '-B 0,20T'),
        (r'W=(?<weight>\d+,\d{2});S=(?<sign>[+-]?)$', 'W=0,20;S=-'),
      ]) {
        final reading = ReadingParser.parse(
          sample.$2,
          pattern: sample.$1,
          expectedValue: '-0.20',
        );
        expect(reading!.numericValue, -0.20);
        expect(reading.formattedWeight, '-0.20');
        final positive = ReadingParser.parse(
          sample.$2.replaceAll('-', '+'),
          pattern: sample.$1,
          expectedValue: '-0.20',
        );
        expect(positive!.numericValue, 0.20);
      }
    });

    test('conserva el signo al leer negativos, positivos y cero', () {
      for (final separator in ['.', ',']) {
        for (final sign in ['-', '+', '']) {
          final result = ReadingParser.parse(
            'WT ${sign}0${separator}130 kg',
            pattern: r'WT\s+([+-]?\d+[.,]\d+)\s+kg',
            expectedValue: '-0,130',
          );
          expect(result, isNotNull);
          expect(result!.formattedWeight, '${sign}0,130');
          expect(result.numericValue, sign == '-' ? -0.130 : 0.130);
          expect(result.decimalPlaces, 3);
        }
      }
      final zero = ReadingParser.parse(
        'WT 0.000 kg',
        pattern: r'WT\s+([+-]?\d+[.,]\d+)\s+kg',
        expectedValue: '-0.130',
      );
      expect(zero!.numericValue, 0);
    });

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

    test('usa el primer grupo capturado como peso', () {
      final result = ReadingParser.parse(
        '0001 000000 B 0,16T 0,00N 0,16\r\n',
        pattern:
            r'B\s+[0-9]+[\,\.][0-9]+T\s+[0-9]+[\,\.][0-9]+N\s+([0-9]+[\,\.][0-9]+)',
        expectedValue: '0.16',
      );

      expect(result, isNotNull);
      expect(result!.formattedWeight, '0.16');
      expect(result.numericValue, 0.16);
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

    test('no intenta extraer otro número si la receta no coincide', () {
      final result = ReadingParser.parse(
        r'N 0,370T 0,000C0\r\n',
        pattern: r'B\s+([0-9]+[,.][0-9]+)T',
        expectedValue: '0,370',
      );

      expect(result, isNull);
    });

    test('extrae únicamente el grupo definido por la receta', () {
      final result = ReadingParser.parse(
        r'N 0,370T 0,000C0\r\n',
        pattern: r'N\s+([0-9]+[,.][0-9]+)T',
        expectedValue: '0,370',
      );

      expect(result, isNotNull);
      expect(result!.formattedWeight, '0,370');
      expect(result.numericValue, 0.370);
    });
  });
}
