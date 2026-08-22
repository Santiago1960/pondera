import 'dart:convert';

import 'package:cryptography/cryptography.dart';
import 'package:pondera/features/license/domain/signed_license.dart';

Future<Map<String, Object?>> buildLicenseRegistrationDocument(
  SignedLicense license, {
  String? replacesLicenseId,
}) async {
  final normalizedReplacement = replacesLicenseId?.trim().toUpperCase();
  if (normalizedReplacement != null &&
      !RegExp('^LIC-$_uuidV4\$').hasMatch(normalizedReplacement)) {
    throw ArgumentError('replacesLicenseId no tiene un identificador válido.');
  }
  final encodedLicense = license.encode();
  final digest = await Sha256().hash(utf8.encode(encodedLicense));
  final hash = digest.bytes
      .map((byte) => byte.toRadixString(16).padLeft(2, '0'))
      .join();
  return {
    'schema_version': 1,
    'license_file': encodedLicense,
    'license_file_sha256': 'sha256:$hash',
    'replaces_license_id': normalizedReplacement,
  };
}

const _uuidV4 =
    r'[0-9A-F]{8}-[0-9A-F]{4}-4[0-9A-F]{3}-[89AB][0-9A-F]{3}-[0-9A-F]{12}';
