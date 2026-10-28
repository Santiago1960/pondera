import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pondera/features/scale_reading/domain/reading_parser.dart';
import 'package:pondera/features/scale_reading/domain/weight_output_format.dart';
import 'package:pondera/features/scale_reading/domain/weight_unit.dart';
import 'package:pondera/features/scale_reading/presentation/weight_output_settings_panel.dart';

ReadingParseResult reading(String source) => ReadingParser.parse(
  '${source}kg',
  pattern: r'^([+-]?\d+(?:[.,]\d+)?)kg$',
  expectedValue: source.contains('.') ? '0,100' : '0.100',
)!;

void main() {
  testWidgets('espera datos sin inventar un peso', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: WeightOutputSettingsPanel(
            format: const WeightOutputFormat(),
            reading: null,
            inputUnit: WeightUnit.kilogram,
            outputUnit: WeightUnit.kilogram,
            onChanged: (_) {},
          ),
        ),
      ),
    );
    await tester.tap(find.text('Formato de salida'));
    await tester.pumpAndSettle();
    expect(
      find.text(
        'Esperando una lectura del indicador para mostrar la vista previa.',
      ),
      findsOneWidget,
    );
    expect(find.textContaining('0.508'), findsNothing);
    expect(find.textContaining('Se escribirá:'), findsNothing);
    expect(find.text('Como en la receta'), findsNothing);
  });

  for (final source in ['+001.238', '-001,238']) {
    testWidgets('la vista previa usa el separador recibido de $source', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: WeightOutputSettingsPanel(
              format: const WeightOutputFormat(decimalPlaces: 2),
              reading: reading(source),
              inputUnit: WeightUnit.kilogram,
              outputUnit: WeightUnit.kilogram,
              onChanged: (_) {},
            ),
          ),
        ),
      );
      await tester.tap(find.text('Formato de salida'));
      await tester.pumpAndSettle();
      expect(find.text('Peso recibido: $source kg'), findsOneWidget);
      expect(
        find.text('Se escribirá: ${source.contains('.') ? '1.24' : '-1,24'}'),
        findsOneWidget,
      );
    });
  }

  testWidgets('la vista previa incluye la conversión de unidades', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: WeightOutputSettingsPanel(
            format: const WeightOutputFormat(
              separator: WeightDecimalSeparator.comma,
              decimalPlaces: 2,
            ),
            reading: reading('+001.238'),
            inputUnit: WeightUnit.kilogram,
            outputUnit: WeightUnit.gram,
            onChanged: (_) {},
          ),
        ),
      ),
    );
    await tester.tap(find.text('Formato de salida'));
    await tester.pumpAndSettle();
    expect(find.text('Peso recibido: +001.238 kg'), findsOneWidget);
    expect(find.text('Se escribirá: 1238,00'), findsOneWidget);
    expect(find.text('Unidad de salida: g'), findsOneWidget);
  });

  for (final width in [360.0, 1000.0]) {
    testWidgets('actualiza el peso real y las opciones en ancho $width', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(Size(width, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      var format = const WeightOutputFormat();
      ReadingParseResult? currentReading = reading('+001.238');
      late StateSetter update;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: StatefulBuilder(
                builder: (context, setState) {
                  update = setState;
                  return WeightOutputSettingsPanel(
                    format: format,
                    reading: currentReading,
                    inputUnit: WeightUnit.kilogram,
                    outputUnit: WeightUnit.kilogram,
                    onChanged: (value) => setState(() => format = value),
                  );
                },
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Formato de salida'));
      await tester.pumpAndSettle();
      await tester.tap(
        find.byType(DropdownButtonFormField<WeightDecimalSeparator>),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Coma (,)').last);
      await tester.pumpAndSettle();
      expect(find.text('Se escribirá: 1,238'), findsOneWidget);
      await tester.tap(find.byType(DropdownButtonFormField<int>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('2 decimales').last);
      await tester.pumpAndSettle();
      expect(find.text('Se escribirá: 1,24'), findsOneWidget);
      await tester.tap(
        find.byType(DropdownButtonFormField<WeightRoundingMode>),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Recortar (sin redondear)').last);
      await tester.pumpAndSettle();
      expect(find.text('Se escribirá: 1,23'), findsOneWidget);
      update(() => currentReading = reading('-002.867'));
      await tester.pumpAndSettle();
      expect(find.text('Peso recibido: -002.867 kg'), findsOneWidget);
      expect(find.text('Se escribirá: -2,86'), findsOneWidget);
      expect(find.text('Peso recibido: +001.238 kg'), findsNothing);
      update(() => currentReading = reading('0.000'));
      await tester.pumpAndSettle();
      expect(find.text('Se escribirá: 0,00'), findsOneWidget);
      await tester.tap(find.byType(DropdownButtonFormField<int>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Como en la lectura').last);
      await tester.pumpAndSettle();
      expect(format.decimalPlaces, isNull);
      expect(format.roundingMode, WeightRoundingMode.truncate);
      expect(find.text('Se escribirá: 0,000'), findsOneWidget);
      update(() => currentReading = null);
      await tester.pumpAndSettle();
      expect(find.textContaining('Se escribirá:'), findsNothing);
      expect(
        find.text(
          'Esperando una lectura del indicador para mostrar la vista previa.',
        ),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    });
  }
}
