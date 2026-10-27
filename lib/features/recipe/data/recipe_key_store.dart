import 'dart:convert';
import 'dart:math';

import 'package:cryptography/cryptography.dart';

import '../../license/data/installation_identity_repository.dart';
import '../../license/domain/license_serialization.dart';
import '../domain/offline_recipe_request.dart';

class RecipeKeyStore {
  RecipeKeyStore(this._store);
  final InstallationValueStore _store;
  static const storageKey = 'pondera_recipe_x25519_seed_v1';

  Future<List<int>> _seed({required bool create}) async {
    var encoded = await _store.read(storageKey);
    if (encoded == null || encoded.isEmpty) {
      if (!create) {
        throw const FormatException(
          'No está disponible la clave de esta instalación. Genera una solicitud nueva.',
        );
      }
      final random = Random.secure();
      encoded = LicenseSerialization.encodeBase64Url(
        List<int>.generate(32, (_) => random.nextInt(256)),
      );
      await _store.write(storageKey, encoded);
      if (await _store.read(storageKey) != encoded) {
        throw StateError('No se pudo conservar la clave de la receta.');
      }
    }
    final bytes = LicenseSerialization.decodeBase64Url(encoded);
    if (bytes.length != 32) {
      throw const FormatException('La clave local de recetas está dañada.');
    }
    return bytes;
  }

  Future<SimpleKeyPair> keyPair({bool create = false}) async =>
      X25519().newKeyPairFromSeed(await _seed(create: create));

  Future<SecretKey> localKey({bool create = false}) async =>
      Hkdf(hmac: Hmac.sha256(), outputLength: 32).deriveKey(
        secretKey: SecretKey(await _seed(create: create)),
        nonce: utf8.encode(RecipeProtocol.localContext),
        info: utf8.encode('AES-256-GCM'),
      );
}
