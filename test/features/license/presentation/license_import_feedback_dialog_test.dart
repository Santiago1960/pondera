import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pondera/app/app_theme.dart';
import 'package:pondera/features/license/domain/license_payload.dart';
import 'package:pondera/features/license/presentation/license_import_feedback_dialog.dart';

void main() {
  testWidgets('confirma una licencia instalada con sus datos principales', (
    tester,
  ) async {
    await tester.pumpWidget(_TestApp(installed: true, payload: _payload));

    await tester.tap(find.text('Importar'));
    await tester.pumpAndSettle();

    expect(find.text('Licencia instalada correctamente'), findsOneWidget);
    expect(find.text('Licencia activa hasta 30/09/2027.'), findsOneWidget);
    expect(find.text('Cliente Demo'), findsOneWidget);
    expect(find.text('Planta Norte · Quito'), findsOneWidget);
    expect(find.text('Balanza 01'), findsOneWidget);
    expect(find.text('LICENSE-001'), findsOneWidget);

    await tester.tap(find.text('Entendido'));
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsNothing);
  });

  testWidgets('explica el rechazo y la conservación de la licencia anterior', (
    tester,
  ) async {
    await tester.pumpWidget(
      const _TestApp(installed: false, previousLicensePreserved: true),
    );

    await tester.tap(find.text('Importar'));
    await tester.pumpAndSettle();

    expect(find.text('No se instaló la licencia'), findsOneWidget);
    expect(find.text('El archivo corresponde a otro equipo.'), findsOneWidget);
    expect(
      find.text('La licencia que ya estaba activa no fue modificada.'),
      findsOneWidget,
    );
    expect(find.text('Licencia instalada correctamente'), findsNothing);
  });
}

class _TestApp extends StatelessWidget {
  const _TestApp({
    required this.installed,
    this.payload,
    this.previousLicensePreserved = false,
  });

  final bool installed;
  final LicensePayload? payload;
  final bool previousLicensePreserved;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      theme: buildPonderaTheme(Brightness.light),
      home: Builder(
        builder: (context) {
          return Scaffold(
            body: Center(
              child: FilledButton(
                onPressed: () => showLicenseImportFeedbackDialog(
                  context,
                  installed: installed,
                  message: installed
                      ? 'Licencia activa hasta 30/09/2027.'
                      : 'El archivo corresponde a otro equipo.',
                  payload: payload,
                  previousLicensePreserved: previousLicensePreserved,
                ),
                child: const Text('Importar'),
              ),
            ),
          );
        },
      ),
    );
  }
}

final _payload = LicensePayload(
  licenseId: 'LICENSE-001',
  requestId: 'REQUEST-001',
  product: 'pondera',
  installationId: 'INSTALL-001',
  customerId: 'CUSTOMER-001',
  customerName: 'Cliente Demo',
  siteId: 'SITE-001',
  siteName: 'Planta Norte',
  city: 'Quito',
  deviceLabel: 'Balanza 01',
  licenseType: LicenseType.subscription,
  issuedAt: DateTime.utc(2026, 9, 1),
  notBefore: DateTime.utc(2026, 9, 1),
  expiresAt: DateTime.utc(2027, 9, 30),
  features: const ['tcp', 'serial', 'n8n'],
);
