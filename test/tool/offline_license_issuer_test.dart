import 'dart:convert';

import 'package:cryptography/cryptography.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pondera/features/license/domain/license_activation_request.dart';
import 'package:pondera/features/license/domain/license_serialization.dart';

import '../../tool/src/license_signing_key.dart';
import '../../tool/src/license_registration_document.dart';
import '../../tool/src/offline_license_issuer.dart';

const _seedHex =
    '9d61b19deffd5a60ba844af492ec2cc44449c5697b326919703bac031cae7f60';

void main() {
  test('emite una licencia verificable a partir de una solicitud', () async {
    final signingKey = LicenseSigningKey.decode(
      jsonEncode({
        'schema_version': 1,
        'algorithm': 'Ed25519',
        'key_id': 'test-key',
        'private_seed': base64Url.encode(
          LicenseSerialization.decodeHex(_seedHex),
        ),
      }),
    );
    final license = await OfflineLicenseIssuer().issue(
      request: _request(),
      signingKey: signingKey,
      licenseId: 'LIC-11111111-1111-4111-8111-111111111111',
      customerId: 'CUS-22222222-2222-4222-8222-222222222222',
      siteId: 'SITE-33333333-3333-4333-8333-333333333333',
      expiresAt: DateTime.utc(2026, 7, 31, 23, 59, 59),
      graceDays: 15,
      issuedAt: DateTime.utc(2026, 6, 18, 12),
    );

    final payload = license.decodePayload();
    expect(license.keyId, 'test-key');
    expect(
      payload.installationId,
      'INSTALL-FFFFFFFF-FFFF-4FFF-8FFF-FFFFFFFFFFFF',
    );
    expect(payload.customerName, 'SIGMA ALIMENTOS');
    expect(payload.expiresAt, DateTime.utc(2026, 7, 31, 23, 59, 59));
    expect(payload.graceUntil, DateTime.utc(2026, 8, 15, 23, 59, 59));

    final algorithm = Ed25519();
    final keyPair = await algorithm.newKeyPairFromSeed(signingKey.seedBytes);
    final publicKey = await keyPair.extractPublicKey();
    expect(
      await algorithm.verify(
        license.payloadBytes,
        signature: Signature(license.signatureBytes, publicKey: publicKey),
      ),
      isTrue,
    );
  });

  test('rechaza una clave privada con longitud incorrecta', () {
    final encoded = jsonEncode({
      'schema_version': 1,
      'algorithm': 'Ed25519',
      'key_id': 'test-key',
      'private_seed': base64Url.encode(List<int>.filled(16, 0)),
    });

    expect(() => LicenseSigningKey.decode(encoded), throwsFormatException);
  });

  test('crea el registro exacto para el backend', () async {
    final signingKey = LicenseSigningKey(
      keyId: 'test-key',
      seedBytes: LicenseSerialization.decodeHex(_seedHex),
    );
    final license = await OfflineLicenseIssuer().issue(
      request: _request(),
      signingKey: signingKey,
      licenseId: 'LIC-44444444-4444-4444-8444-444444444444',
      customerId: 'CUS-22222222-2222-4222-8222-222222222222',
      siteId: 'SITE-33333333-3333-4333-8333-333333333333',
      expiresAt: DateTime.utc(2026, 7, 31, 23, 59, 59),
      graceDays: 15,
      issuedAt: DateTime.utc(2026, 6, 18, 12),
    );

    final registration = await buildLicenseRegistrationDocument(
      license,
      replacesLicenseId: 'LIC-AAAAAAAA-AAAA-4AAA-8AAA-AAAAAAAAAAAA',
    );

    expect(registration['schema_version'], 1);
    expect(registration['license_file'], license.encode());
    expect(
      registration['license_file_sha256'],
      'sha256:e2c4d99b430c89ebb76eb9a762fad77bfa99fc078bba60a63b71868bd269cc0a',
    );
    expect(
      registration['replaces_license_id'],
      'LIC-AAAAAAAA-AAAA-4AAA-8AAA-AAAAAAAAAAAA',
    );
  });

  test('rechaza vencimiento anterior a la emisión', () async {
    final signingKey = LicenseSigningKey(
      keyId: 'test-key',
      seedBytes: LicenseSerialization.decodeHex(_seedHex),
    );

    expect(
      () => OfflineLicenseIssuer().issue(
        request: _request(),
        signingKey: signingKey,
        licenseId: 'LIC-11111111-1111-4111-8111-111111111111',
        customerId: 'CUS-22222222-2222-4222-8222-222222222222',
        siteId: 'SITE-33333333-3333-4333-8333-333333333333',
        expiresAt: DateTime.utc(2026, 6, 17),
        graceDays: 15,
        issuedAt: DateTime.utc(2026, 6, 18),
      ),
      throwsArgumentError,
    );
  });

  test('rechaza identificadores que el backend no puede registrar', () async {
    final signingKey = LicenseSigningKey(
      keyId: 'test-key',
      seedBytes: LicenseSerialization.decodeHex(_seedHex),
    );

    expect(
      () => OfflineLicenseIssuer().issue(
        request: _request(),
        signingKey: signingKey,
        licenseId: 'LIC-2026-0001',
        customerId: 'CUS-22222222-2222-4222-8222-222222222222',
        siteId: 'SITE-33333333-3333-4333-8333-333333333333',
        expiresAt: DateTime.utc(2026, 7, 31),
        graceDays: 15,
        issuedAt: DateTime.utc(2026, 6, 18),
      ),
      throwsArgumentError,
    );
  });
}

LicenseActivationRequest _request() {
  return LicenseActivationRequest(
    requestId: 'REQ-EEEEEEEE-EEEE-4EEE-8EEE-EEEEEEEEEEEE',
    installationId: 'INSTALL-FFFFFFFF-FFFF-4FFF-8FFF-FFFFFFFFFFFF',
    product: 'pondera',
    platform: 'macos',
    appVersion: '0.1.0',
    deviceFingerprintHash: 'sha256:${'a' * 64}',
    customerName: 'SIGMA ALIMENTOS',
    siteName: 'Planta de embutidos',
    city: 'Cuenca',
    deviceLabel: 'PC-Producción-01',
    createdAt: DateTime.utc(2026, 6, 18),
  );
}
