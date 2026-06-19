import 'package:flutter_test/flutter_test.dart';

import '../../tool/src/utc_instant_parser.dart';

void main() {
  test('acepta un instante ISO 8601 expresado explícitamente en UTC', () {
    expect(parseUtcInstant('2026-10-01T00:00:00Z'), DateTime.utc(2026, 10, 1));
  });

  test('rechaza fechas sin zona horaria explícita', () {
    expect(() => parseUtcInstant('2026-10-01T00:00:00'), throwsFormatException);
  });

  test('rechaza offsets locales aunque representen un instante válido', () {
    expect(
      () => parseUtcInstant('2026-09-30T19:00:00-05:00'),
      throwsFormatException,
    );
  });
}
