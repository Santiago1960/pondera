import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:pondera/features/recipe/domain/recipe_access_response.dart';

void main() {
  const requestId = 'RAC-AAAAAAAA-BBBB-4CCC-8DDD-EEEEEEEEEEEE';

  test('acepta una autorización coherente', () {
    final response = RecipeAccessResponse.decode(
      jsonEncode({
        'schema_version': 1,
        'request_id': requestId,
        'decision': 'allow',
        'access_status': 'trial_active',
        'reason_code': 'trial_valid',
        'server_time': '2026-08-11T17:00:00Z',
        'message': 'Periodo de prueba vigente.',
        'recipe_action': 'replace',
        'recipe_id': 'RECIPE-AAAAAAAA-BBBB-4CCC-8DDD-EEEEEEEEEEEE',
        'regex_pattern': r'([0-9]+[\,.][0-9]+)',
        'trial_expires_at': '2026-08-20T17:00:00Z',
      }),
      expectedRequestId: requestId,
    );

    expect(response.decision, RecipeAccessDecision.allow);
    expect(response.recipeAction, RecipeAction.replace);
    expect(response.accessStatus, RecipeAccessStatus.trialActive);
    expect(response.trialExpiresAt, DateTime.utc(2026, 8, 20, 17));
  });

  test('rechaza estados desconocidos o una solicitud diferente', () {
    Map<String, Object?> response({
      String accessStatus = 'trial_active',
      String responseRequestId = requestId,
    }) => {
      'schema_version': 1,
      'request_id': responseRequestId,
      'decision': 'error',
      'access_status': accessStatus,
      'reason_code': 'internal_error',
      'server_time': '2026-08-11T17:00:00Z',
      'message': 'No se pudo procesar la solicitud.',
      'recipe_action': 'keep',
    };

    expect(
      () => RecipeAccessResponse.decode(
        jsonEncode(response(accessStatus: 'inventado')),
        expectedRequestId: requestId,
      ),
      throwsFormatException,
    );
    expect(
      () => RecipeAccessResponse.decode(
        jsonEncode(response(responseRequestId: 'RAC-OTRA')),
        expectedRequestId: requestId,
      ),
      throwsFormatException,
    );
  });

  test('rechaza decisiones y acciones incoherentes', () {
    expect(
      () => RecipeAccessResponse.decode(
        jsonEncode({
          'schema_version': 1,
          'request_id': requestId,
          'decision': 'deny',
          'access_status': 'blocked',
          'reason_code': 'installation_blocked',
          'server_time': '2026-08-11T17:00:00Z',
          'message': 'Instalación bloqueada.',
          'recipe_action': 'keep',
        }),
        expectedRequestId: requestId,
      ),
      throwsFormatException,
    );
  });

  test('acepta un rechazo definitivo que ordena eliminar la receta', () {
    final response = RecipeAccessResponse.decode(
      jsonEncode({
        'schema_version': 1,
        'request_id': requestId,
        'decision': 'deny',
        'access_status': 'blocked',
        'reason_code': 'installation_blocked',
        'server_time': '2026-08-11T17:00:00Z',
        'message': 'Instalación bloqueada.',
        'recipe_action': 'delete',
      }),
      expectedRequestId: requestId,
    );

    expect(response.decision, RecipeAccessDecision.deny);
    expect(response.recipeAction, RecipeAction.delete);
  });

  test('acepta UTC expresado con offset cero', () {
    final response = RecipeAccessResponse.decode(
      jsonEncode({
        'schema_version': 1,
        'request_id': requestId,
        'decision': 'allow',
        'access_status': 'trial_active',
        'reason_code': 'trial_valid',
        'server_time': '2026-08-11T23:16:43.318Z',
        'message': 'Periodo de prueba vigente.',
        'recipe_action': 'replace',
        'trial_expires_at': '2026-08-26T18:56:09.573404+00:00',
        'recipe_id': 'RECIPE-AAAAAAAA-BBBB-4CCC-8DDD-EEEEEEEEEEEE',
        'regex_pattern': r'([0-9]+[\,\.][0-9]+)',
      }),
      expectedRequestId: requestId,
    );

    expect(response.trialExpiresAt!.isUtc, isTrue);
    expect(
      response.trialExpiresAt,
      DateTime.utc(2026, 8, 26, 18, 56, 9, 573, 404),
    );
  });
}
