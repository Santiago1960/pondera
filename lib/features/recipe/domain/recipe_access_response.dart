import 'dart:convert';

enum RecipeAccessDecision { allow, deny, error }

enum RecipeAccessStatus {
  unregistered,
  trialActive,
  trialExpired,
  licensed,
  gracePeriod,
  expired,
  revoked,
  blocked,
}

enum RecipeAction { replace, delete, keep }

class RecipeAccessResponse {
  const RecipeAccessResponse({
    required this.requestId,
    required this.decision,
    required this.accessStatus,
    required this.reasonCode,
    required this.serverTime,
    required this.message,
    required this.recipeAction,
    this.retryable = false,
    this.recipeId,
    this.regexPattern,
    this.confirmedLicenseId,
    this.trialStartedAt,
    this.trialExpiresAt,
    this.graceUntil,
  });

  static const schemaVersion = 1;

  final String requestId;
  final RecipeAccessDecision decision;
  final RecipeAccessStatus accessStatus;
  final String reasonCode;
  final DateTime serverTime;
  final String message;
  final RecipeAction recipeAction;
  final bool retryable;
  final String? recipeId;
  final String? regexPattern;
  final String? confirmedLicenseId;
  final DateTime? trialStartedAt;
  final DateTime? trialExpiresAt;
  final DateTime? graceUntil;

  factory RecipeAccessResponse.decode(
    String source, {
    required String expectedRequestId,
  }) {
    final decoded = jsonDecode(source);
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('La respuesta debe ser un objeto JSON.');
    }
    if (decoded['schema_version'] != schemaVersion) {
      throw const FormatException('Versión de respuesta no soportada.');
    }

    const allowedFields = {
      'schema_version',
      'request_id',
      'decision',
      'access_status',
      'reason_code',
      'server_time',
      'message',
      'recipe_action',
      'retryable',
      'recipe_id',
      'regex_pattern',
      'confirmed_license_id',
      'trial_started_at',
      'trial_expires_at',
      'grace_until',
    };
    if (decoded.keys.any((key) => !allowedFields.contains(key))) {
      throw const FormatException('La respuesta contiene campos desconocidos.');
    }

    final requestId = _requiredString(decoded, 'request_id');
    if (requestId != expectedRequestId) {
      throw const FormatException('La respuesta corresponde a otra solicitud.');
    }

    final response = RecipeAccessResponse(
      requestId: requestId,
      decision: _parseDecision(_requiredString(decoded, 'decision')),
      accessStatus: _parseStatus(_requiredString(decoded, 'access_status')),
      reasonCode: _parseReason(_requiredString(decoded, 'reason_code')),
      serverTime: _requiredUtc(decoded, 'server_time'),
      message: _requiredString(decoded, 'message'),
      recipeAction: _parseAction(_requiredString(decoded, 'recipe_action')),
      retryable: _optionalBool(decoded, 'retryable') ?? false,
      recipeId: _optionalString(decoded, 'recipe_id'),
      regexPattern: _optionalString(decoded, 'regex_pattern'),
      confirmedLicenseId: _optionalString(decoded, 'confirmed_license_id'),
      trialStartedAt: _optionalUtc(decoded, 'trial_started_at'),
      trialExpiresAt: _optionalUtc(decoded, 'trial_expires_at'),
      graceUntil: _optionalUtc(decoded, 'grace_until'),
    );
    response._validateDecision();
    return response;
  }

  void _validateDecision() {
    final valid = switch (decision) {
      RecipeAccessDecision.allow =>
        recipeAction == RecipeAction.replace &&
            regexPattern != null &&
            regexPattern!.isNotEmpty,
      RecipeAccessDecision.deny =>
        recipeAction == RecipeAction.delete && regexPattern == null,
      RecipeAccessDecision.error => recipeAction == RecipeAction.keep,
    };
    if (!valid) {
      throw const FormatException('La decisión y la acción no son coherentes.');
    }
  }
}

RecipeAccessDecision _parseDecision(String value) => switch (value) {
  'allow' => RecipeAccessDecision.allow,
  'deny' => RecipeAccessDecision.deny,
  'error' => RecipeAccessDecision.error,
  _ => throw FormatException('Decisión desconocida: $value.'),
};

RecipeAccessStatus _parseStatus(String value) => switch (value) {
  'unregistered' => RecipeAccessStatus.unregistered,
  'trial_active' => RecipeAccessStatus.trialActive,
  'trial_expired' => RecipeAccessStatus.trialExpired,
  'licensed' => RecipeAccessStatus.licensed,
  'grace_period' => RecipeAccessStatus.gracePeriod,
  'expired' => RecipeAccessStatus.expired,
  'revoked' => RecipeAccessStatus.revoked,
  'blocked' => RecipeAccessStatus.blocked,
  _ => throw FormatException('Estado desconocido: $value.'),
};

RecipeAction _parseAction(String value) => switch (value) {
  'replace' => RecipeAction.replace,
  'delete' => RecipeAction.delete,
  'keep' => RecipeAction.keep,
  _ => throw FormatException('Acción desconocida: $value.'),
};

String _parseReason(String value) {
  const allowed = {
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
  if (!allowed.contains(value)) {
    throw FormatException('Motivo desconocido: $value.');
  }
  return value;
}

String _requiredString(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is! String || value.trim().isEmpty || value != value.trim()) {
    throw FormatException('El campo $key debe ser un texto válido.');
  }
  return value;
}

String? _optionalString(Map<String, dynamic> json, String key) {
  if (!json.containsKey(key)) return null;
  return _requiredString(json, key);
}

bool? _optionalBool(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value == null && !json.containsKey(key)) return null;
  if (value is! bool) {
    throw FormatException('El campo $key debe ser booleano.');
  }
  return value;
}

DateTime _requiredUtc(Map<String, dynamic> json, String key) {
  final source = _requiredString(json, key);
  final value = DateTime.tryParse(source);
  final hasUtcOffset = source.endsWith('Z') || source.endsWith('+00:00');
  if (!hasUtcOffset || value == null || !value.isUtc) {
    throw FormatException('El campo $key debe ser una fecha UTC.');
  }
  return value;
}

DateTime? _optionalUtc(Map<String, dynamic> json, String key) {
  if (!json.containsKey(key)) return null;
  return _requiredUtc(json, key);
}
