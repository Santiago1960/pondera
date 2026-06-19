import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../domain/license_identifier_generator.dart';

abstract interface class InstallationValueStore {
  Future<String?> read(String key);
  Future<void> write(String key, String value);
}

abstract interface class LegacyInstallationValueStore
    implements InstallationValueStore {
  Future<void> delete(String key);
}

class SecureInstallationValueStore implements InstallationValueStore {
  const SecureInstallationValueStore(this._storage);

  static const defaultStorage = FlutterSecureStorage(
    mOptions: MacOsOptions(
      accountName: 'com.caicedosantiago.pondera.installation',
      accessibility: KeychainAccessibility.unlocked_this_device,
      synchronizable: false,
      label: 'Identidad de instalación de Pondera',
      usesDataProtectionKeychain: true,
    ),
  );

  final FlutterSecureStorage _storage;

  @override
  Future<String?> read(String key) => _storage.read(key: key);

  @override
  Future<void> write(String key, String value) {
    return _storage.write(key: key, value: value);
  }
}

class SharedPreferencesValueStore implements LegacyInstallationValueStore {
  const SharedPreferencesValueStore(this._preferences);

  final SharedPreferences _preferences;

  @override
  Future<String?> read(String key) async => _preferences.getString(key);

  @override
  Future<void> write(String key, String value) async {
    await _preferences.setString(key, value);
  }

  @override
  Future<void> delete(String key) async {
    await _preferences.remove(key);
  }
}

class InstallationIdentityRepository {
  InstallationIdentityRepository(
    this._store, {
    LegacyInstallationValueStore? legacyStore,
    LicenseIdentifierGenerator? identifierGenerator,
  }) : _legacyStore = legacyStore,
       _identifierGenerator =
           identifierGenerator ?? LicenseIdentifierGenerator();

  static const _storageKey = 'pondera_installation_id';

  static Future<InstallationIdentityRepository> create() async {
    final preferences = await SharedPreferences.getInstance();
    return InstallationIdentityRepository(
      const SecureInstallationValueStore(
        SecureInstallationValueStore.defaultStorage,
      ),
      legacyStore: SharedPreferencesValueStore(preferences),
    );
  }

  final InstallationValueStore _store;
  final LegacyInstallationValueStore? _legacyStore;
  final LicenseIdentifierGenerator _identifierGenerator;

  Future<String> getOrCreate() async {
    final storedValue = (await _store.read(_storageKey))?.trim();
    if (storedValue != null && storedValue.isNotEmpty) {
      return storedValue;
    }

    final legacyValue = (await _legacyStore?.read(_storageKey))?.trim();
    if (legacyValue != null && legacyValue.isNotEmpty) {
      await _writeAndVerify(legacyValue);
      await _legacyStore?.delete(_storageKey);
      return legacyValue;
    }

    final installationId = _identifierGenerator.createInstallationId();
    await _writeAndVerify(installationId);
    return installationId;
  }

  Future<void> _writeAndVerify(String installationId) async {
    await _store.write(_storageKey, installationId);
    final persistedValue = (await _store.read(_storageKey))?.trim();
    if (persistedValue != installationId) {
      throw StateError(
        'No se pudo verificar la identidad en el almacenamiento seguro.',
      );
    }
  }
}
