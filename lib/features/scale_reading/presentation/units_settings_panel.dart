import 'package:flutter/material.dart';

import '../../../shared/widgets/settings_expansion_card.dart';
import '../domain/weight_unit.dart';

class UnitsSettingsPanel extends StatelessWidget {
  const UnitsSettingsPanel({
    required this.selectedInputUnit,
    required this.selectedOutputUnit,
    required this.inputUnits,
    required this.outputUnits,
    required this.onInputUnitChanged,
    required this.onOutputUnitChanged,
    super.key,
  });

  final WeightUnit selectedInputUnit;
  final WeightUnit selectedOutputUnit;
  final List<WeightUnit> inputUnits;
  final List<WeightUnit> outputUnits;
  final ValueChanged<WeightUnit> onInputUnitChanged;
  final ValueChanged<WeightUnit> onOutputUnitChanged;

  @override
  Widget build(BuildContext context) {
    return SettingsExpansionCard(
      title: 'Unidades de medida',
      summary: '${selectedInputUnit.label} → ${selectedOutputUnit.label}',
      icon: Icons.scale_outlined,
      child: Row(
        children: [
          Expanded(
            child: DropdownButtonFormField<WeightUnit>(
              initialValue: selectedInputUnit,
              decoration: const InputDecoration(
                labelText: 'Origen Balanza',
                border: OutlineInputBorder(),
                isDense: true,
              ),
              items: inputUnits.map((unit) {
                return DropdownMenuItem(value: unit, child: Text(unit.label));
              }).toList(),
              onChanged: (unit) {
                if (unit != null) {
                  onInputUnitChanged(unit);
                }
              },
            ),
          ),
          const SizedBox(width: 15),
          Expanded(
            child: DropdownButtonFormField<WeightUnit>(
              initialValue: selectedOutputUnit,
              decoration: const InputDecoration(
                labelText: 'Destino Escritura',
                border: OutlineInputBorder(),
                isDense: true,
              ),
              items: outputUnits.map((unit) {
                return DropdownMenuItem(value: unit, child: Text(unit.label));
              }).toList(),
              onChanged: (unit) {
                if (unit != null) {
                  onOutputUnitChanged(unit);
                }
              },
            ),
          ),
        ],
      ),
    );
  }
}
