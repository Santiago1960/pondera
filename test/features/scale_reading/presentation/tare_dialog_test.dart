import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pondera/features/scale_reading/domain/tare_weight.dart';
import 'package:pondera/features/scale_reading/presentation/tare_dialog.dart';
import 'package:pondera/features/scale_reading/presentation/current_weight_panel.dart';

void main() {
  testWidgets('valida tara y aplica coma decimal solamente al confirmar', (
    tester,
  ) async {
    TareWeight? result;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () async {
                result = await showTareDialog(context, const TareWeight());
              },
              child: const Text('Abrir'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Abrir'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '-1');
    await tester.tap(find.text('Aplicar'));
    await tester.pumpAndSettle();
    expect(result, isNull);
    expect(
      find.text('Ingrese un peso válido, mayor o igual a cero.'),
      findsOneWidget,
    );
    await tester.enterText(find.byType(TextField), '1,50');
    await tester.tap(find.text('Aplicar'));
    await tester.pumpAndSettle();
    expect(result!.value, 1.5);
  });
  testWidgets('peso neto y desglose caben en ventana pequeña', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 320,
            child: CurrentWeightPanel(
              weightDisplay: '118,50',
              grossDisplay: '120,00',
              unitDisplay: 'kg',
              tareDisplay: '1.5 kg',
              tareActive: true,
              onChangeTare: () {},
              onClearTare: () {},
            ),
          ),
        ),
      ),
    );
    expect(find.text('118,50 kg'), findsOneWidget);
    expect(find.text('Bruto: 120,00 kg · Tara: 1.5 kg'), findsOneWidget);
    expect(find.text('Tara activa'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
