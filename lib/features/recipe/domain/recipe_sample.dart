import '../../scale_reading/domain/reading_parser.dart';

class RecipeSample {
  const RecipeSample(this.rawData);

  final String rawData;

  String? get suggestedExpectedValue {
    final numbers = RegExp(r'[+-]?\d+(?:[.,]\d+)?').allMatches(rawData);
    if (numbers.length != 1) {
      return null;
    }
    final number = numbers.single.group(0)!;
    if (number.length > 32 ||
        !(double.tryParse(number.replaceAll(',', '.'))?.isFinite ?? false)) {
      return null;
    }
    return number
        .replaceFirst(RegExp(r'^\+'), '')
        .replaceFirstMapped(RegExp(r'^(-?)0+(?=\d)'), (match) => match[1]!);
  }

  String get visibleRawData => rawData.replaceAllMapped(
    RegExp(r'[\x00-\x1f\x7f]'),
    (match) => switch (match[0]) {
      '\r' => r'\r',
      '\n' => r'\n',
      '\t' => r'\t',
      _ => '\\x${match[0]!.codeUnitAt(0).toRadixString(16).padLeft(2, '0')}',
    },
  );

  bool matchesPattern(String pattern, {required String expectedValue}) {
    if (pattern.isEmpty || !ReadingParser.isValidExpectedValue(expectedValue)) {
      return false;
    }
    try {
      if (RegExp(pattern).allMatches(rawData).length != 1) {
        return false;
      }
      final reading = ReadingParser.parse(
        rawData,
        pattern: pattern,
        expectedValue: expectedValue,
      );
      final expected = double.tryParse(
        expectedValue.trim().replaceAll(',', '.'),
      );
      return reading != null &&
          RegExp(r'^[+-]?\d+(?:[.,]\d+)?$').hasMatch(reading.formattedWeight) &&
          (reading.numericValue?.isFinite ?? false) &&
          (expected?.isFinite ?? false) &&
          reading.numericValue == expected;
    } on FormatException {
      return false;
    }
  }
}
