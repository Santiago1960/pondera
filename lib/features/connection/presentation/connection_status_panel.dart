import 'package:flutter/material.dart';

import '../../../app/app_theme.dart';

class ConnectionStatusPanel extends StatelessWidget {
  const ConnectionStatusPanel({
    required this.activeDeviceLabel,
    required this.uiStatusMessage,
    required this.isConnected,
    required this.isInteractionBlocked,
    required this.onToggleConnection,
    this.isError = false,
    super.key,
  });

  final String activeDeviceLabel;
  final String uiStatusMessage;
  final bool isConnected;
  final bool isInteractionBlocked;
  final bool isError;
  final VoidCallback onToggleConnection;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final statusColor = isInteractionBlocked || isError
        ? colorScheme.error
        : isConnected
        ? (isDark ? PonderaColors.successDark : PonderaColors.successLight)
        : (isDark ? PonderaColors.warningDark : PonderaColors.warningLight);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              width: 12,
              height: 12,
              decoration: BoxDecoration(
                color: statusColor,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    uiStatusMessage,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      color: statusColor,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    activeDeviceLabel,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: colorScheme.onSurfaceVariant,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 16),
            FilledButton.icon(
              onPressed: isInteractionBlocked ? null : onToggleConnection,
              style: isConnected
                  ? FilledButton.styleFrom(
                      backgroundColor: colorScheme.error,
                      foregroundColor: colorScheme.onError,
                    )
                  : null,
              icon: Icon(isConnected ? Icons.link_off : Icons.link, size: 18),
              label: Text(isConnected ? 'Desconectar' : 'Conectar'),
            ),
          ],
        ),
      ),
    );
  }
}
