import 'dart:convert';
import 'dart:io';

import 'package:cryptography/cryptography.dart';

class SigningKeyGenerator {
  SigningKeyGenerator({Ed25519? algorithm})
    : _algorithm = algorithm ?? Ed25519();

  final Ed25519 _algorithm;

  Future<void> generate({
    required String keyId,
    required File privateFile,
    required File publicFile,
  }) async {
    if (await privateFile.exists() || await publicFile.exists()) {
      throw const FileSystemException(
        'La generación fue cancelada porque uno de los archivos ya existe.',
      );
    }

    final keyPair = await _algorithm.newKeyPair();
    final seedBytes = await keyPair.extractPrivateKeyBytes();
    final publicKey = await keyPair.extractPublicKey();
    if (seedBytes.length != 32 || publicKey.bytes.length != 32) {
      throw StateError('Ed25519 devolvió una clave de tamaño inesperado.');
    }

    await privateFile.writeAsString(
      _encodeKey(keyId: keyId, field: 'private_seed', bytes: seedBytes),
      flush: true,
    );
    await _restrictPrivateFilePermissions(privateFile.path);
    await publicFile.writeAsString(
      _encodeKey(keyId: keyId, field: 'public_key', bytes: publicKey.bytes),
      flush: true,
    );
  }
}

String _encodeKey({
  required String keyId,
  required String field,
  required List<int> bytes,
}) {
  return jsonEncode({
    'schema_version': 1,
    'algorithm': 'Ed25519',
    'key_id': keyId,
    field: base64Url.encode(bytes).replaceAll('=', ''),
  });
}

Future<void> _restrictPrivateFilePermissions(String path) async {
  if (!Platform.isMacOS && !Platform.isLinux) {
    return;
  }
  final result = await Process.run('chmod', ['600', path]);
  if (result.exitCode != 0) {
    throw FileSystemException(
      'No se pudieron restringir los permisos de la clave privada.',
      path,
    );
  }
}
