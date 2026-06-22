import 'package:flutter/material.dart';

import '../../../shared/widgets/settings_expansion_card.dart';

class ConnectionDiagnosticsPanel extends StatelessWidget {
  const ConnectionDiagnosticsPanel({
    required this.networkDiagnostics,
    super.key,
  });

  final String networkDiagnostics;

  @override
  Widget build(BuildContext context) {
    return SettingsExpansionCard(
      title: 'Diagnóstico avanzado',
      icon: Icons.monitor_heart_outlined,
      child: SelectableText(
        networkDiagnostics,
        style: TextStyle(
          color: Theme.of(context).colorScheme.onSurfaceVariant,
          fontFamily: 'IBMPlexMono',
          fontSize: 12,
        ),
      ),
    );
  }
}
