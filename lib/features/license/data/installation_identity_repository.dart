import 'package:shared_preferences/shared_preferences.dart';

import '../domain/license_identifier_generator.dart';

abstract interface class InstallationValueStore {
  Future<String?> read(String key);
  Future<void> write(String key, String value);
}

class SharedPreferencesValueStore implements InstallationValueStore {
  const SharedPreferencesValueStore(this._preferences);

  final SharedPreferences _preferences;

  @override
  Future<String?> read(String key) async => _preferences.getString(key);

  @override
  Future<void> write(String key, String value) async {
    await _preferences.setString(key, value);
  }
}

class InstallationIdentityRepository {
  InstallationIdentityRepository(
    this._store, {
    LicenseIdentifierGenerator? identifierGenerator,
  }) : _identifierGenerator =
           identifierGenerator ?? LicenseIdentifierGenerator();

  static const _storageKey = 'pondera_installation_id';

  static Future<InstallationIdentityRepository> create() async {
    final preferences = await SharedPreferences.getInstance();
    return InstallationIdentityRepository(
      SharedPreferencesValueStore(preferences),
    );
  }

  final InstallationValueStore _store;
  final LicenseIdentifierGenerator _identifierGenerator;

  Future<String> getOrCreate() async {
    final storedValue = (await _store.read(_storageKey))?.trim();
    if (storedValue != null && storedValue.isNotEmpty) {
      return storedValue;
    }

    final installationId = _identifierGenerator.createInstallationId();
    await _store.write(_storageKey, installationId);
    return installationId;
  }
}
