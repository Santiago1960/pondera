import 'dart:convert';

import 'package:cryptography/cryptography.dart';

import '../../license/domain/license_identifier_generator.dart';
import '../../license/domain/license_serialization.dart';
import '../data/recipe_key_store.dart';
import '../data/recipe_package_verifier.dart';
import '../data/recipe_state_repository.dart';
import '../domain/offline_recipe_request.dart';
import '../domain/recipe_sample.dart';

class AuthorizedRecipeService {
  const AuthorizedRecipeService(this._repository, this._keys, this._verifier);
  final RecipeStateRepository _repository;
  final RecipeKeyStore _keys;
  final RecipePackageVerifier _verifier;

  Future<OfflineRecipeRequest> createRequest({
    required RecipeAuthorizationContext context,
    required RecipeSample sample,
    required String expectedValue,
    required String platform,
    required String appVersion,
    DateTime? now,
  }) async {
    context.requireLicensed();
    final publicKey = await (await _keys.keyPair(
      create: true,
    )).extractPublicKey();
    return OfflineRecipeRequest({
      'schema_version': 1,
      'type': RecipeProtocol.requestType,
      'product': 'pondera',
      'request_id': LicenseIdentifierGenerator().createRecipeAccessRequestId(),
      'installation_id': context.installationId,
      'device_fingerprint_hash': context.deviceFingerprintHash,
      'license_id': context.licenseId,
      'license_file_sha256': context.licenseSha256,
      'license_document': context.licenseDocument,
      'recipient_public_key': LicenseSerialization.encodeBase64Url(
        publicKey.bytes,
      ),
      'cipher': RecipeProtocol.cipher,
      'platform': platform,
      'app_version': appVersion,
      'created_at': (now ?? DateTime.now()).toUtc().toIso8601String(),
      'trama': sample.rawData,
      'valor_esperado': expectedValue.trim(),
    });
  }

  Future<void> rememberRequest(OfflineRecipeRequest request) async {
    final state = _repository.load();
    state['pending'] = request.data;
    await _repository.save(state);
  }

  Future<ActiveRecipe> importResponse(
    String document, {
    required RecipeAuthorizationContext context,
    DateTime? now,
  }) async {
    context.requireLicensed();
    final state = _repository.load();
    final pending = state['pending'] as Map<String, dynamic>?;
    if (pending == null) {
      final active = state['active'] as Map<String, dynamic>?;
      if (active?['source'] == 'offline' && active?['document'] == document) {
        return (await loadActive(context: context, now: now))!;
      }
      throw const FormatException(
        'No hay una solicitud pendiente para esta respuesta. Genera una solicitud nueva.',
      );
    }
    final recipe = await _verifier.verify(
      document,
      context: context,
      recipientKeyPair: await _keys.keyPair(),
      pendingRequest: OfflineRecipeRequest(pending),
      now: now,
    );
    await _repository.save({
      'pending': null,
      'active': {'source': 'offline', 'document': document},
    });
    return recipe;
  }

  Future<ActiveRecipe?> loadActive({
    required RecipeAuthorizationContext context,
    DateTime? now,
  }) async {
    if (!context.isUsable) return null;
    final active = _repository.load()['active'] as Map<String, dynamic>?;
    if (active == null) return null;
    if (active['source'] == 'offline') {
      RecipeProtocol.fields(active, const {'source', 'document'});
      return _verifier.verify(
        RecipeProtocol.text(active, 'document'),
        context: context,
        recipientKeyPair: await _keys.keyPair(),
        now: now,
      );
    }
    if (active['source'] != 'online') {
      throw const FormatException(
        'El origen de la receta guardada no es válido.',
      );
    }
    RecipeProtocol.fields(active, const {
      'source',
      'nonce',
      'ciphertext',
      'mac',
    });
    final List<int> decoded;
    try {
      decoded = await AesGcm.with256bits().decrypt(
        SecretBox(
          RecipePackageVerifier.bytes(active, 'ciphertext'),
          nonce: RecipePackageVerifier.bytes(active, 'nonce', length: 12),
          mac: Mac(RecipePackageVerifier.bytes(active, 'mac', length: 16)),
        ),
        secretKey: await _keys.localKey(),
        aad: utf8.encode(RecipeProtocol.localContext),
      );
    } on SecretBoxAuthenticationError {
      throw const FormatException(
        'La receta guardada fue alterada o corresponde a otro perfil.',
      );
    }
    final data = RecipeProtocol.object(utf8.decode(decoded));
    RecipeProtocol.fields(data, const {
      'type',
      'installation_id',
      'device_fingerprint_hash',
      'license_id',
      'license_file_sha256',
      'regex_pattern',
      'trama',
      'valor_esperado',
    });
    final pattern = RecipeProtocol.text(data, 'regex_pattern');
    final expected = RecipeProtocol.text(data, 'valor_esperado');
    if (data['type'] != 'bitgenial.pondera.online-recipe-cache' ||
        !context.matches(data) ||
        !RecipeSample(
          RecipeProtocol.text(data, 'trama'),
        ).matchesPattern(pattern, expectedValue: expected)) {
      throw const FormatException(
        'La receta guardada no corresponde a esta licencia o no es válida.',
      );
    }
    return ActiveRecipe(pattern: pattern, expectedValue: expected);
  }

  Future<void> saveOnline({
    required RecipeAuthorizationContext context,
    required RecipeSample sample,
    required String pattern,
    required String expectedValue,
  }) async {
    if (!context.isUsable ||
        !sample.matchesPattern(pattern, expectedValue: expectedValue)) {
      throw const FormatException(
        'La licencia o la receta recibida no son válidas.',
      );
    }
    final data = utf8.encode(
      jsonEncode({
        'type': 'bitgenial.pondera.online-recipe-cache',
        'installation_id': context.installationId,
        'device_fingerprint_hash': context.deviceFingerprintHash,
        'license_id': context.licenseId,
        'license_file_sha256': context.licenseSha256,
        'regex_pattern': pattern,
        'trama': sample.rawData,
        'valor_esperado': expectedValue,
      }),
    );
    final box = await AesGcm.with256bits().encrypt(
      data,
      secretKey: await _keys.localKey(create: true),
      aad: utf8.encode(RecipeProtocol.localContext),
    );
    await _repository.save({
      'pending': null,
      'active': {
        'source': 'online',
        'nonce': LicenseSerialization.encodeBase64Url(box.nonce),
        'ciphertext': LicenseSerialization.encodeBase64Url(box.cipherText),
        'mac': LicenseSerialization.encodeBase64Url(box.mac.bytes),
      },
    });
  }

  Future<void> clear() => _repository.clear();
}
