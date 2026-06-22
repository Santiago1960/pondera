import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pondera/app/app_theme.dart';
import 'package:pondera/features/recipe/presentation/recipe_actions_panel.dart';

void main() {
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
            onClearRecipe: () {},
          ),
        ),
      ),
    );

    expect(find.text('Procesando con n8n…'), findsOneWidget);
    await tester.tap(find.text('Receta de lectura'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.byType(LinearProgressIndicator), findsOneWidget);
    expect(find.text('Procesando…'), findsOneWidget);
    await tester.tap(find.text('Procesando…'));
    expect(sendCount, 0);
  });
}
