import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:pondera/features/license/data/license_key_registry.dart';
import 'package:pondera/features/license/domain/license_key_ids.dart';

void main() {
  test('producción reconoce únicamente la clave pública de producción', () {
    final registry = LicenseKeyRegistry.forEnvironment(
      allowDevelopmentKeys: false,
    );

    expect(registry.find(LicenseKeyIds.bitgenialProduction2026_01), isNotNull);
    expect(registry.find(LicenseKeyIds.production2026_01), isNotNull);
    expect(registry.find(LicenseKeyIds.development), isNull);
  });

  test('incorpora la clave pública genérica de Bitgenial', () {
    final registry = LicenseKeyRegistry.forEnvironment(
      allowDevelopmentKeys: false,
    );
    final publicKey = registry.find(LicenseKeyIds.bitgenialProduction2026_01);

    expect(
      publicKey?.bytes,
      base64Url.decode('jklUe9EP7y_9YXiLVXH0hV-KfGeIba6R8iR7AHOLWC8='),
    );
  });

  test('la clave pública incorporada coincide con el archivo generado', () {
    final registry = LicenseKeyRegistry.forEnvironment(
      allowDevelopmentKeys: false,
    );
    final publicKey = registry.find(LicenseKeyIds.production2026_01);

    expect(
      publicKey?.bytes,
      base64Url.decode('WJLgFwl9soxXNqz_LognhbUPIeIl6PkJMrQ8BjuY3Xg='),
    );
  });

  test('desarrollo reconoce las claves de producción y de prueba', () {
    final registry = LicenseKeyRegistry.forEnvironment(
      allowDevelopmentKeys: true,
    );

    expect(registry.find(LicenseKeyIds.bitgenialProduction2026_01), isNotNull);
    expect(registry.find(LicenseKeyIds.production2026_01), isNotNull);
    expect(registry.find(LicenseKeyIds.development), isNotNull);
  });
}
