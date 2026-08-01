import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pondera/features/scale_reading/domain/weight_capture_controller.dart';
import 'package:pondera/features/scale_reading/domain/weight_unit.dart';
import 'package:pondera/features/scale_reading/presentation/weight_capture_settings_panel.dart';

void main() {
  testWidgets('muestra modos futuros y permite configurar el rango de Print', (
    tester,
  ) async {
    final minimumController = TextEditingController();
    final maximumController = TextEditingController();
    final stableController = TextEditingController(text: '1000');
    addTearDown(minimumController.dispose);
    addTearDown(maximumController.dispose);
    addTearDown(stableController.dispose);
    var rangeEnabled = false;
    var saveCount = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, setState) {
              return SingleChildScrollView(
                child: WeightCaptureSettingsPanel(
                  selectedMode: WeightCaptureMode.indicatorPrint,
                  rangeEnabled: rangeEnabled,
                  rangeUnit: WeightUnit.kilogram,
                  minimumController: minimumController,
                  maximumController: maximumController,
                  stableMillisecondsController: stableController,
                  onModeChanged: (_) {},
                  onRangeEnabledChanged: (value) {
                    setState(() => rangeEnabled = value);
                  },
                  onRangeUnitChanged: (_) {},
                  onSave: () => saveCount++,
                ),
              );
            },
          ),
        ),
      ),
    );

    await tester.tap(find.text('Captura del peso'));
    await tester.pumpAndSettle();

    expect(find.text('Print del indicador'), findsOneWidget);
    expect(find.text('Tiempo estable (ms)'), findsOneWidget);
    expect(find.byKey(const Key('capture-minimum-field')), findsNothing);

    await tester.tap(find.byType(DropdownButtonFormField<WeightCaptureMode>));
    await tester.pumpAndSettle();
    expect(find.text('Tecla F12 · Próxima etapa'), findsOneWidget);
    expect(
      find.text('Automático al estabilizarse · Próxima etapa'),
      findsOneWidget,
    );
    await tester.tapAt(const Offset(10, 10));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('capture-range-toggle')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('capture-minimum-field')), findsOneWidget);
    expect(find.byKey(const Key('capture-maximum-field')), findsOneWidget);
    expect(find.text('Unidad del rango'), findsOneWidget);

    await tester.tap(find.byKey(const Key('capture-save-button')));
    expect(saveCount, 1);
  });
}
