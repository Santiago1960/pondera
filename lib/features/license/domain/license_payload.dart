import 'dart:convert';

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

    final licenseTypeValue = _requiredString(decoded, 'license_type');
    final licenseType = LicenseType.values
        .where((value) => value.name == licenseTypeValue)
        .firstOrNull;
    if (licenseType == null) {
      throw FormatException(
        'Tipo de licencia no soportado: $licenseTypeValue.',
      );
    }

    return LicensePayload(
      licenseId: _requiredString(decoded, 'license_id'),
      requestId: _requiredString(decoded, 'request_id'),
      product: _requiredString(decoded, 'product'),
      installationId: _requiredString(decoded, 'installation_id'),
      customerId: _requiredString(decoded, 'customer_id'),
      customerName: _requiredString(decoded, 'customer_name'),
      siteId: _requiredString(decoded, 'site_id'),
      siteName: _requiredString(decoded, 'site_name'),
      city: _requiredString(decoded, 'city'),
      deviceLabel: _requiredString(decoded, 'device_label'),
      assetTag: _optionalString(decoded, 'asset_tag'),
      licenseType: licenseType,
      issuedAt: _requiredDateTime(decoded, 'issued_at'),
      notBefore: _requiredDateTime(decoded, 'not_before'),
      expiresAt: _optionalDateTime(decoded, 'expires_at'),
      graceUntil: _optionalDateTime(decoded, 'grace_until'),
      features: _requiredStringList(decoded, 'features'),
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

DateTime? _optionalDateTime(Map<String, dynamic> json, String key) {
  if (json[key] == null) {
    return null;
  }
  return _requiredDateTime(json, key);
}

List<String> _requiredStringList(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is! List || value.any((item) => item is! String)) {
    throw FormatException('El campo $key debe ser una lista de textos.');
  }
  return List<String>.unmodifiable(value.cast<String>());
}
