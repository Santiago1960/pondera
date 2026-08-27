import 'dart:convert';

class LicenseStatusResponse {
  const LicenseStatusResponse({
    required this.requestId,
    required this.installationId,
    required this.licenseId,
    required this.decision,
    required this.accessStatus,
    required this.reasonCode,
    required this.serverTime,
  });

  final String requestId;
  final String installationId;
  final String? licenseId;
  final String decision;
  final String accessStatus;
  final String reasonCode;
  final DateTime serverTime;

  bool get revokesLicense =>
      decision == 'deny' && reasonCode == 'license_revoked';
  bool get blocksInstallation =>
      decision == 'deny' && reasonCode == 'installation_blocked';
  bool get isAllow => decision == 'allow';
  bool get isDefinitiveBlock => revokesLicense || blocksInstallation;

  String get message => switch (reasonCode) {
    'license_revoked' => 'La licencia fue revocada por Bitgenial.',
    'installation_blocked' => 'La instalación fue bloqueada por Bitgenial.',
    _ => 'La licencia fue verificada con el servidor.',
  };

  factory LicenseStatusResponse.decode(
    List<int> source, {
    required String expectedInstallationId,
    String? expectedRequestId,
    String? expectedLicenseId,
    bool checkLicenseId = false,
  }) {
    final decoded = jsonDecode(utf8.decode(source));
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException(
        'El estado de licencia debe ser un objeto JSON.',
      );
    }
    const allowed = {
      'schema_version',
      'request_id',
      'product',
      'installation_id',
      'license_id',
      'decision',
      'access_status',
      'reason_code',
      'server_time',
    };
    if (decoded.keys.any((key) => !allowed.contains(key)) ||
        decoded['schema_version'] != 1 ||
        decoded['product'] != 'pondera') {
      throw const FormatException(
        'El estado de licencia tiene un formato inválido.',
      );
    }
    final requestId = _requiredString(decoded, 'request_id');
    final installationId = _requiredString(decoded, 'installation_id');
    final licenseId = decoded['license_id'];
    if (licenseId != null && licenseId is! String) {
      throw const FormatException('license_id debe ser texto o null.');
    }
    if ((expectedRequestId != null && requestId != expectedRequestId) ||
        installationId != expectedInstallationId ||
        (checkLicenseId && licenseId != expectedLicenseId)) {
      throw const FormatException(
        'El estado firmado corresponde a otra solicitud o licencia.',
      );
    }
    final response = LicenseStatusResponse(
      requestId: requestId,
      installationId: installationId,
      licenseId: licenseId as String?,
      decision: _requiredString(decoded, 'decision'),
      accessStatus: _requiredString(decoded, 'access_status'),
      reasonCode: _requiredString(decoded, 'reason_code'),
      serverTime: _requiredUtc(decoded, 'server_time'),
    );
    response._validateDecision();
    return response;
  }

  void _validateDecision() {
    const statuses = {
      'unregistered',
      'trial_active',
      'trial_expired',
      'licensed',
      'grace_period',
      'expired',
      'revoked',
      'blocked',
    };
    const reasons = {
      'trial_started',
      'trial_valid',
      'trial_expired',
      'license_valid',
      'license_grace',
      'license_expired',
      'license_revoked',
      'installation_blocked',
      'license_mismatch',
      'idempotency_conflict',
      'invalid_request',
      'unsupported_product',
      'rate_limited',
      'service_unavailable',
      'internal_error',
    };
    final coherent = switch (decision) {
      'allow' => const {
        'trial_active',
        'licensed',
        'grace_period',
      }.contains(accessStatus),
      'deny' => const {
        'trial_expired',
        'expired',
        'revoked',
        'blocked',
      }.contains(accessStatus),
      'error' => true,
      _ => false,
    };
    if (!coherent ||
        !statuses.contains(accessStatus) ||
        !reasons.contains(reasonCode)) {
      throw const FormatException(
        'La decisión remota de licencia es incoherente.',
      );
    }
  }
}

String _requiredString(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is! String || value.isEmpty || value != value.trim()) {
    throw FormatException('$key debe ser un texto válido.');
  }
  return value;
}

DateTime _requiredUtc(Map<String, dynamic> json, String key) {
  final source = _requiredString(json, key);
  final value = DateTime.tryParse(source);
  if (value == null || !value.isUtc || !source.endsWith('Z')) {
    throw FormatException('$key debe ser una fecha UTC.');
  }
  return value;
}
