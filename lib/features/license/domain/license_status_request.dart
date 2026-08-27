import 'dart:convert';

class LicenseStatusRequest {
  const LicenseStatusRequest({
    required this.requestId,
    required this.installationId,
    required this.deviceFingerprintHash,
    required this.platform,
    required this.appVersion,
    required this.createdAt,
    required this.licenseId,
    required this.licenseFileSha256,
  });

  final String requestId;
  final String installationId;
  final String deviceFingerprintHash;
  final String platform;
  final String appVersion;
  final DateTime createdAt;
  final String licenseId;
  final String licenseFileSha256;

  String encode() => jsonEncode({
    'schema_version': 1,
    'request_id': requestId,
    'product': 'pondera',
    'installation_id': installationId,
    'device_fingerprint_hash': deviceFingerprintHash,
    'platform': platform,
    'app_version': appVersion,
    'created_at': createdAt.toUtc().toIso8601String(),
    'license_id': licenseId,
    'license_file_sha256': licenseFileSha256,
  });
}
