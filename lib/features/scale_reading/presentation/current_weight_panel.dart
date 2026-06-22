import 'package:flutter/material.dart';

import '../../../app/app_theme.dart';

class CurrentWeightPanel extends StatelessWidget {
  const CurrentWeightPanel({required this.weightDisplay, super.key});

  final String weightDisplay;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Card(
      color: colorScheme.surfaceContainerHighest,
      margin: EdgeInsets.only(left:200, right:200),
      elevation: 6,
      child: Padding(
        padding: const EdgeInsets.all(15.0),
        child: Column(
          children: [
            Text(
              'PESO OBTENIDO',
              style: TextStyle(
                fontSize: 14,
                color: colorScheme.primary,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 5),
            Text(
              weightDisplay,
              style: TextStyle(
                fontSize: 36,
                fontWeight: FontWeight.bold,
                color: isDark
                    ? PonderaColors.weightDark
                    : PonderaColors.weightLight,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
