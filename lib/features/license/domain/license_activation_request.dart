import 'dart:convert';

import 'license_serialization.dart';

class LicenseActivationRequest {
  const LicenseActivationRequest({
    required this.requestId,
    required this.installationId,
    required this.product,
    required this.platform,
    required this.appVersion,
    required this.deviceFingerprintHash,
    required this.customerName,
    required this.siteName,
    required this.city,
    required this.deviceLabel,
    required this.createdAt,
    this.assetTag,
  });

  static const schemaVersion = 1;

  final String requestId;
  final String installationId;
  final String product;
  final String platform;
  final String appVersion;
  final String deviceFingerprintHash;
  final String customerName;
  final String siteName;
  final String city;
  final String deviceLabel;
  final String? assetTag;
  final DateTime createdAt;

  Map<String, Object?> toJson() {
    return {
      'schema_version': schemaVersion,
      'request_id': requestId,
      'installation_id': installationId,
      'product': product,
      'platform': platform,
      'app_version': appVersion,
      'device_fingerprint_hash': deviceFingerprintHash,
      'customer_name': customerName,
      'site_name': siteName,
      'city': city,
      'device_label': deviceLabel,
      'asset_tag': assetTag,
      'created_at': createdAt.toUtc().toIso8601String(),
    };
  }

  String encode() => jsonEncode(toJson());

  factory LicenseActivationRequest.decode(String source) {
    final decoded = jsonDecode(source);
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('La solicitud debe ser un objeto JSON.');
    }
    if (decoded['schema_version'] != schemaVersion) {
      throw const FormatException('Versión de solicitud no soportada.');
    }

    return LicenseActivationRequest(
      requestId: LicenseSerialization.requiredString(decoded, 'request_id'),
      installationId: LicenseSerialization.requiredString(
        decoded,
        'installation_id',
      ),
      product: LicenseSerialization.requiredString(decoded, 'product'),
      platform: LicenseSerialization.requiredString(decoded, 'platform'),
      appVersion: LicenseSerialization.requiredString(decoded, 'app_version'),
      deviceFingerprintHash: LicenseSerialization.requiredString(
        decoded,
        'device_fingerprint_hash',
      ),
      customerName: LicenseSerialization.requiredString(
        decoded,
        'customer_name',
      ),
      siteName: LicenseSerialization.requiredString(decoded, 'site_name'),
      city: LicenseSerialization.requiredString(decoded, 'city'),
      deviceLabel: LicenseSerialization.requiredString(decoded, 'device_label'),
      assetTag: LicenseSerialization.optionalString(decoded, 'asset_tag'),
      createdAt: LicenseSerialization.requiredUtcDateTime(
        decoded,
        'created_at',
      ),
    );
  }
}
