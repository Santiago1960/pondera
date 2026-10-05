/// Validates extraction and exercises numeric changes without assuming a protocol.
class RecipeValidator {
  const RecipeValidator._();

  static final _numbers = RegExp(r'[0-9]+(?:[.,][0-9]+)?');

  static String? validate({
    required String pattern,
    required String frame,
    required String expectedValue,
  }) {
    const invalid =
        'La receta no extrae únicamente el peso con su formato. '
        'La receta actual no fue modificada.';
    if (pattern.isEmpty || pattern.length > 512 || frame.length > 4096) {
      return invalid;
    }
    final expected = double.tryParse(expectedValue.replaceAll(',', '.'));
    final tokens = _numbers.allMatches(frame).toList();
    final candidates = tokens
        .where(
          (token) =>
              double.tryParse(token[0]!.replaceAll(',', '.')) == expected,
        )
        .toList();
    if (expected == null || candidates.isEmpty) return invalid;
    late final RegExp regex;
    try {
      regex = RegExp(pattern);
    } on FormatException {
      return invalid;
    }
    bool extracts(String sample, String weight) {
      final matches = regex.allMatches(sample).take(2).toList();
      return matches.length == 1 &&
          matches.single.groupCount == 1 &&
          matches.single.group(1) == weight;
    }

    final initialMatches = regex.allMatches(frame).take(2).toList();
    if (initialMatches.length != 1 || initialMatches.single.groupCount != 1) {
      return invalid;
    }
    final initialMatch = initialMatches.single;
    final capturedWeight = initialMatch.group(1);
    if (capturedWeight == null ||
        double.tryParse(capturedWeight.replaceAll(',', '.')) != expected) {
      return invalid;
    }
    final possibleTargets = candidates.where(
      (candidate) =>
          candidate[0] == capturedWeight &&
          candidate.start >= initialMatch.start &&
          candidate.end <= initialMatch.end,
    );

    bool validatesTarget(RegExpMatch target) {
      final targetIndex = tokens.indexOf(target);

      // Identify which repeated occurrence controls the capture while also
      // rejecting recipes that freeze other numeric fields as literals.
      for (var i = 0; i < tokens.length; i++) {
        final token = tokens[i];
        final changed = token[0]!.replaceAllMapped(
          RegExp(r'[0-9]'),
          (m) => ((int.parse(m[0]!) + 3) % 10).toString(),
        );
        final sample = frame.replaceRange(token.start, token.end, changed);
        if (!extracts(sample, i == targetIndex ? changed : target[0]!)) {
          return false;
        }
      }
      final decimal = RegExp(r'[.,]').firstMatch(target[0]!);
      final suffix = decimal == null ? '' : target[0]!.substring(decimal.start);
      for (final weight in ['0$suffix', '12345$suffix']) {
        if (!extracts(
          frame.replaceRange(target.start, target.end, weight),
          weight,
        )) {
          return false;
        }
      }
      if (decimal != null) {
        final weight = target[0]!;
        final otherSeparator = weight.replaceRange(
          decimal.start,
          decimal.end,
          weight[decimal.start] == ',' ? '.' : ',',
        );
        for (final wrongFormat in [
          otherSeparator,
          '${weight}7',
          weight.substring(0, weight.length - 1),
        ]) {
          if (regex.hasMatch(
            frame.replaceRange(target.start, target.end, wrongFormat),
          )) {
            return false;
          }
        }
      }
      return true;
    }

    if (possibleTargets.any(validatesTarget)) return null;
    return 'La receta depende de los valores de la muestra y falla cuando '
        'cambian. Solicite una nueva receta. La receta actual no fue modificada.';
  }
}
