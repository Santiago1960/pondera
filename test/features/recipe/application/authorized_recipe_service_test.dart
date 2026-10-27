import 'dart:convert';

import 'package:cryptography/cryptography.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pondera/core/constants/preference_keys.dart';
import 'package:pondera/features/license/data/installation_identity_repository.dart';
import 'package:pondera/features/license/data/license_key_registry.dart';
import 'package:pondera/features/license/domain/license_key_ids.dart';
import 'package:pondera/features/license/domain/license_serialization.dart';
import 'package:pondera/features/recipe/application/authorized_recipe_service.dart';
import 'package:pondera/features/recipe/data/recipe_key_store.dart';
import 'package:pondera/features/recipe/data/recipe_package_verifier.dart';
import 'package:pondera/features/recipe/data/recipe_state_repository.dart';
import 'package:pondera/features/recipe/domain/offline_recipe_request.dart';
import 'package:pondera/features/recipe/domain/recipe_sample.dart';
import 'package:pondera/features/scale_reading/domain/reading_parser.dart';
import 'package:shared_preferences/shared_preferences.dart';

final _now = DateTime.utc(2026, 10, 26, 18);
final _end = _now.add(const Duration(days: 30));
const _raw = '\x02+000.563kg\x03\r\n';
const _pattern = r'(?<weight>[+-]?[0-9]+\.[0-9]{3})kg';

class _SecureStore implements InstallationValueStore {
  final values = <String, String>{};
  @override
  Future<String?> read(String key) async => values[key];
  @override
  Future<void> write(String key, String value) async {
    values[key] = value;
  }
}

RecipeAuthorizationContext _context({
  String installation = 'INSTALL-ONE',
  String fingerprint = 'sha256:machine-one',
  String? licenseId = 'LIC-ONE',
  String? licenseHash = 'sha256:license-one',
  bool usable = true,
}) => RecipeAuthorizationContext(
  installationId: installation,
  deviceFingerprintHash: fingerprint,
  isUsable: usable,
  licenseId: licenseId,
  licenseSha256: licenseHash,
  licenseDocument: licenseId == null ? null : 'signed-license-fixture',
  validUntil: _end,
);

// Emisor exclusivamente de prueba: semilla pública del vector RFC 8032.
// No se ejecuta contra servicios ni claves de producción.
Future<String> _issue(
  OfflineRecipeRequest request, {
  String pattern = _pattern,
  String? rawData,
  String? expectedValue,
  Map<String, dynamic> overrides = const {},
  bool corruptMac = false,
}) async {
  final ecdh = X25519();
  final ephemeral = await ecdh.newKeyPair();
  final ephemeralPublic = await ephemeral.extractPublicKey();
  final shared = await ecdh.sharedSecretKey(
    keyPair: ephemeral,
    remotePublicKey: SimplePublicKey(
      LicenseSerialization.decodeBase64Url(request.publicKey),
      type: KeyPairType.x25519,
    ),
  );
  final requestHash = await RecipePackageVerifier.requestDigest(request);
  final salt = LicenseSerialization.decodeBase64Url(requestHash);
  final key = await Hkdf(hmac: Hmac.sha256(), outputLength: 32).deriveKey(
    secretKey: shared,
    nonce: salt,
    info: utf8.encode(RecipeProtocol.encryptionContext),
  );
  final box = await AesGcm.with256bits().encrypt(
    utf8.encode(
      jsonEncode({
        'regex_pattern': pattern,
        'trama': rawData ?? request.rawData,
        'valor_esperado': expectedValue ?? request.expectedValue,
      }),
    ),
    secretKey: key,
    aad: salt,
  );
  final mac = List<int>.from(box.mac.bytes);
  if (corruptMac) mac[0] ^= 1;
  final payload = {
    'schema_version': 1,
    'type': RecipeProtocol.responseType,
    'product': 'pondera',
    'cipher': RecipeProtocol.cipher,
    'recipe_id': 'RECIPE-TEST',
    'request_id': request.requestId,
    'request_sha256': requestHash,
    'installation_id': request.data['installation_id'],
    'device_fingerprint_hash': request.data['device_fingerprint_hash'],
    'license_id': request.data['license_id'],
    'license_file_sha256': request.data['license_file_sha256'],
    'recipient_public_key': request.publicKey,
    'ephemeral_public_key': LicenseSerialization.encodeBase64Url(
      ephemeralPublic.bytes,
    ),
    'issued_at': _now.toIso8601String(),
    'valid_until': _end.toIso8601String(),
    'nonce': LicenseSerialization.encodeBase64Url(box.nonce),
    'ciphertext': LicenseSerialization.encodeBase64Url(box.cipherText),
    'mac': LicenseSerialization.encodeBase64Url(mac),
    ...overrides,
  };
  final bytes = utf8.encode(jsonEncode(payload));
  final signer = Ed25519();
  final keyPair = await signer.newKeyPairFromSeed(
    LicenseSerialization.decodeHex(
      '9d61b19deffd5a60ba844af492ec2cc44449c5697b326919703bac031cae7f60',
    ),
  );
  final signature = await signer.sign(
    RecipePackageVerifier.signingMessage(bytes),
    keyPair: keyPair,
  );
  return jsonEncode({
    'schema_version': 1,
    'type': RecipeProtocol.responseType,
    'algorithm': 'Ed25519',
    'key_id': LicenseKeyIds.development,
    'payload': LicenseSerialization.encodeBase64Url(bytes),
    'signature': LicenseSerialization.encodeBase64Url(signature.bytes),
  });
}

void main() {
  late SharedPreferences preferences;
  late _SecureStore secureStore;
  late RecipeKeyStore keys;
  late RecipeStateRepository repository;
  late AuthorizedRecipeService service;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    preferences = await SharedPreferences.getInstance();
    secureStore = _SecureStore();
    keys = RecipeKeyStore(secureStore);
    repository = RecipeStateRepository(preferences);
    service = AuthorizedRecipeService(
      repository,
      keys,
      RecipePackageVerifier(
        LicenseKeyRegistry.forEnvironment(allowDevelopmentKeys: true),
      ),
    );
  });

  Future<OfflineRecipeRequest> request({
    String raw = _raw,
    String expected = '0.563',
  }) async {
    final value = await service.createRequest(
      context: _context(),
      sample: RecipeSample(raw),
      expectedValue: expected,
      platform: 'windows',
      appVersion: '1.0.10+11',
      now: _now,
    );
    await service.rememberRequest(value);
    return value;
  }

  test('conserva la trama exacta y solo exporta la clave pública', () async {
    final value = await request();
    final decoded = OfflineRecipeRequest.decode(value.encode());
    expect(decoded.rawData, _raw);
    expect(decoded.expectedValue, '0.563');
    expect(decoded.data['license_document'], 'signed-license-fixture');
    final privateSeed = secureStore.values[RecipeKeyStore.storageKey]!;
    expect(value.encode().contains(privateSeed), isFalse);
    expect(
      utf8.encode(value.encode()).length,
      lessThan(RecipeProtocol.maxFileBytes),
    );
  });

  test(
    'exporta, descifra, activa y vuelve a validar después de reiniciar',
    () async {
      final value = await request();
      final response = await _issue(value);
      expect(response.contains(_pattern), isFalse);
      final recipe = await service.importResponse(
        response,
        context: _context(),
        now: _now,
      );
      expect(recipe.pattern, _pattern);
      expect(recipe.expectedValue, '0.563');
      expect(repository.load()['pending'], isNull);
      expect(
        preferences
            .getString(RecipeStateRepository.storageKey)!
            .contains(_pattern),
        isFalse,
      );
      final restarted = AuthorizedRecipeService(
        repository,
        RecipeKeyStore(secureStore),
        RecipePackageVerifier(
          LicenseKeyRegistry.forEnvironment(allowDevelopmentKeys: true),
        ),
      );
      final restored = await restarted.loadActive(
        context: _context(),
        now: _now.add(const Duration(days: 1)),
      );
      expect(restored?.pattern, _pattern);
      expect(
        ReadingParser.parse(
          '-000.200kg',
          pattern: restored!.pattern,
          expectedValue: restored.expectedValue,
        )?.numericValue,
        -0.2,
      );
      expect(
        (await service.importResponse(
          response,
          context: _context(),
          now: _now,
        )).pattern,
        _pattern,
      );
    },
  );

  test(
    'un regex libre o un archivo de licencia no son respuestas de receta',
    () async {
      await request();
      for (final invalid in [
        _pattern,
        jsonEncode({'regex_pattern': _pattern}),
        jsonEncode({'schema_version': 1, 'algorithm': 'Ed25519'}),
      ]) {
        await expectLater(
          service.importResponse(invalid, context: _context(), now: _now),
          throwsFormatException,
        );
      }
    },
  );

  test('rechaza contenido alterado y no sustituye la receta activa', () async {
    await service.saveOnline(
      context: _context(),
      sample: const RecipeSample(_raw),
      pattern: _pattern,
      expectedValue: '0.563',
    );
    final value = await request();
    final response = RecipeProtocol.object(await _issue(value));
    final payload = RecipeProtocol.object(
      utf8.decode(
        LicenseSerialization.decodeBase64Url(response['payload'] as String),
      ),
    );
    payload['recipe_id'] = 'ALTERED';
    response['payload'] = LicenseSerialization.encodeBase64Url(
      utf8.encode(jsonEncode(payload)),
    );
    await expectLater(
      service.importResponse(
        jsonEncode(response),
        context: _context(),
        now: _now,
      ),
      throwsFormatException,
    );
    expect(
      (await service.loadActive(context: _context(), now: _now))?.pattern,
      _pattern,
    );
    expect(repository.load()['pending'], isNotNull);
  });

  test('rechaza otro equipo, huella, licencia o archivo de licencia', () async {
    final response = await _issue(await request());
    for (final context in [
      _context(installation: 'INSTALL-OTHER'),
      _context(fingerprint: 'sha256:another'),
      _context(licenseId: 'LIC-OTHER'),
      _context(licenseHash: 'sha256:changed'),
    ]) {
      await expectLater(
        service.importResponse(response, context: context, now: _now),
        throwsFormatException,
      );
    }
  });

  test('otra solicitud invalida las respuestas anteriores', () async {
    final old = await _issue(await request());
    await request();
    await expectLater(
      service.importResponse(old, context: _context(), now: _now),
      throwsFormatException,
    );
  });

  test(
    'firma válida no acepta otra clave receptora, muestra, peso o MAC dañada',
    () async {
      final value = await request();
      for (final response in [
        await _issue(
          value,
          overrides: {
            'recipient_public_key': LicenseSerialization.encodeBase64Url(
              List.filled(32, 7),
            ),
          },
        ),
        await _issue(value, rawData: '+000.564kg'),
        await _issue(value, expectedValue: '0.564'),
        await _issue(value, corruptMac: true),
        await _issue(value, pattern: r'kg(\d+)'),
      ]) {
        await expectLater(
          service.importResponse(response, context: _context(), now: _now),
          throwsFormatException,
        );
      }
    },
  );

  test(
    'rechaza recetas vencidas, futuras o con vigencia mayor a la licencia',
    () async {
      final value = await request();
      for (final override in [
        {'valid_until': _now.toIso8601String()},
        {'issued_at': _now.add(const Duration(minutes: 6)).toIso8601String()},
        {'valid_until': _end.add(const Duration(days: 1)).toIso8601String()},
        {'valid_until': null},
      ]) {
        await expectLater(
          service.importResponse(
            await _issue(value, overrides: override),
            context: _context(),
            now: _now,
          ),
          throwsFormatException,
        );
      }
      await service.importResponse(
        await _issue(value),
        context: _context(),
        now: _now,
      );
      await expectLater(
        service.loadActive(context: _context(), now: _end),
        throwsFormatException,
      );
    },
  );

  test('la modalidad offline exige licencia importada y operativa', () async {
    for (final context in [
      _context(licenseId: null, licenseHash: null),
      _context(usable: false),
    ]) {
      await expectLater(
        service.createRequest(
          context: context,
          sample: const RecipeSample(_raw),
          expectedValue: '0.563',
          platform: 'windows',
          appVersion: '1.0.10',
        ),
        throwsFormatException,
      );
    }
    final response = await _issue(await request());
    await expectLater(
      service.importResponse(
        response,
        context: _context(usable: false),
        now: _now,
      ),
      throwsFormatException,
    );
    expect(
      await service.loadActive(context: _context(usable: false), now: _now),
      isNull,
    );
  });

  test('una respuesta no se importa sin solicitud pendiente', () async {
    final response = await _issue(await request());
    await service.clear();
    await expectLater(
      service.importResponse(response, context: _context(), now: _now),
      throwsFormatException,
    );
  });

  test(
    'producción rechaza firmas de desarrollo y claves desconocidas',
    () async {
      final value = await request();
      final document = await _issue(value);
      final production = RecipePackageVerifier(
        LicenseKeyRegistry.forEnvironment(allowDevelopmentKeys: false),
      );
      await expectLater(
        production.verify(
          document,
          context: _context(),
          recipientKeyPair: await keys.keyPair(),
          now: _now,
        ),
        throwsFormatException,
      );
      final envelope = RecipeProtocol.object(document)..['key_id'] = 'unknown';
      await expectLater(
        service.importResponse(
          jsonEncode(envelope),
          context: _context(),
          now: _now,
        ),
        throwsFormatException,
      );
    },
  );

  test(
    'una receta online se conserva cifrada y ligada a su licencia',
    () async {
      await service.saveOnline(
        context: _context(),
        sample: const RecipeSample(_raw),
        pattern: _pattern,
        expectedValue: '0.563',
      );
      expect(
        (await service.loadActive(context: _context()))?.pattern,
        _pattern,
      );
      expect(
        preferences
            .getString(RecipeStateRepository.storageKey)!
            .contains(_pattern),
        isFalse,
      );
      await expectLater(
        service.loadActive(context: _context(licenseHash: 'sha256:new')),
        throwsFormatException,
      );
      final state = repository.load();
      (state['active'] as Map<String, dynamic>)['mac'] =
          LicenseSerialization.encodeBase64Url(List.filled(16, 0));
      await repository.save(state);
      await expectLater(
        service.loadActive(context: _context()),
        throwsFormatException,
      );
    },
  );

  test(
    'copiar preferencias no copia la clave y el regex antiguo no se ejecuta',
    () async {
      await preferences.setString(PreferenceKeys.recipe, _pattern);
      await preferences.setString(PreferenceKeys.expectedValue, '0.563');
      expect(await service.loadActive(context: _context()), isNull);
      await service.saveOnline(
        context: _context(),
        sample: const RecipeSample(_raw),
        pattern: _pattern,
        expectedValue: '0.563',
      );
      final other = AuthorizedRecipeService(
        repository,
        RecipeKeyStore(_SecureStore()),
        RecipePackageVerifier(
          LicenseKeyRegistry.forEnvironment(allowDevelopmentKeys: true),
        ),
      );
      await expectLater(
        other.loadActive(context: _context()),
        throwsFormatException,
      );
      await service.clear();
      expect(await service.loadActive(context: _context()), isNull);
      expect(secureStore.values.containsKey(RecipeKeyStore.storageKey), isTrue);
    },
  );

  test('conserva la muestra negativa y su referencia de tara', () async {
    const raw = '\x020001 -B 0,20T 0,00N 0,20\x03\r\n';
    const pattern = r'(?<sign>[+-]?)B[ \t]*(?<weight>[0-9]+,[0-9]{2})T';
    final value = await request(raw: raw, expected: '-0.20');
    final recipe = await service.importResponse(
      await _issue(value, pattern: pattern),
      context: _context(),
      now: _now,
    );
    expect(recipe.expectedValue, '-0.20');
    expect(
      ReadingParser.parse(
        raw,
        pattern: recipe.pattern,
        expectedValue: recipe.expectedValue,
      )?.numericValue,
      -0.2,
    );
  });
}
