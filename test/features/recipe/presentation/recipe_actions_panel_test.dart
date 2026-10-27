import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pondera/app/app_theme.dart';
import 'package:pondera/features/recipe/presentation/recipe_actions_panel.dart';

void main() {
  testWidgets('la demo no habilita archivos offline ni muestra el regex', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: RecipeActionsPanel(
            savedRegex: r'(\d+)',
            isEnabled: true,
            isProcessing: false,
            onSendToN8n: () {},
            onExportOfflineRequest: () {},
            onImportAuthorizedRecipe: () {},
            onClearRecipe: () {},
          ),
        ),
      ),
    );
    await tester.tap(find.text('Receta de lectura'));
    await tester.pumpAndSettle();
    expect(find.text(r'(\d+)'), findsNothing);
    expect(find.text('Ingresar receta manual'), findsNothing);
    for (final label in [
      'Solicitar receta sin internet',
      'Cargar receta autorizada',
    ]) {
      expect(
        tester
            .widget<OutlinedButton>(find.widgetWithText(OutlinedButton, label))
            .onPressed,
        isNull,
      );
    }
  });

  testWidgets(
    'cargar respuesta usa una acción distinta de solicitar o conectar',
    (tester) async {
      var imports = 0;
      var exports = 0;
      var online = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: RecipeActionsPanel(
              savedRegex: '',
              isEnabled: true,
              isProcessing: false,
              canUseOffline: true,
              onSendToN8n: () => online++,
              onExportOfflineRequest: () => exports++,
              onImportAuthorizedRecipe: () => imports++,
              onClearRecipe: () {},
            ),
          ),
        ),
      );
      await tester.tap(find.text('Receta de lectura'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Cargar receta autorizada'));
      await tester.tap(find.text('Cargar receta autorizada'));
      expect(imports, 1);
      expect(exports, 0);
      expect(online, 0);
    },
  );

  testWidgets('abre el ingreso manual sin solicitar una receta por n8n', (
    tester,
  ) async {
    var manualCount = 0;
    var sendCount = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: RecipeActionsPanel(
            savedRegex: '',
            isEnabled: true,
            isProcessing: false,
            onSendToN8n: () => sendCount++,
            onExportOfflineRequest: () => manualCount++,
            onImportAuthorizedRecipe: () {},
            canUseOffline: true,
            onClearRecipe: () {},
          ),
        ),
      ),
    );
    await tester.tap(find.text('Receta de lectura'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Solicitar receta sin internet'));
    await tester.tap(find.text('Solicitar receta sin internet'));
    expect(manualCount, 1);
    expect(sendCount, 0);
  });

  for (final (enabled, processing) in [(false, false), (true, true)]) {
    testWidgets(
      'deshabilita ingreso manual: enabled=$enabled, processing=$processing',
      (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: RecipeActionsPanel(
                savedRegex: '',
                isEnabled: enabled,
                isProcessing: processing,
                onSendToN8n: () {},
                onExportOfflineRequest: () {},
                onImportAuthorizedRecipe: () {},
                canUseOffline: true,
                onClearRecipe: () {},
              ),
            ),
          ),
        );
        await tester.tap(find.text('Receta de lectura'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));
        expect(
          tester
              .widget<OutlinedButton>(
                find.widgetWithText(
                  OutlinedButton,
                  'Solicitar receta sin internet',
                ),
              )
              .onPressed,
          isNull,
        );
      },
    );
  }

  testWidgets('confirma antes de eliminar una receta activa', (tester) async {
    var clearCount = 0;
    await tester.pumpWidget(
      MaterialApp(
        theme: buildPonderaTheme(Brightness.light),
        home: Scaffold(
          body: RecipeActionsPanel(
            savedRegex: r'\d+[.,]\d+',
            isEnabled: true,
            isProcessing: false,
            onSendToN8n: () {},
            onExportOfflineRequest: () {},
            onImportAuthorizedRecipe: () {},
            canUseOffline: true,
            onClearRecipe: () => clearCount++,
          ),
        ),
      ),
    );

    await tester.tap(find.text('Receta de lectura'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Eliminar receta'));
    await tester.tap(find.text('Eliminar receta'));
    await tester.pumpAndSettle();

    expect(find.byType(AlertDialog), findsOneWidget);
    expect(clearCount, 0);

    await tester.tap(find.text('Cancelar'));
    await tester.pumpAndSettle();
    expect(clearCount, 0);

    await tester.tap(find.text('Eliminar receta'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Eliminar'));
    await tester.pumpAndSettle();

    expect(clearCount, 1);
  });

  testWidgets('muestra progreso y evita reenvíos mientras espera n8n', (
    tester,
  ) async {
    var sendCount = 0;
    await tester.pumpWidget(
      MaterialApp(
        theme: buildPonderaTheme(Brightness.light),
        home: Scaffold(
          body: RecipeActionsPanel(
            savedRegex: '',
            isEnabled: true,
            isProcessing: true,
            onSendToN8n: () => sendCount++,
            onExportOfflineRequest: () {},
            onImportAuthorizedRecipe: () {},
            canUseOffline: true,
            onClearRecipe: () {},
          ),
        ),
      ),
    );

    expect(find.text('Analizando la muestra…'), findsOneWidget);
    await tester.tap(find.text('Receta de lectura'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.byType(LinearProgressIndicator), findsOneWidget);
    expect(find.text('Procesando…'), findsOneWidget);
    await tester.tap(find.text('Procesando…'));
    expect(sendCount, 0);
  });
}
