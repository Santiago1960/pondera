import 'package:cryptography/cryptography.dart';
import 'package:flutter/foundation.dart';

import '../domain/license_key_ids.dart';
import '../domain/license_serialization.dart';

class LicenseKeyRegistry {
  const LicenseKeyRegistry(this._keys);

  final Map<String, SimplePublicKey> _keys;

  SimplePublicKey? find(String keyId) => _keys[keyId];

  factory LicenseKeyRegistry.forCurrentBuild() {
    return LicenseKeyRegistry.forEnvironment(allowDevelopmentKeys: kDebugMode);
  }

  factory LicenseKeyRegistry.forEnvironment({
    required bool allowDevelopmentKeys,
  }) {
    return LicenseKeyRegistry({
      LicenseKeyIds.production2026_01: SimplePublicKey(
        LicenseSerialization.decodeBase64Url(
          'WJLgFwl9soxXNqz_LognhbUPIeIl6PkJMrQ8BjuY3Xg',
        ),
        type: KeyPairType.ed25519,
      ),
      if (allowDevelopmentKeys)
        LicenseKeyIds.development: SimplePublicKey(
          LicenseSerialization.decodeHex(
            'd75a980182b10ab7d54bfed3c964073a0ee172f3daa62325af021a68f707511a',
          ),
          type: KeyPairType.ed25519,
        ),
    });
  }
}
