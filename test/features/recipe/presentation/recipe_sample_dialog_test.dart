import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pondera/features/recipe/domain/recipe_sample.dart';
import 'package:pondera/features/recipe/presentation/recipe_sample_dialog.dart';

void main() {
  testWidgets(
    'mantiene la muestra BR-15 y su peso aunque cambie la recepción',
    (tester) async {
      var currentRawData = '+000.563kg';
      String? submittedValue;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: FilledButton(
                onPressed: () async {
                  submittedValue = await showDialog<String>(
                    context: context,
                    builder: (_) => RecipeSampleDialog(
                      sample: RecipeSample(currentRawData),
                      initialExpectedValue: '0.561',
                    ),
                  );
                },
                child: const Text('Crear receta'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Crear receta'));
      await tester.pumpAndSettle();
      currentRawData = '+000.561kg';
      await tester.pump();

      expect(find.text('+000.563kg'), findsOneWidget);
      expect(find.widgetWithText(TextFormField, '0.563'), findsOneWidget);
      await tester.enterText(find.byType(TextFormField), '0.561');
      await tester.tap(find.text('Enviar'));
      await tester.pumpAndSettle();
      expect(find.text('El peso de esta muestra es 0.563.'), findsOneWidget);
      expect(submittedValue, isNull);

      await tester.enterText(find.byType(TextFormField), '0,563');
      await tester.tap(find.text('Enviar'));
      await tester.pumpAndSettle();
      expect(submittedValue, '0,563');
    },
  );

  testWidgets('permite seleccionar el peso de una trama con varios campos', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: RecipeSampleDialog(
          sample: RecipeSample('\x020001 -B 0,20T 0,00N 0,20\x03\r\n'),
          initialExpectedValue: '-0.20',
        ),
      ),
    );
    expect(find.text(r'\x020001 -B 0,20T 0,00N 0,20\x03\r\n'), findsOneWidget);
    expect(find.widgetWithText(TextFormField, '-0.20'), findsOneWidget);
    await tester.enterText(find.byType(TextFormField), '-');
    await tester.tap(find.text('Enviar'));
    await tester.pumpAndSettle();
    expect(
      find.text('Ingrese un valor válido, por ejemplo 0.130 o -0,130.'),
      findsOneWidget,
    );
  });
}
