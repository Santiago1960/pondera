import 'dart:convert';

import 'license_serialization.dart';

enum LicenseType { trial, subscription, perpetual }

class LicensePayload {
  const LicensePayload({
    required this.licenseId,
    required this.requestId,
    required this.product,
    required this.installationId,
    required this.customerId,
    required this.customerName,
    required this.siteId,
    required this.siteName,
    required this.city,
    required this.deviceLabel,
    required this.licenseType,
    required this.issuedAt,
    required this.notBefore,
    required this.features,
    this.assetTag,
    this.expiresAt,
    this.graceUntil,
  });

  static const schemaVersion = 1;

  final String licenseId;
  final String requestId;
  final String product;
  final String installationId;
  final String customerId;
  final String customerName;
  final String siteId;
  final String siteName;
  final String city;
  final String deviceLabel;
  final String? assetTag;
  final LicenseType licenseType;
  final DateTime issuedAt;
  final DateTime notBefore;
  final DateTime? expiresAt;
  final DateTime? graceUntil;
  final List<String> features;

  Map<String, Object?> toJson() {
    return {
      'schema_version': schemaVersion,
      'license_id': licenseId,
      'request_id': requestId,
      'product': product,
      'installation_id': installationId,
      'customer_id': customerId,
      'customer_name': customerName,
      'site_id': siteId,
      'site_name': siteName,
      'city': city,
      'device_label': deviceLabel,
      'asset_tag': assetTag,
      'license_type': licenseType.name,
      'issued_at': issuedAt.toUtc().toIso8601String(),
      'not_before': notBefore.toUtc().toIso8601String(),
      'expires_at': expiresAt?.toUtc().toIso8601String(),
      'grace_until': graceUntil?.toUtc().toIso8601String(),
      'features': features,
    };
  }

  List<int> encode() => utf8.encode(jsonEncode(toJson()));

  factory LicensePayload.decode(List<int> bytes) {
    final decoded = jsonDecode(utf8.decode(bytes));
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('El contenido de licencia no es válido.');
    }
    if (decoded['schema_version'] != schemaVersion) {
      throw const FormatException('Versión de licencia no soportada.');
    }

    final licenseTypeValue = LicenseSerialization.requiredString(
      decoded,
      'license_type',
    );
    final licenseType = LicenseType.values
        .where((value) => value.name == licenseTypeValue)
        .firstOrNull;
    if (licenseType == null) {
      throw FormatException(
        'Tipo de licencia no soportado: $licenseTypeValue.',
      );
    }

    return LicensePayload(
      licenseId: LicenseSerialization.requiredString(decoded, 'license_id'),
      requestId: LicenseSerialization.requiredString(decoded, 'request_id'),
      product: LicenseSerialization.requiredString(decoded, 'product'),
      installationId: LicenseSerialization.requiredString(
        decoded,
        'installation_id',
      ),
      customerId: LicenseSerialization.requiredString(decoded, 'customer_id'),
      customerName: LicenseSerialization.requiredString(
        decoded,
        'customer_name',
      ),
      siteId: LicenseSerialization.requiredString(decoded, 'site_id'),
      siteName: LicenseSerialization.requiredString(decoded, 'site_name'),
      city: LicenseSerialization.requiredString(decoded, 'city'),
      deviceLabel: LicenseSerialization.requiredString(decoded, 'device_label'),
      assetTag: LicenseSerialization.optionalString(decoded, 'asset_tag'),
      licenseType: licenseType,
      issuedAt: LicenseSerialization.requiredUtcDateTime(decoded, 'issued_at'),
      notBefore: LicenseSerialization.requiredUtcDateTime(
        decoded,
        'not_before',
      ),
      expiresAt: LicenseSerialization.optionalUtcDateTime(
        decoded,
        'expires_at',
      ),
      graceUntil: LicenseSerialization.optionalUtcDateTime(
        decoded,
        'grace_until',
      ),
      features: _requiredStringList(decoded, 'features'),
    );
  }
}

List<String> _requiredStringList(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is! List || value.any((item) => item is! String)) {
    throw FormatException('El campo $key debe ser una lista de textos.');
  }
  return List<String>.unmodifiable(value.cast<String>());
}
