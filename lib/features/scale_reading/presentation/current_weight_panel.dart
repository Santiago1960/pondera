import 'package:flutter/material.dart';

import '../../../app/app_theme.dart';

class CurrentWeightPanel extends StatelessWidget {
  const CurrentWeightPanel({
    required this.weightDisplay,
    this.grossDisplay,
    this.tareDisplay = '0 kg',
    this.unitDisplay = '',
    this.tareActive = false,
    this.onChangeTare,
    this.onClearTare,
    super.key,
  });

  final String weightDisplay;
  final String? grossDisplay;
  final String tareDisplay;
  final String unitDisplay;
  final bool tareActive;
  final VoidCallback? onChangeTare;
  final VoidCallback? onClearTare;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Card(
      color: colorScheme.surfaceContainerHighest,
      margin: EdgeInsets.zero,
      elevation: 6,
      child: Padding(
        padding: const EdgeInsets.all(15.0),
        child: Column(
          children: [
            Text(
              'PESO NETO',
              style: TextStyle(
                fontSize: 14,
                color: colorScheme.primary,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 5),
            Text(
              grossDisplay == null
                  ? weightDisplay
                  : '$weightDisplay $unitDisplay',
              style: TextStyle(
                fontSize: 36,
                fontWeight: FontWeight.bold,
                color: isDark
                    ? PonderaColors.weightDark
                    : PonderaColors.weightLight,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              grossDisplay == null
                  ? 'Tara: $tareDisplay'
                  : 'Bruto: $grossDisplay $unitDisplay · Tara: $tareDisplay',
              textAlign: TextAlign.center,
            ),
            Text(
              tareActive ? 'Tara activa' : 'Sin tara',
              style: TextStyle(color: colorScheme.primary),
            ),
            Wrap(
              alignment: WrapAlignment.center,
              spacing: 8,
              children: [
                TextButton.icon(
                  onPressed: onChangeTare,
                  icon: const Icon(Icons.edit_outlined),
                  label: const Text('Cambiar tara'),
                ),
                if (tareActive)
                  TextButton(
                    onPressed: onClearTare,
                    child: const Text('Quitar tara'),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
