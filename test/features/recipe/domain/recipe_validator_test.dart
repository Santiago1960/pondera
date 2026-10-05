import 'package:flutter_test/flutter_test.dart';
import 'package:pondera/features/recipe/domain/recipe_validator.dart';

void main() {
  String? check(String pattern, String frame, String expected) =>
      RecipeValidator.validate(
        pattern: pattern,
        frame: frame,
        expectedValue: expected,
      );

  test('acepta formatos numéricos sin contexto y conserva separadores', () {
    expect(check(r'^([0-9]+,[0-9]{2})$', '0,16', '0.16'), isNull);
    expect(check(r'^([0-9]+\.[0-9]{3})$', '0.160', '0,160'), isNull);
    expect(check(r'^([0-9]+)$', '16', '16'), isNull);
  });
  test('acepta contexto estructural con números variables', () {
    expect(
      check(
        r'B\s+[0-9]+,[0-9]{2}T\s+[0-9]+,[0-9]{2}N\s+([0-9]+,[0-9]{2})$',
        '\x020001 000000 B 0,30T 0,00N 0,16',
        '0,16',
      ),
      isNull,
    );
  });
  test('rechaza valores fijos que congelan el contexto', () {
    expect(
      check(
        r'B\s+0,30T\s+0,00N\s+([0-9]+,[0-9]{2})',
        'B 0,30T 0,00N 0,16',
        '0,16',
      ),
      isNotNull,
    );
    expect(check(r'^(0,16)$', '0,16', '0,16'), isNotNull);
  });
  test('acepta cualquier aparición válida si el valor se repite', () {
    expect(
      check(r'B\s+([0-9]+,[0-9]{2})T', 'B 0,16T 0,00N 0,16', '0,16'),
      isNull,
    );
    expect(
      check(r'N\s+([0-9]+,[0-9]{2})$', 'B 0,16T 0,00N 0,16', '0,16'),
      isNull,
    );
  });
  test('rechaza captura parcial, campo equivocado y varios grupos', () {
    expect(check(r'^([0-9]+[,.][0-9]+)$', '0,16', '0,16'), isNotNull);
    expect(check(r'([0-9]+,[0-9]{1})', '0,16', '0,16'), isNotNull);
    expect(check(r'A ([0-9]+)', 'A 15 B 16', '16'), isNotNull);
    expect(check(r'([0-9]+)(,[0-9]{2})', '0,16', '0,16'), isNotNull);
    expect(check(r'[', '0,16', '0,16'), isNotNull);
    expect(check(r'[0-9]+,[0-9]{2}', '0,16', '0,16'), isNotNull);
  });
}
