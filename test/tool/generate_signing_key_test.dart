import 'dart:convert';
import 'dart:io';

import 'package:cryptography/cryptography.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pondera/features/license/domain/license_serialization.dart';

import '../../tool/src/license_signing_key.dart';
import '../../tool/src/signing_key_generator.dart';

void main() {
  test(
    'genera un par Ed25519 coherente sin exponer la clave privada',
    () async {
      final temporaryDirectory = await Directory.systemTemp.createTemp(
        'pondera-key-test-',
      );
      addTearDown(() => temporaryDirectory.delete(recursive: true));
      final privatePath =
          '${temporaryDirectory.path}/private.pondera-private-key';
      final publicPath = '${temporaryDirectory.path}/public.pondera-public-key';

      await SigningKeyGenerator().generate(
        keyId: 'pondera-prod-2026-01',
        privateFile: File(privatePath),
        publicFile: File(publicPath),
      );

      final signingKey = LicenseSigningKey.decode(
        await File(privatePath).readAsString(),
      );
      final publicJson = jsonDecode(await File(publicPath).readAsString());
      final keyPair = await Ed25519().newKeyPairFromSeed(signingKey.seedBytes);
      final derivedPublicKey = await keyPair.extractPublicKey();
      expect(publicJson['key_id'], 'pondera-prod-2026-01');
      expect(
        LicenseSerialization.decodeBase64Url(
          publicJson['public_key'] as String,
        ),
        derivedPublicKey.bytes,
      );
    },
  );

  test('no sobrescribe archivos de claves existentes', () async {
    final temporaryDirectory = await Directory.systemTemp.createTemp(
      'pondera-key-test-',
    );
    addTearDown(() => temporaryDirectory.delete(recursive: true));
    final privateFile = File(
      '${temporaryDirectory.path}/private.pondera-private-key',
    );
    await privateFile.writeAsString('existente');

    final publicFile = File(
      '${temporaryDirectory.path}/public.pondera-public-key',
    );

    expect(
      () => SigningKeyGenerator().generate(
        keyId: 'pondera-prod-2026-01',
        privateFile: privateFile,
        publicFile: publicFile,
      ),
      throwsA(isA<FileSystemException>()),
    );
    expect(await privateFile.readAsString(), 'existente');
    expect(await publicFile.exists(), isFalse);
  });
}
