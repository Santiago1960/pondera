import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:pondera/features/license/domain/license_identifier_generator.dart';
import 'package:pondera/features/recipe/domain/recipe_access_request.dart';

void main() {
  test('serializa recipe_access v1 con valores UTC y licencia real', () {
    final generator = LicenseIdentifierGenerator(random: Random(7));
    final request = RecipeAccessRequest(
      requestId: generator.createRecipeAccessRequestId(),
      installationId: generator.createInstallationId(),
      deviceFingerprintHash: 'sha256:${'a' * 64}',
      platform: 'macos',
      appVersion: '1.0.0+10',
      rawData: '\u00020001 000000 B 0,16T 0,00N 0,16\r\n',
      expectedValue: '0,16',
      createdAt: DateTime(2026, 8, 11, 12),
      deviceLabel: 'Balanza recepción',
      licenseId: 'SNCA-2026-0001',
      licenseFileSha256: 'sha256:${'b' * 64}',
      customerId: 'CLI-001',
      customerName: 'Cliente Uno',
      siteId: 'SEDE-001',
      siteName: 'Planta Norte',
      city: 'Quito',
      assetTag: 'ACT-001',
      currentRecipePattern: r'N\s+([0-9]+[,.][0-9]+)',
    );

    final json = request.toJson();

    expect(json.keys.toSet(), {
      'schema_version',
      'request_id',
      'product',
      'platform',
      'app_version',
      'created_at',
      'installation_id',
      'device_fingerprint_hash',
      'device_label',
      'license_id',
      'license_file_sha256',
      'customer_id',
      'customer_name',
      'site_id',
      'site_name',
      'city',
      'asset_tag',
      'current_recipe_pattern',
      'trama',
      'valor_esperado',
    });
    expect(
      json['request_id'],
      matches(
        RegExp(
          r'^RAC-[0-9A-F]{8}-[0-9A-F]{4}-4[0-9A-F]{3}-[89AB][0-9A-F]{3}-[0-9A-F]{12}$',
        ),
      ),
    );
    expect(json['schema_version'], 1);
    expect(json['product'], 'pondera');
    expect(
      json['created_at'],
      DateTime(2026, 8, 11, 12).toUtc().toIso8601String(),
    );
    expect(json['license_id'], request.licenseId);
    expect(json['license_file_sha256'], request.licenseFileSha256);
    expect(json['device_label'], 'Balanza recepción');
    expect(json['customer_id'], 'CLI-001');
    expect(json['site_id'], 'SEDE-001');
    expect(json['city'], 'Quito');
    expect(json['asset_tag'], 'ACT-001');
    expect(json['current_recipe_pattern'], request.currentRecipePattern);
  });

  test('mantiene todos los campos con null durante la prueba', () {
    final generator = LicenseIdentifierGenerator(random: Random(8));
    final json = RecipeAccessRequest(
      requestId: generator.createRecipeAccessRequestId(),
      installationId: generator.createInstallationId(),
      deviceFingerprintHash: 'sha256:${'c' * 64}',
      platform: 'windows',
      appVersion: '1.0.0',
      rawData: 'PESO 0.16',
      expectedValue: '0.16',
      createdAt: DateTime.utc(2026, 8, 11),
    ).toJson();

    expect(json['license_id'], isNull);
    expect(json['license_file_sha256'], isNull);
    expect(json['customer_id'], isNull);
    expect(json['site_id'], isNull);
    expect(json['current_recipe_pattern'], isNull);
  });

  test('rechaza una licencia incompleta', () {
    final generator = LicenseIdentifierGenerator(random: Random(9));
    final request = RecipeAccessRequest(
      requestId: generator.createRecipeAccessRequestId(),
      installationId: generator.createInstallationId(),
      deviceFingerprintHash: 'sha256:${'d' * 64}',
      platform: 'macos',
      appVersion: '1.0.0',
      rawData: 'PESO 0.16',
      expectedValue: '0.16',
      createdAt: DateTime.utc(2026, 8, 11),
      licenseId: 'SNCA-2026-0001',
    );

    expect(request.toJson, throwsFormatException);
  });
}
