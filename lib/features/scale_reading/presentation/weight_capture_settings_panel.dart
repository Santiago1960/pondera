import 'package:flutter/material.dart';

import '../../../shared/widgets/settings_expansion_card.dart';
import '../domain/weight_capture_controller.dart';
import '../domain/weight_unit.dart';

class WeightCaptureSettingsPanel extends StatelessWidget {
  const WeightCaptureSettingsPanel({
    required this.selectedMode,
    required this.rangeEnabled,
    required this.rangeUnit,
    required this.minimumController,
    required this.maximumController,
    required this.stableMillisecondsController,
    required this.onModeChanged,
    required this.onRangeEnabledChanged,
    required this.onRangeUnitChanged,
    required this.onSave,
    super.key,
  });

  final WeightCaptureMode selectedMode;
  final bool rangeEnabled;
  final WeightUnit rangeUnit;
  final TextEditingController minimumController;
  final TextEditingController maximumController;
  final TextEditingController stableMillisecondsController;
  final ValueChanged<WeightCaptureMode> onModeChanged;
  final ValueChanged<bool> onRangeEnabledChanged;
  final ValueChanged<WeightUnit> onRangeUnitChanged;
  final VoidCallback onSave;

  @override
  Widget build(BuildContext context) {
    return SettingsExpansionCard(
      title: 'Captura del peso',
      summary:
          '${_modeLabel(selectedMode)} · ${rangeEnabled ? 'Rango restringido' : 'Rango libre'}',
      icon: Icons.scale_outlined,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          DropdownButtonFormField<WeightCaptureMode>(
            key: ValueKey(selectedMode),
            initialValue: selectedMode,
            decoration: const InputDecoration(
              labelText: 'Modo de captura',
              border: OutlineInputBorder(),
              isDense: true,
            ),
            items: WeightCaptureMode.values.map((mode) {
              return DropdownMenuItem(
                value: mode,
                child: Text(_modeLabel(mode)),
              );
            }).toList(),
            onChanged: (mode) {
              if (mode != null) {
                onModeChanged(mode);
              }
            },
          ),
          const SizedBox(height: 8),
          Text(
            switch (selectedMode) {
              WeightCaptureMode.indicatorPrint =>
                'Modo activo inmediatamente. Registra cada trama enviada con el botón Print del indicador.',
              WeightCaptureMode.keyboardF12 =>
                'Modo activo inmediatamente. Presione F12 para registrar el último peso recibido; para registrar otro, la balanza debe volver a cero.',
              WeightCaptureMode.automaticStable =>
                'Registra automáticamente un peso cuando permanece estable durante el tiempo configurado; para registrar otro, la balanza debe volver a cero.',
            },
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 8),
          SwitchListTile.adaptive(
            key: const Key('capture-range-toggle'),
            contentPadding: EdgeInsets.zero,
            title: const Text('Restringir pesos válidos'),
            subtitle: Text(
              rangeEnabled
                  ? 'Solo se registran pesos dentro del rango definido.'
                  : 'Se registra cualquier peso diferente de cero.',
            ),
            value: rangeEnabled,
            onChanged: onRangeEnabledChanged,
          ),
          if (rangeEnabled) ...[
            const SizedBox(height: 4),
            LayoutBuilder(
              builder: (context, constraints) {
                final width = constraints.maxWidth >= 680
                    ? (constraints.maxWidth - 20) / 3
                    : constraints.maxWidth;
                return Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    SizedBox(
                      width: width,
                      child: TextField(
                        key: const Key('capture-minimum-field'),
                        controller: minimumController,
                        decoration: const InputDecoration(
                          labelText: 'Peso mínimo',
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                      ),
                    ),
                    SizedBox(
                      width: width,
                      child: TextField(
                        key: const Key('capture-maximum-field'),
                        controller: maximumController,
                        decoration: const InputDecoration(
                          labelText: 'Peso máximo',
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                      ),
                    ),
                    SizedBox(
                      width: width,
                      child: DropdownButtonFormField<WeightUnit>(
                        key: ValueKey(rangeUnit),
                        initialValue: rangeUnit,
                        decoration: const InputDecoration(
                          labelText: 'Unidad del rango',
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                        items: WeightUnit.values.map((unit) {
                          return DropdownMenuItem(
                            value: unit,
                            child: Text(unit.label),
                          );
                        }).toList(),
                        onChanged: (unit) {
                          if (unit != null) {
                            onRangeUnitChanged(unit);
                          }
                        },
                      ),
                    ),
                  ],
                );
              },
            ),
          ],
          const SizedBox(height: 12),
          SizedBox(
            width: 240,
            child: TextField(
              key: const Key('capture-stable-milliseconds-field'),
              controller: stableMillisecondsController,
              enabled: selectedMode == WeightCaptureMode.automaticStable,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Tiempo estable (ms)',
                helperText: 'Entre 100 y 60000 ms',
                border: OutlineInputBorder(),
                isDense: true,
              ),
            ),
          ),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerRight,
            child: ElevatedButton.icon(
              key: const Key('capture-save-button'),
              onPressed: onSave,
              icon: const Icon(Icons.save_outlined, size: 18),
              label: const Text('Guardar captura'),
            ),
          ),
        ],
      ),
    );
  }

  static String _modeLabel(WeightCaptureMode mode) {
    return switch (mode) {
      WeightCaptureMode.indicatorPrint => 'Print del indicador',
      WeightCaptureMode.keyboardF12 => 'Tecla F12',
      WeightCaptureMode.automaticStable => 'Automático al estabilizarse',
    };
  }
}
