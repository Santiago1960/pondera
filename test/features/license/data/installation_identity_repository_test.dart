import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:pondera/features/license/data/installation_identity_repository.dart';
import 'package:pondera/features/license/domain/license_identifier_generator.dart';

void main() {
  test(
    'migra la identidad anterior y luego elimina la copia insegura',
    () async {
      final secureStore = _MemoryStore();
      final legacyStore = _MemoryLegacyStore(
        'pondera_installation_id',
        'INSTALL-LEGACY',
      );
      final repository = InstallationIdentityRepository(
        secureStore,
        legacyStore: legacyStore,
      );

      final installationId = await repository.getOrCreate();

      expect(installationId, 'INSTALL-LEGACY');
      expect(
        await secureStore.read('pondera_installation_id'),
        'INSTALL-LEGACY',
      );
      expect(await legacyStore.read('pondera_installation_id'), isNull);
      expect(legacyStore.deleteCount, 1);
    },
  );

  test(
    'prioriza la identidad segura y no modifica la copia anterior',
    () async {
      final secureStore = _MemoryStore(
        'pondera_installation_id',
        'INSTALL-SECURE',
      );
      final legacyStore = _MemoryLegacyStore(
        'pondera_installation_id',
        'INSTALL-LEGACY',
      );
      final repository = InstallationIdentityRepository(
        secureStore,
        legacyStore: legacyStore,
      );

      expect(await repository.getOrCreate(), 'INSTALL-SECURE');
      expect(legacyStore.deleteCount, 0);
    },
  );

  test(
    'no elimina la identidad anterior si falla la escritura segura',
    () async {
      final secureStore = _MemoryStore()..discardWrites = true;
      final legacyStore = _MemoryLegacyStore(
        'pondera_installation_id',
        'INSTALL-LEGACY',
      );
      final repository = InstallationIdentityRepository(
        secureStore,
        legacyStore: legacyStore,
      );

      await expectLater(repository.getOrCreate(), throwsStateError);
      expect(
        await legacyStore.read('pondera_installation_id'),
        'INSTALL-LEGACY',
      );
      expect(legacyStore.deleteCount, 0);
    },
  );

  test(
    'crea una identidad nueva únicamente en almacenamiento seguro',
    () async {
      final secureStore = _MemoryStore();
      final legacyStore = _MemoryLegacyStore();
      final repository = InstallationIdentityRepository(
        secureStore,
        legacyStore: legacyStore,
        identifierGenerator: LicenseIdentifierGenerator(random: Random(7)),
      );

      final installationId = await repository.getOrCreate();

      expect(installationId, startsWith('INSTALL-'));
      expect(await legacyStore.read('pondera_installation_id'), isNull);
    },
  );
}

class _MemoryStore implements InstallationValueStore {
  _MemoryStore([String? key, String? value]) {
    if (key != null && value != null) {
      _values[key] = value;
    }
  }

  final Map<String, String> _values = {};
  bool discardWrites = false;

  @override
  Future<String?> read(String key) async => _values[key];

  @override
  Future<void> write(String key, String value) async {
    if (!discardWrites) {
      _values[key] = value;
    }
  }
}

class _MemoryLegacyStore extends _MemoryStore
    implements LegacyInstallationValueStore {
  _MemoryLegacyStore([super.key, super.value]);

  int deleteCount = 0;

  @override
  Future<void> delete(String key) async {
    deleteCount++;
    _values.remove(key);
  }
}
