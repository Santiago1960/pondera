import 'package:flutter/material.dart';

import '../domain/license_payload.dart';

Future<void> showLicenseImportFeedbackDialog(
  BuildContext context, {
  required bool installed,
  required String message,
  LicensePayload? payload,
  bool previousLicensePreserved = false,
}) {
  assert(!installed || payload != null);
  final colorScheme = Theme.of(context).colorScheme;
  final installedPayload = installed ? payload : null;

  return showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (dialogContext) {
      return AlertDialog(
        icon: Icon(
          installed ? Icons.verified_outlined : Icons.gpp_bad_outlined,
          color: installed ? colorScheme.primary : colorScheme.error,
          size: 36,
        ),
        title: Text(
          installed
              ? 'Licencia instalada correctamente'
              : 'No se instaló la licencia',
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(message),
              if (installedPayload case final license?) ...[
                const SizedBox(height: 16),
                const Divider(),
                const SizedBox(height: 8),
                _LicenseDetail(label: 'Cliente', value: license.customerName),
                _LicenseDetail(
                  label: 'Sede',
                  value: '${license.siteName} · ${license.city}',
                ),
                _LicenseDetail(label: 'Equipo', value: license.deviceLabel),
                _LicenseDetail(
                  label: 'Licencia',
                  value: license.licenseId,
                  selectable: true,
                ),
              ],
              if (!installed && previousLicensePreserved) ...[
                const SizedBox(height: 12),
                Text(
                  'La licencia que ya estaba activa no fue modificada.',
                  style: TextStyle(
                    color: colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ],
          ),
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Entendido'),
          ),
        ],
      );
    },
  );
}

class _LicenseDetail extends StatelessWidget {
  const _LicenseDetail({
    required this.label,
    required this.value,
    this.selectable = false,
  });

  final String label;
  final String value;
  final bool selectable;

  @override
  Widget build(BuildContext context) {
    final labelStyle = Theme.of(
      context,
    ).textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w600);
    final valueStyle = TextStyle(
      color: Theme.of(context).colorScheme.onSurfaceVariant,
    );

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 72, child: Text(label, style: labelStyle)),
          const SizedBox(width: 8),
          Expanded(
            child: selectable
                ? SelectableText(value, style: valueStyle)
                : Text(value, style: valueStyle),
          ),
        ],
      ),
    );
  }
}
