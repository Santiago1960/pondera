import 'package:flutter/material.dart';

import '../../../app/app_theme.dart';

class RawDataLogEntry {
  const RawDataLogEntry({required this.rawData, required this.receivedAt});

  final String rawData;
  final DateTime receivedAt;
}

class RawDataLogPanel extends StatefulWidget {
  const RawDataLogPanel({
    required this.entries,
    required this.receptionSequence,
    this.continuousMode = false,
    super.key,
  });

  final List<RawDataLogEntry> entries;
  final int receptionSequence;
  final bool continuousMode;

  @override
  State<RawDataLogPanel> createState() => _RawDataLogPanelState();
}

class _RawDataLogPanelState extends State<RawDataLogPanel>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
      value: 1,
    );
  }

  @override
  void didUpdateWidget(RawDataLogPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.continuousMode ||
        widget.entries.isEmpty ||
        widget.receptionSequence == oldWidget.receptionSequence) {
      return;
    }
    if (MediaQuery.maybeOf(context)?.disableAnimations ?? false) {
      _pulseController.value = 1;
      return;
    }
    _pulseController.forward(from: 0);
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final latestEntry = widget.entries.lastOrNull;
    final previousEntries = widget.entries.reversed.skip(1).toList();
    final colorScheme = Theme.of(context).colorScheme;
    final successColor = Theme.of(context).brightness == Brightness.dark
        ? PonderaColors.successDark
        : PonderaColors.successLight;

    if (widget.continuousMode) {
      return Card(
        child: Theme(
          data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
          child: ExpansionTile(
            leading: Icon(
              Icons.sync,
              color: successColor,
            ),
            title: const Text(
              'Recepción continua',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            subtitle: const Text(
              'Las tramas se procesan en segundo plano.',
            ),
            childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
            children: [
              Align(
                alignment: Alignment.centerLeft,
                child: latestEntry == null
                    ? Text(
                        'Esperando datos de la balanza...',
                        style: TextStyle(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      )
                    : SelectableText(
                        _visibleRawData(latestEntry.rawData),
                        style: TextStyle(
                          color: colorScheme.onSurface,
                          fontFamily: 'IBMPlexMono',
                          fontSize: 13,
                        ),
                      ),
              ),
            ],
          ),
        ),
      );
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Text(
                  'Última trama recibida',
                  style: Theme.of(
                    context,
                  ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
                ),
                const Spacer(),
                _ReceptionStatus(receivedAt: latestEntry?.receivedAt),
              ],
            ),
            const SizedBox(height: 10),
            AnimatedBuilder(
              animation: _pulseController,
              builder: (context, child) {
                final pulseStrength =
                    1 - Curves.easeOutCubic.transform(_pulseController.value);
                return Container(
                  constraints: const BoxConstraints(minHeight: 64),
                  padding: const EdgeInsets.all(12),
                  alignment: Alignment.centerLeft,
                  decoration: BoxDecoration(
                    color: Color.lerp(
                      colorScheme.surfaceContainerHighest,
                      colorScheme.primaryContainer,
                      pulseStrength,
                    ),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: Color.lerp(
                        colorScheme.outlineVariant,
                        colorScheme.primary,
                        pulseStrength,
                      )!,
                      width: 1 + pulseStrength,
                    ),
                  ),
                  child: child,
                );
              },
              child: Semantics(
                liveRegion: true,
                label: latestEntry == null
                    ? 'Esperando datos de la balanza'
                    : 'Última trama recibida: ${latestEntry.rawData}',
                child: latestEntry == null
                    ? Text(
                        'Esperando datos de la balanza...',
                        style: TextStyle(color: colorScheme.onSurfaceVariant),
                      )
                    : SelectableText(
                        _visibleRawData(latestEntry.rawData),
                        style: TextStyle(
                          color: colorScheme.onSurface,
                          fontFamily: 'IBMPlexMono',
                          fontSize: 13,
                        ),
                      ),
              ),
            ),
            if (previousEntries.isNotEmpty) ...[
              const SizedBox(height: 4),
              Theme(
                data: Theme.of(
                  context,
                ).copyWith(dividerColor: Colors.transparent),
                child: ExpansionTile(
                  tilePadding: EdgeInsets.zero,
                  childrenPadding: const EdgeInsets.only(bottom: 4),
                  title: Text(_previousEntriesLabel(previousEntries.length)),
                  children: previousEntries.map((entry) {
                    return ListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      leading: Text(
                        _formatTime(entry.receivedAt),
                        style: TextStyle(
                          color: colorScheme.onSurfaceVariant,
                          fontFamily: 'IBMPlexMono',
                          fontSize: 11,
                        ),
                      ),
                      title: SelectableText(
                        _visibleRawData(entry.rawData),
                        style: const TextStyle(
                          fontFamily: 'IBMPlexMono',
                          fontSize: 12,
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ReceptionStatus extends StatelessWidget {
  const _ReceptionStatus({required this.receivedAt});

  final DateTime? receivedAt;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final hasReceivedData = receivedAt != null;
    final statusColor = hasReceivedData
        ? (isDark ? PonderaColors.successDark : PonderaColors.successLight)
        : Theme.of(context).colorScheme.onSurfaceVariant;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: statusColor, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(
          hasReceivedData
              ? 'Recibida ${_formatTime(receivedAt!)}'
              : 'Sin datos',
          style: TextStyle(
            color: statusColor,
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}

String _visibleRawData(String rawData) {
  return rawData.replaceAll('\r', '\\r').replaceAll('\n', '\\n');
}

String _formatTime(DateTime value) {
  final hour = value.hour.toString().padLeft(2, '0');
  final minute = value.minute.toString().padLeft(2, '0');
  final second = value.second.toString().padLeft(2, '0');
  return '$hour:$minute:$second';
}

String _previousEntriesLabel(int count) {
  return count == 1 ? 'Ver trama anterior' : 'Ver $count tramas anteriores';
}
