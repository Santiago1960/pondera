import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:pondera/features/license/domain/license_activation_request.dart';
import 'package:pondera/features/license/domain/license_payload.dart';
import 'package:pondera/features/license/domain/license_status_request.dart';
import 'package:pondera/features/license/domain/signed_license.dart';

void main() {
  test('serializa y recupera una solicitud de activación', () {
    final request = LicenseActivationRequest(
      requestId: 'REQ-7F3A',
      installationId: 'INSTALL-A7F3',
      product: 'pondera',
      platform: 'windows',
      appVersion: '1.0.0',
      deviceFingerprintHash: 'sha256:${'a' * 64}',
      customerName: 'SIGMA ALIMENTOS',
      siteName: 'Planta de embutidos',
      city: 'Cuenca',
      deviceLabel: 'PC-Producción-01',
      assetTag: 'SIG-PC-042',
      createdAt: DateTime.utc(2026, 6, 18, 12),
    );

    final decoded = LicenseActivationRequest.decode(request.encode());

    expect(decoded.requestId, request.requestId);
    expect(decoded.installationId, request.installationId);
    expect(decoded.deviceFingerprintHash, 'sha256:${'a' * 64}');
    expect(decoded.customerName, 'SIGMA ALIMENTOS');
    expect(decoded.siteName, 'Planta de embutidos');
    expect(decoded.city, 'Cuenca');
    expect(decoded.deviceLabel, 'PC-Producción-01');
    expect(decoded.assetTag, 'SIG-PC-042');
    expect(decoded.createdAt, DateTime.utc(2026, 6, 18, 12));
  });

  test('serializa una licencia temporal con sus datos operativos', () {
    final payload = _buildPayload();

    final decoded = LicensePayload.decode(payload.encode());

    expect(decoded.licenseId, 'LIC-2026-0081');
    expect(decoded.requestId, 'REQ-7F3A');
    expect(decoded.installationId, 'INSTALL-A7F3');
    expect(decoded.customerId, 'CLI-0042');
    expect(decoded.siteId, 'SITE-001');
    expect(decoded.licenseType, LicenseType.subscription);
    expect(decoded.expiresAt, DateTime.utc(2027, 6, 30, 23, 59, 59));
    expect(decoded.features, ['tcp', 'serial', 'n8n', 'keyboard_output']);
  });

  test('permite licencias perpetuas sin fecha de vencimiento', () {
    final payload = LicensePayload(
      licenseId: 'LIC-PERPETUAL-01',
      requestId: 'REQ-0001',
      product: 'pondera',
      installationId: 'INSTALL-0001',
      customerId: 'CLI-0001',
      customerName: 'Cliente',
      siteId: 'SITE-0001',
      siteName: 'Planta principal',
      city: 'Cuenca',
      deviceLabel: 'PC-01',
      licenseType: LicenseType.perpetual,
      issuedAt: DateTime.utc(2026, 6, 18),
      notBefore: DateTime.utc(2026, 6, 18),
      expiresAt: null,
      graceUntil: null,
      features: const ['tcp'],
    );

    expect(LicensePayload.decode(payload.encode()).expiresAt, isNull);
  });

  test('el sobre conserva exactamente los bytes firmados', () {
    final payload = _buildPayload();
    final payloadBytes = payload.encode();
    final signatureBytes = List<int>.generate(64, (index) => index);
    final license = SignedLicense.fromBytes(
      keyId: 'pondera-2026-01',
      payloadBytes: payloadBytes,
      signatureBytes: signatureBytes,
    );

    final decoded = SignedLicense.decode(license.encode());

    expect(decoded.keyId, 'pondera-2026-01');
    expect(decoded.payloadBytes, payloadBytes);
    expect(decoded.signatureBytes, signatureBytes);
    expect(decoded.decodePayload().licenseId, payload.licenseId);
  });

  test('rechaza solicitudes incompletas', () {
    final source = jsonEncode({'schema_version': 1, 'request_id': 'REQ-1'});

    expect(
      () => LicenseActivationRequest.decode(source),
      throwsFormatException,
    );
  });

  test('serializa una consulta oportunista sin datos de receta', () {
    final request = LicenseStatusRequest(
      requestId: 'RAC-1',
      installationId: 'INSTALL-1',
      deviceFingerprintHash: 'sha256:${'a' * 64}',
      platform: 'macos',
      appVersion: '1.0.0+10',
      createdAt: DateTime.utc(2026, 8, 26, 15),
      licenseId: 'LIC-1',
      licenseFileSha256: 'sha256:${'b' * 64}',
    );

    final json = jsonDecode(request.encode()) as Map<String, dynamic>;

    expect(json['product'], 'pondera');
    expect(json['license_id'], 'LIC-1');
    expect(json.containsKey('trama'), isFalse);
    expect(json.containsKey('valor_esperado'), isFalse);
  });
}

LicensePayload _buildPayload() {
  return LicensePayload(
    licenseId: 'LIC-2026-0081',
    requestId: 'REQ-7F3A',
    product: 'pondera',
    installationId: 'INSTALL-A7F3',
    customerId: 'CLI-0042',
    customerName: 'SIGMA ALIMENTOS',
    siteId: 'SITE-001',
    siteName: 'Planta de embutidos',
    city: 'Cuenca',
    deviceLabel: 'PC-Producción-01',
    assetTag: 'SIG-PC-042',
    licenseType: LicenseType.subscription,
    issuedAt: DateTime.utc(2026, 6, 18),
    notBefore: DateTime.utc(2026, 6, 18),
    expiresAt: DateTime.utc(2027, 6, 30, 23, 59, 59),
    graceUntil: DateTime.utc(2027, 7, 15, 23, 59, 59),
    features: const ['tcp', 'serial', 'n8n', 'keyboard_output'],
  );
}
