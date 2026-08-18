import 'dart:convert';

import 'package:cryptography/cryptography.dart';
import 'package:flutter/services.dart';

class DeviceFingerprint {
  const DeviceFingerprint();

  static const _channel = MethodChannel('bitgenial/device_fingerprint');
  static const _namespace = 'bitgenial-device-v1|';

  Future<String> readHash() async {
    final systemId = await _channel.invokeMethod<String>('readSystemId');
    if (systemId == null || systemId.trim().isEmpty) {
      throw StateError('No se pudo identificar el dispositivo.');
    }
    return hashSystemId(systemId);
  }

  static Future<String> hashSystemId(String systemId) async {
    final digest = await Sha256().hash(
      utf8.encode('$_namespace${systemId.trim().toUpperCase()}'),
    );
    final hex = digest.bytes
        .map((byte) => byte.toRadixString(16).padLeft(2, '0'))
        .join();
    return 'sha256:$hex';
  }
}
