import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pondera/app/app_theme.dart';
import 'package:pondera/shared/widgets/settings_expansion_card.dart';

void main() {
  testWidgets('inicia cerrada y muestra el contenido al expandirse', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: buildPonderaTheme(Brightness.light),
        home: const Scaffold(
          body: SettingsExpansionCard(
            title: 'Configuración de prueba',
            summary: 'Resumen visible',
            icon: Icons.tune,
            child: Text('Contenido interno'),
          ),
        ),
      ),
    );

    expect(find.text('Resumen visible'), findsOneWidget);
    expect(find.text('Contenido interno'), findsNothing);

    await tester.tap(find.text('Configuración de prueba'));
    await tester.pumpAndSettle();

    expect(find.text('Contenido interno'), findsOneWidget);
  });

  testWidgets('permite reemplazar el contenido expandido por campos de texto', (
    tester,
  ) async {
    var showTextFields = false;

    await tester.pumpWidget(
      MaterialApp(
        theme: buildPonderaTheme(Brightness.light),
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, setState) {
              return SettingsExpansionCard(
                title: 'Enlace con la balanza',
                summary: showTextFields ? 'Ethernet' : 'RS-232',
                icon: Icons.lan_outlined,
                child: showTextFields
                    ? const Row(
                        children: [
                          Expanded(child: TextField()),
                          Expanded(child: TextField()),
                        ],
                      )
                    : FilledButton(
                        onPressed: () {
                          setState(() => showTextFields = true);
                        },
                        child: const Text('Cambiar a Ethernet'),
                      ),
              );
            },
          ),
        ),
      ),
    );

    await tester.tap(find.text('Enlace con la balanza'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cambiar a Ethernet'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.byType(TextField), findsNWidgets(2));
  });
}
