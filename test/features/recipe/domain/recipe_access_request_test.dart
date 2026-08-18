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
      licenseId: 'LIC-AAAAAAAA-BBBB-4CCC-8DDD-EEEEEEEEEEEE',
      licenseFileSha256: 'sha256:${'b' * 64}',
    );

    final json = request.toJson();

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
  });

  test('omite ambos campos de licencia durante la prueba', () {
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

    expect(json, isNot(contains('license_id')));
    expect(json, isNot(contains('license_file_sha256')));
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
      licenseId: 'LIC-AAAAAAAA-BBBB-4CCC-8DDD-EEEEEEEEEEEE',
    );

    expect(request.toJson, throwsFormatException);
  });
}
