import 'dart:convert';

class LicenseActivationRequest {
  const LicenseActivationRequest({
    required this.requestId,
    required this.installationId,
    required this.product,
    required this.platform,
    required this.appVersion,
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
      requestId: _requiredString(decoded, 'request_id'),
      installationId: _requiredString(decoded, 'installation_id'),
      product: _requiredString(decoded, 'product'),
      platform: _requiredString(decoded, 'platform'),
      appVersion: _requiredString(decoded, 'app_version'),
      customerName: _requiredString(decoded, 'customer_name'),
      siteName: _requiredString(decoded, 'site_name'),
      city: _requiredString(decoded, 'city'),
      deviceLabel: _requiredString(decoded, 'device_label'),
      assetTag: _optionalString(decoded, 'asset_tag'),
      createdAt: _requiredDateTime(decoded, 'created_at'),
    );
  }
}

String _requiredString(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is! String || value.trim().isEmpty) {
    throw FormatException('El campo $key es obligatorio.');
  }
  return value.trim();
}

String? _optionalString(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value == null) {
    return null;
  }
  if (value is! String) {
    throw FormatException('El campo $key debe ser texto.');
  }
  final trimmed = value.trim();
  return trimmed.isEmpty ? null : trimmed;
}

DateTime _requiredDateTime(Map<String, dynamic> json, String key) {
  final value = _requiredString(json, key);
  final parsed = DateTime.tryParse(value);
  if (parsed == null) {
    throw FormatException('El campo $key debe ser una fecha ISO 8601.');
  }
  return parsed.toUtc();
}
