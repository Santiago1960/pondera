import 'dart:io';

import 'package:cryptography/cryptography.dart';
import 'package:pondera/features/license/domain/license_activation_request.dart';
import 'package:pondera/features/license/domain/license_key_ids.dart';
import 'package:pondera/features/license/domain/license_payload.dart';
import 'package:pondera/features/license/domain/signed_license.dart';

// Clave privada pública del vector de prueba RFC 8032.
// Es insegura y se acepta únicamente en builds debug de Pondera.
const _developmentSeedHex =
    '9d61b19deffd5a60ba844af492ec2cc44449c5697b326919703bac031cae7f60';

Future<void> main(List<String> arguments) async {
  if (arguments.isEmpty || arguments.length > 2) {
    stderr.writeln(
      'Uso: dart run tool/create_dev_license.dart '
      '<solicitud.pondera-request> [salida.pondera-license]',
    );
    exitCode = 64;
    return;
  }

  final requestFile = File(arguments.first);
  final request = LicenseActivationRequest.decode(
    await requestFile.readAsString(),
  );
  final now = DateTime.now().toUtc();
  final expiresAt = now.add(const Duration(days: 30));
  final payload = LicensePayload(
    licenseId: 'DEV-${request.requestId}',
    requestId: request.requestId,
    product: request.product,
    installationId: request.installationId,
    customerId: 'DEV-CUSTOMER',
    customerName: request.customerName,
    siteId: 'DEV-SITE',
    siteName: request.siteName,
    city: request.city,
    deviceLabel: request.deviceLabel,
    assetTag: request.assetTag,
    licenseType: LicenseType.subscription,
    issuedAt: now,
    notBefore: now.subtract(const Duration(minutes: 5)),
    expiresAt: expiresAt,
    graceUntil: expiresAt.add(const Duration(days: 15)),
    features: const ['tcp', 'serial', 'n8n', 'keyboard_output'],
  );

  final algorithm = Ed25519();
  final keyPair = await algorithm.newKeyPairFromSeed(
    _decodeHex(_developmentSeedHex),
  );
  final payloadBytes = payload.encode();
  final signature = await algorithm.sign(payloadBytes, keyPair: keyPair);
  final signedLicense = SignedLicense.fromBytes(
    keyId: LicenseKeyIds.development,
    payloadBytes: payloadBytes,
    signatureBytes: signature.bytes,
  );

  final outputPath = arguments.length == 2
      ? arguments[1]
      : _defaultOutputPath(requestFile.path);
  await File(outputPath).writeAsString(signedLicense.encode(), flush: true);
  stdout.writeln('Licencia de desarrollo creada: $outputPath');
}

String _defaultOutputPath(String requestPath) {
  const extension = '.pondera-request';
  if (requestPath.endsWith(extension)) {
    return '${requestPath.substring(0, requestPath.length - extension.length)}.pondera-license';
  }
  return '$requestPath.pondera-license';
}

List<int> _decodeHex(String value) {
  return List<int>.generate(
    value.length ~/ 2,
    (index) => int.parse(value.substring(index * 2, index * 2 + 2), radix: 16),
  );
}
