import 'reading_parser.dart';
import 'weight_converter.dart';
import 'weight_unit.dart';

enum WeightDecimalSeparator { indicator, dot, comma }

enum WeightRoundingMode { round, truncate }

class WeightOutputFormat {
  const WeightOutputFormat({
    this.separator = WeightDecimalSeparator.indicator,
    this.decimalPlaces,
    this.roundingMode = WeightRoundingMode.round,
  }) : assert(
         decimalPlaces == null || (decimalPlaces >= 0 && decimalPlaces <= 6),
       );

  factory WeightOutputFormat.fromStoredValues({
    String? separator,
    int? decimalPlaces,
    String? roundingMode,
  }) {
    return WeightOutputFormat(
      separator:
          WeightDecimalSeparator.values
              .where((value) => value.name == separator)
              .firstOrNull ??
          WeightDecimalSeparator.indicator,
      decimalPlaces:
          decimalPlaces != null && decimalPlaces >= 0 && decimalPlaces <= 6
          ? decimalPlaces
          : null,
      roundingMode:
          WeightRoundingMode.values
              .where((value) => value.name == roundingMode)
              .firstOrNull ??
          WeightRoundingMode.round,
    );
  }

  final WeightDecimalSeparator separator;
  final int? decimalPlaces;
  final WeightRoundingMode roundingMode;

  String format(
    double value, {
    required int sourceDecimalPlaces,
    required String sourceWeight,
  }) {
    if (!value.isFinite) return '---';
    final places = decimalPlaces;
    final text = places == null
        ? value.toStringAsFixed(sourceDecimalPlaces)
        : _formatFixed(value, places);
    return switch (separator) {
      WeightDecimalSeparator.indicator => ReadingParser.formatWeight(
        text,
        expectedValue: sourceWeight,
      ),
      WeightDecimalSeparator.dot => text,
      WeightDecimalSeparator.comma => text.replaceAll('.', ','),
    };
  }

  String formatReading(
    ReadingParseResult reading, {
    required WeightUnit inputUnit,
    required WeightUnit outputUnit,
  }) {
    final value = reading.numericValue;
    if (value == null) return '---';
    return format(
      WeightConverter.convert(value, from: inputUnit, to: outputUnit),
      sourceDecimalPlaces: reading.decimalPlaces,
      sourceWeight: reading.sourceWeight,
    );
  }

  String _formatFixed(double value, int places) {
    // Work with decimal digits so values such as 1.005 and 0.29 do not lose
    // a digit when a binary floating-point multiplication is inexact.
    final parts = value.abs().toString().split('e');
    final coefficient = parts.first;
    final exponent = parts.length == 2 ? int.parse(parts.last) : 0;
    final fractionLength = coefficient.contains('.')
        ? coefficient.length - coefficient.indexOf('.') - 1
        : 0;
    final digits = BigInt.parse(coefficient.replaceAll('.', ''));
    final shift = places + exponent - fractionLength;
    BigInt scaled;
    if (shift >= 0) {
      scaled = digits * BigInt.from(10).pow(shift);
    } else {
      final divisor = BigInt.from(10).pow(-shift);
      scaled = digits ~/ divisor;
      if (roundingMode == WeightRoundingMode.round &&
          (digits % divisor) * BigInt.two >= divisor) {
        scaled += BigInt.one;
      }
    }
    final text = scaled.toString().padLeft(places + 1, '0');
    final unsigned = places == 0
        ? text
        : '${text.substring(0, text.length - places)}.${text.substring(text.length - places)}';
    return value.isNegative && scaled != BigInt.zero ? '-$unsigned' : unsigned;
  }
}
