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
    this.deviceLabel,
    this.licenseId,
    this.licenseFileSha256,
    this.customerId,
    this.customerName,
    this.siteId,
    this.siteName,
    this.city,
    this.assetTag,
    this.currentRecipePattern,
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
  final String? deviceLabel;
  final String? licenseId;
  final String? licenseFileSha256;
  final String? customerId;
  final String? customerName;
  final String? siteId;
  final String? siteName;
  final String? city;
  final String? assetTag;
  final String? currentRecipePattern;

  Map<String, Object?> toJson() {
    _validate();
    return {
      'schema_version': schemaVersion,
      'request_id': requestId,
      'product': product,
      'platform': platform,
      'app_version': appVersion,
      'created_at': createdAt.toUtc().toIso8601String(),
      'installation_id': installationId,
      'device_fingerprint_hash': deviceFingerprintHash,
      'device_label': deviceLabel,
      'license_id': licenseId,
      'license_file_sha256': licenseFileSha256,
      'customer_id': customerId,
      'customer_name': customerName,
      'site_id': siteId,
      'site_name': siteName,
      'city': city,
      'asset_tag': assetTag,
      'current_recipe_pattern': currentRecipePattern,
      'trama': rawData,
      'valor_esperado': expectedValue,
    };
  }

  String encode() => jsonEncode(toJson());

  void _validate() {
    final customerFields = [
      deviceLabel,
      customerId,
      customerName,
      siteId,
      siteName,
      city,
    ];
    final licensePairIsComplete =
        (licenseId == null) == (licenseFileSha256 == null);
    final customerIdentityIsComplete = licenseId == null
        ? customerFields.every((value) => value == null) && assetTag == null
        : customerFields.every((value) => value != null);
    if (!licensePairIsComplete ||
        !customerIdentityIsComplete ||
        !_racId.hasMatch(requestId) ||
        !_installationId.hasMatch(installationId) ||
        !_sha256.hasMatch(deviceFingerprintHash) ||
        !const {'windows', 'macos', 'android'}.contains(platform) ||
        appVersion.isEmpty ||
        appVersion != appVersion.trim() ||
        appVersion.length > 32 ||
        !_ascii.hasMatch(appVersion) ||
        rawData.isEmpty ||
        utf8.encode(rawData).length > 4096 ||
        expectedValue.length > 32 ||
        !_decimal.hasMatch(expectedValue) ||
        !_validOptionalText(licenseId, 128) ||
        !_validOptionalText(deviceLabel, 256) ||
        !_validOptionalText(customerId, 256) ||
        !_validOptionalText(customerName, 256) ||
        !_validOptionalText(siteId, 256) ||
        !_validOptionalText(siteName, 256) ||
        !_validOptionalText(city, 256) ||
        !_validOptionalText(assetTag, 256) ||
        (currentRecipePattern != null &&
            (currentRecipePattern!.isEmpty ||
                utf8.encode(currentRecipePattern!).length > 4096)) ||
        (licenseFileSha256 != null && !_sha256.hasMatch(licenseFileSha256!))) {
      throw const FormatException('Solicitud de receta inválida.');
    }
  }
}

bool _validOptionalText(String? value, int maxLength) {
  return value == null ||
      (value == value.trim() &&
          value.isNotEmpty &&
          value.length <= maxLength &&
          !_controlCharacter.hasMatch(value));
}

final _uuid =
    r'[0-9A-F]{8}-[0-9A-F]{4}-4[0-9A-F]{3}-[89AB][0-9A-F]{3}-[0-9A-F]{12}';
final _racId = RegExp('^RAC-$_uuid\$');
final _installationId = RegExp('^INSTALL-$_uuid\$');
final _sha256 = RegExp(r'^sha256:[0-9a-f]{64}$');
final _ascii = RegExp(r'^[\x20-\x7e]+$');
final _decimal = RegExp(r'^[+-]?[0-9]+(?:[.,][0-9]+)?$');
final _controlCharacter = RegExp(r'[\u0000-\u001f\u007f]');
