import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:pondera/features/license/application/activation_request_service.dart';
import 'package:pondera/features/license/data/activation_request_exporter.dart';
import 'package:pondera/features/license/data/installation_identity_repository.dart';
import 'package:pondera/features/license/domain/license_identifier_generator.dart';

void main() {
  test('crea una identidad estable y la reutiliza', () async {
    final store = _MemorySecureStore();
    final repository = InstallationIdentityRepository(
      store,
      identifierGenerator: LicenseIdentifierGenerator(random: Random(1)),
    );

    final first = await repository.getOrCreate();
    final second = await repository.getOrCreate();

    expect(
      first,
      matches(
        RegExp(
          r'^INSTALL-[0-9A-F]{8}-[0-9A-F]{4}-4[0-9A-F]{3}-[89AB][0-9A-F]{3}-[0-9A-F]{12}$',
        ),
      ),
    );
    expect(second, first);
    expect(store.writeCount, 1);
  });

  test('crea la solicitud con los datos humanos y técnicos', () async {
    final store = _MemorySecureStore();
    final repository = InstallationIdentityRepository(
      store,
      identifierGenerator: LicenseIdentifierGenerator(random: Random(2)),
    );
    final service = ActivationRequestService(
      repository,
      identifierGenerator: LicenseIdentifierGenerator(random: Random(3)),
    );

    final request = await service.create(
      platform: 'windows',
      appVersion: '1.0.0+10',
      deviceFingerprintHash: 'sha256:${'a' * 64}',
      customerName: ' SIGMA ALIMENTOS ',
      siteName: ' Planta de embutidos ',
      city: ' Cuenca ',
      deviceLabel: ' PC-Producción-01 ',
      assetTag: ' SIG-PC-042 ',
      now: DateTime.utc(2026, 6, 18),
    );

    expect(
      request.requestId,
      matches(
        RegExp(
          r'^REQ-[0-9A-F]{8}-[0-9A-F]{4}-4[0-9A-F]{3}-[89AB][0-9A-F]{3}-[0-9A-F]{12}$',
        ),
      ),
    );
    expect(request.installationId, startsWith('INSTALL-'));
    expect(request.product, 'pondera');
    expect(request.deviceFingerprintHash, 'sha256:${'a' * 64}');
    expect(request.customerName, 'SIGMA ALIMENTOS');
    expect(request.siteName, 'Planta de embutidos');
    expect(request.city, 'Cuenca');
    expect(request.deviceLabel, 'PC-Producción-01');
    expect(request.assetTag, 'SIG-PC-042');
    expect(request.createdAt, DateTime.utc(2026, 6, 18));
  });

  test('genera un nombre de archivo reconocible', () async {
    final service = ActivationRequestService(
      InstallationIdentityRepository(_MemorySecureStore()),
      identifierGenerator: LicenseIdentifierGenerator(random: Random(4)),
    );
    final request = await service.create(
      platform: 'macos',
      appVersion: '1.0.0',
      deviceFingerprintHash: 'sha256:${'b' * 64}',
      customerName: 'SIGMA ALIMENTOS',
      siteName: 'Planta de embutidos',
      city: 'Cuenca',
      deviceLabel: 'PC-Producción-01',
      now: DateTime.utc(2026, 6, 18),
    );

    final fileName = ActivationRequestExporter.suggestedFileName(request);

    expect(
      fileName,
      'SIGMA-ALIMENTOS-Cuenca-PC-Produccion-01-${request.requestId}.pondera-request',
    );
  });
}

class _MemorySecureStore implements InstallationValueStore {
  final Map<String, String> _values = {};
  int writeCount = 0;

  @override
  Future<String?> read(String key) async => _values[key];

  @override
  Future<void> write(String key, String value) async {
    writeCount++;
    _values[key] = value;
  }
}
