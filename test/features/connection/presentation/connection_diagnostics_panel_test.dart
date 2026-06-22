import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pondera/app/app_theme.dart';
import 'package:pondera/features/connection/presentation/connection_diagnostics_panel.dart';

void main() {
  testWidgets('muestra el diagnóstico del enlace solo al expandirse', (
    tester,
  ) async {
    const diagnostics = 'Polling enviados: 12 | Bytes recibidos: 48';

    await tester.pumpWidget(
      MaterialApp(
        theme: buildPonderaTheme(Brightness.light),
        home: const Scaffold(
          body: ConnectionDiagnosticsPanel(networkDiagnostics: diagnostics),
        ),
      ),
    );

    expect(find.text('Diagnóstico avanzado'), findsOneWidget);
    expect(find.text(diagnostics), findsNothing);
    expect(find.text('Integración n8n'), findsNothing);

    await tester.tap(find.text('Diagnóstico avanzado'));
    await tester.pumpAndSettle();

    expect(find.text(diagnostics), findsOneWidget);
    expect(find.text('Integración n8n'), findsNothing);
  });
}
