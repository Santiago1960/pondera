import 'package:flutter/material.dart';

import '../../../shared/widgets/settings_expansion_card.dart';

class LicenseStatusPanel extends StatelessWidget {
  const LicenseStatusPanel({
    required this.statusMessage,
    required this.isExpired,
    required this.showResetDemoAction,
    required this.onResetDemo,
    required this.onGenerateActivationRequest,
    required this.onImportLicense,
    this.customerDetails,
    this.deviceDetails,
    super.key,
  });

  final String statusMessage;
  final bool isExpired;
  final bool showResetDemoAction;
  final String? customerDetails;
  final String? deviceDetails;
  final VoidCallback onResetDemo;
  final VoidCallback onGenerateActivationRequest;
  final VoidCallback onImportLicense;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return SettingsExpansionCard(
      title: 'Licencia',
      summary: statusMessage,
      icon: isExpired ? Icons.gpp_bad_outlined : Icons.verified_user_outlined,
      initiallyExpanded: isExpired,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (customerDetails case final details?)
            Text(
              details,
              style: TextStyle(color: colorScheme.onSurfaceVariant),
            ),
          if (deviceDetails case final details?) ...[
            const SizedBox(height: 4),
            Text(
              details,
              style: TextStyle(color: colorScheme.onSurfaceVariant),
            ),
          ],
          if (customerDetails != null || deviceDetails != null)
            const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              OutlinedButton.icon(
                onPressed: onGenerateActivationRequest,
                icon: const Icon(Icons.description_outlined),
                label: const Text('Generar solicitud de activación'),
              ),
              FilledButton.tonalIcon(
                onPressed: onImportLicense,
                icon: const Icon(Icons.file_open_outlined),
                label: const Text('Importar licencia'),
              ),
              if (showResetDemoAction)
                TextButton.icon(
                  onPressed: onResetDemo,
                  icon: const Icon(Icons.restart_alt),
                  label: const Text('Restablecer demo (desarrollo)'),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
