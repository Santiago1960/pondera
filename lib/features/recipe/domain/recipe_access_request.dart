import 'dart:convert';

class RecipeAccessRequest {
  const RecipeAccessRequest({
    required this.requestId,
    required this.installationId,
    required this.deviceFingerprintHash,
    required this.platform,
    required this.appVersion,
    required this.rawData,
    required this.expectedValue,
    required this.createdAt,
    this.licenseId,
    this.licenseFileSha256,
  });

  static const schemaVersion = 1;
  static const product = 'pondera';

  final String requestId;
  final String installationId;
  final String deviceFingerprintHash;
  final String platform;
  final String appVersion;
  final String rawData;
  final String expectedValue;
  final DateTime createdAt;
  final String? licenseId;
  final String? licenseFileSha256;

  Map<String, Object> toJson() {
    _validate();
    return {
      'schema_version': schemaVersion,
      'request_id': requestId,
      'product': product,
      'installation_id': installationId,
      'device_fingerprint_hash': deviceFingerprintHash,
      'platform': platform,
      'app_version': appVersion,
      'trama': rawData,
      'valor_esperado': expectedValue,
      'created_at': createdAt.toUtc().toIso8601String(),
      'license_id': ?licenseId,
      'license_file_sha256': ?licenseFileSha256,
    };
  }

  String encode() => jsonEncode(toJson());

  void _validate() {
    final licensePairIsComplete =
        (licenseId == null) == (licenseFileSha256 == null);
    if (!licensePairIsComplete ||
        !_racId.hasMatch(requestId) ||
        !_installationId.hasMatch(installationId) ||
        !_sha256.hasMatch(deviceFingerprintHash) ||
        !const {'windows', 'macos'}.contains(platform) ||
        appVersion.isEmpty ||
        appVersion != appVersion.trim() ||
        appVersion.length > 32 ||
        !_ascii.hasMatch(appVersion) ||
        rawData.isEmpty ||
        utf8.encode(rawData).length > 4096 ||
        expectedValue.length > 32 ||
        !_decimal.hasMatch(expectedValue) ||
        (licenseId != null && !_licenseId.hasMatch(licenseId!)) ||
        (licenseFileSha256 != null && !_sha256.hasMatch(licenseFileSha256!))) {
      throw const FormatException('Solicitud de receta inválida.');
    }
  }
}

final _uuid =
    r'[0-9A-F]{8}-[0-9A-F]{4}-4[0-9A-F]{3}-[89AB][0-9A-F]{3}-[0-9A-F]{12}';
final _racId = RegExp('^RAC-$_uuid\$');
final _installationId = RegExp('^INSTALL-$_uuid\$');
final _licenseId = RegExp('^LIC-$_uuid\$');
final _sha256 = RegExp(r'^sha256:[0-9a-f]{64}$');
final _ascii = RegExp(r'^[\x20-\x7e]+$');
final _decimal = RegExp(r'^[+-]?[0-9]+(?:[.,][0-9]+)?$');
