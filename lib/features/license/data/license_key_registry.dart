import 'package:cryptography/cryptography.dart';
import 'package:flutter/foundation.dart';

import '../domain/license_key_ids.dart';

class LicenseKeyRegistry {
  const LicenseKeyRegistry(this._keys);

  final Map<String, SimplePublicKey> _keys;

  SimplePublicKey? find(String keyId) => _keys[keyId];

  factory LicenseKeyRegistry.forCurrentBuild() {
    return LicenseKeyRegistry({
      if (kDebugMode)
        LicenseKeyIds.development: SimplePublicKey(
          _decodeHex(
            'd75a980182b10ab7d54bfed3c964073a0ee172f3daa62325af021a68f707511a',
          ),
          type: KeyPairType.ed25519,
        ),
      // TODO(licensing): agregar aquí la clave pública real de producción.
    });
  }
}

List<int> _decodeHex(String value) {
  return List<int>.generate(
    value.length ~/ 2,
    (index) => int.parse(value.substring(index * 2, index * 2 + 2), radix: 16),
  );
}
