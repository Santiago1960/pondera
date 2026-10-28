import 'package:flutter/material.dart';

import '../../../shared/widgets/settings_expansion_card.dart';
import '../domain/reading_parser.dart';
import '../domain/weight_output_format.dart';
import '../domain/weight_unit.dart';

class WeightOutputSettingsPanel extends StatelessWidget {
  const WeightOutputSettingsPanel({
    required this.format,
    required this.onChanged,
    required this.reading,
    required this.inputUnit,
    required this.outputUnit,
    super.key,
  });

  final WeightOutputFormat format;
  final ValueChanged<WeightOutputFormat> onChanged;
  final ReadingParseResult? reading;
  final WeightUnit inputUnit;
  final WeightUnit outputUnit;

  void _update({
    WeightDecimalSeparator? separator,
    int? decimalPlaces,
    WeightRoundingMode? roundingMode,
  }) {
    onChanged(
      WeightOutputFormat(
        separator: separator ?? format.separator,
        decimalPlaces: decimalPlaces == -1
            ? null
            : decimalPlaces ?? format.decimalPlaces,
        roundingMode: roundingMode ?? format.roundingMode,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentReading = reading;
    final hasReading = currentReading?.numericValue?.isFinite ?? false;
    final output = hasReading
        ? format.formatReading(
            currentReading!,
            inputUnit: inputUnit,
            outputUnit: outputUnit,
          )
        : null;
    return SettingsExpansionCard(
      title: 'Formato de salida',
      summary: output == null
          ? 'Esperando una lectura del indicador'
          : '${currentReading!.sourceWeight} ${inputUnit.code} → $output ${outputUnit.code}',
      icon: Icons.numbers_outlined,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Elige cómo mostrar y escribir el peso en Excel u otra aplicación. '
            'Puedes cambiar este formato sin crear otra receta.',
          ),
          const SizedBox(height: 14),
          DropdownButtonFormField<WeightDecimalSeparator>(
            key: ValueKey('separator-${format.separator.name}'),
            initialValue: format.separator,
            isExpanded: true,
            decoration: const InputDecoration(
              labelText: 'Separador decimal',
              border: OutlineInputBorder(),
            ),
            items: const [
              DropdownMenuItem(
                value: WeightDecimalSeparator.indicator,
                child: Text('Como muestra el indicador'),
              ),
              DropdownMenuItem(
                value: WeightDecimalSeparator.dot,
                child: Text('Punto (.)'),
              ),
              DropdownMenuItem(
                value: WeightDecimalSeparator.comma,
                child: Text('Coma (,)'),
              ),
            ],
            onChanged: (value) {
              if (value != null) _update(separator: value);
            },
          ),
          const SizedBox(height: 14),
          DropdownButtonFormField<int>(
            key: ValueKey('places-${format.decimalPlaces}'),
            initialValue: format.decimalPlaces ?? -1,
            isExpanded: true,
            decoration: const InputDecoration(
              labelText: 'Cantidad de decimales',
              border: OutlineInputBorder(),
            ),
            items: [
              const DropdownMenuItem(
                value: -1,
                child: Text('Como en la lectura'),
              ),
              for (var places = 0; places <= 6; places++)
                DropdownMenuItem(
                  value: places,
                  child: Text(
                    '$places ${places == 1 ? 'decimal' : 'decimales'}',
                  ),
                ),
            ],
            onChanged: (value) {
              if (value != null) _update(decimalPlaces: value);
            },
          ),
          const SizedBox(height: 14),
          DropdownButtonFormField<WeightRoundingMode>(
            key: ValueKey('rounding-${format.roundingMode.name}'),
            initialValue: format.roundingMode,
            isExpanded: true,
            decoration: const InputDecoration(
              labelText: 'Al reducir decimales',
              border: OutlineInputBorder(),
            ),
            items: const [
              DropdownMenuItem(
                value: WeightRoundingMode.round,
                child: Text('Redondear'),
              ),
              DropdownMenuItem(
                value: WeightRoundingMode.truncate,
                child: Text('Recortar (sin redondear)'),
              ),
            ],
            onChanged: (value) {
              if (value != null) _update(roundingMode: value);
            },
          ),
          const SizedBox(height: 12),
          if (output == null)
            const Text(
              'Esperando una lectura del indicador para mostrar la vista previa.',
            )
          else ...[
            Text(
              'Peso recibido: ${currentReading!.sourceWeight} ${inputUnit.code}',
            ),
            const SizedBox(height: 6),
            Text('Se escribirá: $output'),
            Text('Unidad de salida: ${outputUnit.code}'),
          ],
          const SizedBox(height: 6),
          const Text('Se aplica después de convertir las unidades.'),
        ],
      ),
    );
  }
}
