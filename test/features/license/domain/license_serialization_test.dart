import 'package:flutter_test/flutter_test.dart';
import 'package:pondera/features/license/domain/license_serialization.dart';

void main() {
  test('normaliza textos obligatorios y opcionales', () {
    final json = <String, dynamic>{'required': ' value ', 'optional': ' '};

    expect(LicenseSerialization.requiredString(json, 'required'), 'value');
    expect(LicenseSerialization.optionalString(json, 'optional'), isNull);
  });

  test('convierte fechas ISO 8601 a UTC', () {
    final json = <String, dynamic>{'created_at': '2026-08-03T10:00:00-05:00'};

    expect(
      LicenseSerialization.requiredUtcDateTime(json, 'created_at'),
      DateTime.utc(2026, 8, 3, 15),
    );
    expect(
      LicenseSerialization.optionalUtcDateTime(json, 'expires_at'),
      isNull,
    );
  });

  test('reutiliza conversiones Base64 URL y hexadecimal', () {
    final bytes = <int>[0, 1, 2, 253, 254, 255];

    final encoded = LicenseSerialization.encodeBase64Url(bytes);

    expect(encoded, isNot(contains('=')));
    expect(LicenseSerialization.decodeBase64Url(encoded), bytes);
    expect(LicenseSerialization.decodeHex('000102fdfeff'), bytes);
  });
}
