class ReadingParseResult {
  const ReadingParseResult({
    required this.formattedWeight,
    required this.numericValue,
    required this.decimalPlaces,
  });

  final String formattedWeight;
  final double? numericValue;
  final int decimalPlaces;
}

class ReadingParser {
  const ReadingParser._();

  static bool isValidExpectedValue(String value) {
    return RegExp(r'^\d+(?:[.,]\d+)?$').hasMatch(value.trim());
  }

  static ReadingParseResult? parse(
    String rawData, {
    required String pattern,
    required String expectedValue,
  }) {
    final match = RegExp(pattern).firstMatch(rawData);
    if (match == null) {
      return null;
    }

    final capturedWeight = match.groupCount > 0
        ? match.group(1) ?? match.group(0)
        : match.group(0);
    final formattedWeight = formatWeight(
      capturedWeight,
      expectedValue: expectedValue,
    );
    final numericText = formattedWeight
        .replaceAll(RegExp(r'[^0-9.,]'), '')
        .replaceAll(',', '.');

    return ReadingParseResult(
      formattedWeight: formattedWeight,
      numericValue: double.tryParse(numericText),
      decimalPlaces: numericText.contains('.')
          ? numericText.split('.')[1].length
          : 2,
    );
  }

  static String formatWeight(
    String? rawWeight, {
    required String expectedValue,
  }) {
    final value = rawWeight?.trim() ?? '';
    if (value.isEmpty || value == '---') {
      return '---';
    }

    final expectedDecimalSeparator = _decimalSeparatorFor(expectedValue);
    if (expectedDecimalSeparator == null) {
      return value;
    }

    final sourceDecimalSeparator = _decimalSeparatorFor(value);
    if (sourceDecimalSeparator == null) {
      return value;
    }

    final thousandsSeparator = sourceDecimalSeparator == '.' ? ',' : '.';
    return value
        .replaceAll(thousandsSeparator, '')
        .replaceAll(sourceDecimalSeparator, expectedDecimalSeparator);
  }

  static String? _decimalSeparatorFor(String value) {
    final dotIndex = value.lastIndexOf('.');
    final commaIndex = value.lastIndexOf(',');
    if (dotIndex == -1 && commaIndex == -1) {
      return null;
    }
    return dotIndex > commaIndex ? '.' : ',';
  }
}
