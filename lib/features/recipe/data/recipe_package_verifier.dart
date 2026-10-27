import 'dart:convert';

import 'package:cryptography/cryptography.dart';

import '../../license/data/license_key_registry.dart';
import '../../license/domain/license_serialization.dart';
import '../domain/offline_recipe_request.dart';
import '../domain/recipe_sample.dart';

class RecipePackageVerifier {
  const RecipePackageVerifier(this._registry);
  final LicenseKeyRegistry _registry;

  static List<int> signingMessage(List<int> payload) => [
    ...utf8.encode(RecipeProtocol.signatureContext),
    ...payload,
  ];

  static Future<String> requestDigest(OfflineRecipeRequest request) async =>
      LicenseSerialization.encodeBase64Url(
        (await Sha256().hash(utf8.encode(request.encode()))).bytes,
      );

  static List<int> bytes(Map<String, dynamic> map, String key, {int? length}) {
    final value = RecipeProtocol.text(map, key);
    final decoded = LicenseSerialization.decodeBase64Url(value);
    if ((length != null && decoded.length != length) ||
        LicenseSerialization.encodeBase64Url(decoded) != value) {
      throw FormatException('El campo $key no tiene un formato válido.');
    }
    return decoded;
  }

  Future<ActiveRecipe> verify(
    String source, {
    required RecipeAuthorizationContext context,
    required SimpleKeyPair recipientKeyPair,
    OfflineRecipeRequest? pendingRequest,
    DateTime? now,
  }) async {
    context.requireLicensed();
    final envelope = RecipeProtocol.object(source);
    RecipeProtocol.fields(envelope, const {
      'schema_version',
      'type',
      'algorithm',
      'key_id',
      'payload',
      'signature',
    });
    if (envelope['schema_version'] != 1 ||
        envelope['type'] != RecipeProtocol.responseType ||
        envelope['algorithm'] != 'Ed25519') {
      throw const FormatException(
        'El archivo no es una receta autorizada de Bitgenial.',
      );
    }
    final publicKey = _registry.find(RecipeProtocol.text(envelope, 'key_id'));
    if (publicKey == null) {
      throw const FormatException(
        'La receta utiliza una clave de firma desconocida.',
      );
    }
    final payloadBytes = bytes(envelope, 'payload');
    if (!await Ed25519().verify(
      signingMessage(payloadBytes),
      signature: Signature(
        bytes(envelope, 'signature', length: 64),
        publicKey: publicKey,
      ),
    )) {
      throw const FormatException('La firma de la receta no es válida.');
    }
    final payload = RecipeProtocol.object(utf8.decode(payloadBytes));
    RecipeProtocol.fields(payload, const {
      'schema_version',
      'type',
      'product',
      'cipher',
      'recipe_id',
      'request_id',
      'request_sha256',
      'installation_id',
      'device_fingerprint_hash',
      'license_id',
      'license_file_sha256',
      'recipient_public_key',
      'ephemeral_public_key',
      'issued_at',
      'valid_until',
      'nonce',
      'ciphertext',
      'mac',
    });
    if (payload['schema_version'] != 1 ||
        payload['type'] != RecipeProtocol.responseType ||
        payload['product'] != 'pondera' ||
        payload['cipher'] != RecipeProtocol.cipher ||
        !context.matches(payload)) {
      throw const FormatException(
        'La receta no corresponde a este equipo o a su licencia vigente.',
      );
    }
    RecipeProtocol.text(payload, 'recipe_id');
    RecipeProtocol.text(payload, 'request_id');
    final currentTime = (now ?? DateTime.now()).toUtc();
    final issuedAt = RecipeProtocol.utc(payload, 'issued_at');
    final validUntil = payload['valid_until'] == null
        ? null
        : RecipeProtocol.utc(payload, 'valid_until');
    if (issuedAt.isAfter(currentTime.add(const Duration(minutes: 5))) ||
        (validUntil != null &&
            (!currentTime.isBefore(validUntil) ||
                !issuedAt.isBefore(validUntil))) ||
        (context.validUntil != null &&
            (validUntil == null || validUntil.isAfter(context.validUntil!)))) {
      throw const FormatException('La vigencia de la receta no es válida.');
    }
    final recipientPublicKey = await recipientKeyPair.extractPublicKey();
    if (payload['recipient_public_key'] !=
        LicenseSerialization.encodeBase64Url(recipientPublicKey.bytes)) {
      throw const FormatException(
        'La receta está cifrada para otra instalación.',
      );
    }
    final requestHash = bytes(payload, 'request_sha256', length: 32);
    if (pendingRequest != null &&
        (payload['request_id'] != pendingRequest.requestId ||
            payload['request_sha256'] != await requestDigest(pendingRequest) ||
            payload['recipient_public_key'] != pendingRequest.publicKey)) {
      throw const FormatException(
        'La respuesta no corresponde a la solicitud pendiente.',
      );
    }
    final shared = await X25519().sharedSecretKey(
      keyPair: recipientKeyPair,
      remotePublicKey: SimplePublicKey(
        bytes(payload, 'ephemeral_public_key', length: 32),
        type: KeyPairType.x25519,
      ),
    );
    if (!(await shared.extractBytes()).any((byte) => byte != 0)) {
      throw const FormatException(
        'La clave de cifrado de la receta no es válida.',
      );
    }
    final key = await Hkdf(hmac: Hmac.sha256(), outputLength: 32).deriveKey(
      secretKey: shared,
      nonce: requestHash,
      info: utf8.encode(RecipeProtocol.encryptionContext),
    );
    final List<int> clearBytes;
    try {
      clearBytes = await AesGcm.with256bits().decrypt(
        SecretBox(
          bytes(payload, 'ciphertext'),
          nonce: bytes(payload, 'nonce', length: 12),
          mac: Mac(bytes(payload, 'mac', length: 16)),
        ),
        secretKey: key,
        aad: requestHash,
      );
    } on SecretBoxAuthenticationError {
      throw const FormatException(
        'No se pudo autenticar el contenido cifrado de la receta.',
      );
    }
    final recipe = RecipeProtocol.object(utf8.decode(clearBytes));
    RecipeProtocol.fields(recipe, const {
      'regex_pattern',
      'trama',
      'valor_esperado',
    });
    final pattern = RecipeProtocol.text(recipe, 'regex_pattern');
    final rawData = RecipeProtocol.text(recipe, 'trama');
    final expected = RecipeProtocol.text(recipe, 'valor_esperado');
    if ((pendingRequest != null &&
            (rawData != pendingRequest.rawData ||
                expected != pendingRequest.expectedValue)) ||
        !RecipeSample(
          rawData,
        ).matchesPattern(pattern, expectedValue: expected)) {
      throw const FormatException(
        'La receta no interpreta correctamente la muestra solicitada.',
      );
    }
    return ActiveRecipe(
      pattern: pattern,
      expectedValue: expected,
      validUntil: validUntil,
    );
  }
}
