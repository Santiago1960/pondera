import 'package:cryptography/cryptography.dart';
import 'package:pondera/features/license/domain/license_activation_request.dart';
import 'package:pondera/features/license/domain/license_payload.dart';
import 'package:pondera/features/license/domain/signed_license.dart';

import 'license_signing_key.dart';

class OfflineLicenseIssuer {
  OfflineLicenseIssuer({Ed25519? algorithm})
    : _algorithm = algorithm ?? Ed25519();

  final Ed25519 _algorithm;

  Future<SignedLicense> issue({
    required LicenseActivationRequest request,
    required LicenseSigningKey signingKey,
    required String licenseId,
    required String customerId,
    required String siteId,
    required DateTime expiresAt,
    required int graceDays,
    DateTime? issuedAt,
  }) async {
    final normalizedLicenseId = _requiredIdentifier(
      licenseId,
      'licenseId',
      'LIC',
    );
    final normalizedCustomerId = _requiredIdentifier(
      customerId,
      'customerId',
      'CUS',
    );
    final normalizedSiteId = _requiredIdentifier(siteId, 'siteId', 'SITE');
    _requiredIdentifier(request.requestId, 'requestId', 'REQ');
    _requiredIdentifier(request.installationId, 'installationId', 'INSTALL');
    if (graceDays < 0) {
      throw ArgumentError('Los días de gracia no pueden ser negativos.');
    }

    final issuanceTime = (issuedAt ?? DateTime.now()).toUtc();
    final expirationTime = expiresAt.toUtc();
    if (!expirationTime.isAfter(issuanceTime)) {
      throw ArgumentError(
        'La fecha de vencimiento debe ser posterior a la emisión.',
      );
    }

    final payload = LicensePayload(
      licenseId: normalizedLicenseId,
      requestId: request.requestId,
      product: request.product,
      installationId: request.installationId,
      customerId: normalizedCustomerId,
      customerName: request.customerName,
      siteId: normalizedSiteId,
      siteName: request.siteName,
      city: request.city,
      deviceLabel: request.deviceLabel,
      assetTag: request.assetTag,
      licenseType: LicenseType.subscription,
      issuedAt: issuanceTime,
      notBefore: issuanceTime.subtract(const Duration(minutes: 5)),
      expiresAt: expirationTime,
      graceUntil: expirationTime.add(Duration(days: graceDays)),
      features: const ['tcp', 'serial', 'n8n', 'keyboard_output'],
    );

    final keyPair = await _algorithm.newKeyPairFromSeed(signingKey.seedBytes);
    final payloadBytes = payload.encode();
    final signature = await _algorithm.sign(payloadBytes, keyPair: keyPair);
    return SignedLicense.fromBytes(
      keyId: signingKey.keyId,
      payloadBytes: payloadBytes,
      signatureBytes: signature.bytes,
    );
  }
}

String _requiredValue(String value, String fieldName) {
  final normalized = value.trim();
  if (normalized.isEmpty) {
    throw ArgumentError('El campo $fieldName es obligatorio.');
  }
  return normalized;
}

String _requiredIdentifier(String value, String fieldName, String prefix) {
  final normalized = _requiredValue(value, fieldName);
  if (!RegExp('^$prefix-$_uuidV4\$').hasMatch(normalized)) {
    throw ArgumentError(
      'El campo $fieldName no tiene un identificador válido.',
    );
  }
  return normalized;
}

const _uuidV4 =
    r'[0-9A-F]{8}-[0-9A-F]{4}-4[0-9A-F]{3}-[89AB][0-9A-F]{3}-[0-9A-F]{12}';
