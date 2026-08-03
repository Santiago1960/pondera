import 'dart:convert';

import 'package:cryptography/cryptography.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pondera/features/license/domain/license_activation_request.dart';
import 'package:pondera/features/license/domain/license_serialization.dart';

import '../../tool/src/license_signing_key.dart';
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
      licenseId: 'LIC-2026-0001',
      customerId: 'CLI-0001',
      siteId: 'SITE-0001',
      expiresAt: DateTime.utc(2026, 7, 31, 23, 59, 59),
      graceDays: 15,
      issuedAt: DateTime.utc(2026, 6, 18, 12),
    );

    final payload = license.decodePayload();
    expect(license.keyId, 'test-key');
    expect(payload.installationId, 'INSTALL-A7F3');
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

  test('rechaza vencimiento anterior a la emisión', () async {
    final signingKey = LicenseSigningKey(
      keyId: 'test-key',
      seedBytes: LicenseSerialization.decodeHex(_seedHex),
    );

    expect(
      () => OfflineLicenseIssuer().issue(
        request: _request(),
        signingKey: signingKey,
        licenseId: 'LIC-2026-0001',
        customerId: 'CLI-0001',
        siteId: 'SITE-0001',
        expiresAt: DateTime.utc(2026, 6, 17),
        graceDays: 15,
        issuedAt: DateTime.utc(2026, 6, 18),
      ),
      throwsArgumentError,
    );
  });
}

LicenseActivationRequest _request() {
  return LicenseActivationRequest(
    requestId: 'REQ-7F3A',
    installationId: 'INSTALL-A7F3',
    product: 'pondera',
    platform: 'macos',
    appVersion: '0.1.0',
    customerName: 'SIGMA ALIMENTOS',
    siteName: 'Planta de embutidos',
    city: 'Cuenca',
    deviceLabel: 'PC-Producción-01',
    createdAt: DateTime.utc(2026, 6, 18),
  );
}
