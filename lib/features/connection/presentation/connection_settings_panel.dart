import 'dart:io';

import 'package:flutter/material.dart';

import '../../../shared/widgets/settings_expansion_card.dart';
import '../domain/connection_type.dart';

class ConnectionSettingsPanel extends StatelessWidget {
  const ConnectionSettingsPanel({
    required this.selectedConnectionType,
    required this.isConnected,
    required this.ipController,
    required this.portController,
    required this.serialPortController,
    required this.serialPortName,
    required this.availableSerialPorts,
    required this.serialBaudRate,
    required this.serialDataBits,
    required this.serialStopBits,
    required this.serialParity,
    required this.serialFlowControl,
    required this.baudRates,
    required this.dataBitsOptions,
    required this.stopBitsOptions,
    required this.parityLabels,
    required this.flowControlLabels,
    required this.onConnectionTypeChanged,
    required this.onSaveNetwork,
    required this.onSerialPortNameChanged,
    required this.onDetectedSerialPortChanged,
    required this.onRefreshSerialPorts,
    required this.onSerialBaudRateChanged,
    required this.onSerialDataBitsChanged,
    required this.onSerialStopBitsChanged,
    required this.onSerialParityChanged,
    required this.onSerialFlowControlChanged,
    required this.onSaveSerial,
    super.key,
  });

  final ConnectionType selectedConnectionType;
  final bool isConnected;
  final TextEditingController ipController;
  final TextEditingController portController;
  final TextEditingController serialPortController;
  final String serialPortName;
  final List<String> availableSerialPorts;
  final int serialBaudRate;
  final int serialDataBits;
  final int serialStopBits;
  final String serialParity;
  final String serialFlowControl;
  final List<int> baudRates;
  final List<int> dataBitsOptions;
  final List<int> stopBitsOptions;
  final Map<String, String> parityLabels;
  final Map<String, String> flowControlLabels;
  final ValueChanged<ConnectionType> onConnectionTypeChanged;
  final VoidCallback onSaveNetwork;
  final ValueChanged<String> onSerialPortNameChanged;
  final ValueChanged<String> onDetectedSerialPortChanged;
  final VoidCallback onRefreshSerialPorts;
  final ValueChanged<int> onSerialBaudRateChanged;
  final ValueChanged<int> onSerialDataBitsChanged;
  final ValueChanged<int> onSerialStopBitsChanged;
  final ValueChanged<String> onSerialParityChanged;
  final ValueChanged<String> onSerialFlowControlChanged;
  final VoidCallback onSaveSerial;

  @override
  Widget build(BuildContext context) {
    return SettingsExpansionCard(
      title: 'Enlace con la balanza',
      summary: _connectionSummary(),
      icon: selectedConnectionType == ConnectionType.ethernet
          ? Icons.lan_outlined
          : Icons.settings_input_component_outlined,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          DropdownButtonFormField<ConnectionType>(
            initialValue: selectedConnectionType,
            decoration: const InputDecoration(
              labelText: 'Tipo de conexión',
              border: OutlineInputBorder(),
              isDense: true,
            ),
            items: ConnectionType.values.map((type) {
              return DropdownMenuItem(
                value: type,
                child: Text(connectionTypeLabels[type] ?? type.name),
              );
            }).toList(),
            onChanged: isConnected
                ? null
                : (value) {
                    if (value != null) {
                      onConnectionTypeChanged(value);
                    }
                  },
          ),
          const SizedBox(height: 10),
          if (selectedConnectionType == ConnectionType.ethernet)
            _buildEthernetSettings(),
          if (selectedConnectionType == ConnectionType.serial)
            _buildSerialSettings(),
        ],
      ),
    );
  }

  String _connectionSummary() {
    if (selectedConnectionType == ConnectionType.ethernet) {
      return 'Ethernet · ${ipController.text.trim()}:${portController.text.trim()}';
    }
    final port = serialPortName.isEmpty ? 'Sin puerto' : serialPortName;
    return 'RS-232 · $port · $serialBaudRate baud';
  }

  Widget _buildEthernetSettings() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final availableWidth = constraints.maxWidth;
        final ipWidth = availableWidth >= 620
            ? (availableWidth - 72) * 0.62
            : availableWidth;
        final portWidth = availableWidth >= 620
            ? (availableWidth - 72) * 0.38
            : availableWidth;

        return Wrap(
          spacing: 10,
          runSpacing: 10,
          crossAxisAlignment: WrapCrossAlignment.end,
          children: [
            SizedBox(
              width: ipWidth.clamp(220.0, availableWidth),
              child: TextField(
                controller: ipController,
                decoration: const InputDecoration(
                  labelText: 'Dirección IP',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
                style: const TextStyle(fontSize: 13, fontFamily: 'IBMPlexMono'),
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
              ),
            ),
            SizedBox(
              width: portWidth.clamp(160.0, availableWidth),
              child: TextField(
                controller: portController,
                decoration: const InputDecoration(
                  labelText: 'Puerto TCP',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
                style: const TextStyle(fontSize: 13, fontFamily: 'IBMPlexMono'),
                keyboardType: TextInputType.number,
              ),
            ),
            ElevatedButton(
              onPressed: onSaveNetwork,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
                minimumSize: const Size(52, 52),
              ),
              child: const Icon(Icons.save_sharp, size: 18),
            ),
          ],
        );
      },
    );
  }

  Widget _buildSerialSettings() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final availableWidth = constraints.maxWidth;
        final longRowWidth = availableWidth >= 900
            ? (availableWidth - 62) / 2
            : availableWidth;
        final shortFieldWidth = availableWidth >= 760
            ? (availableWidth - 40) / 5
            : availableWidth >= 520
                ? (availableWidth - 20) / 3
                : availableWidth;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: 10,
              runSpacing: 10,
              crossAxisAlignment: WrapCrossAlignment.end,
              children: [
                SizedBox(
                  width: longRowWidth.clamp(240.0, availableWidth),
                  child: TextField(
                    controller: serialPortController,
                    decoration: InputDecoration(
                      labelText: Platform.isWindows
                          ? 'Puerto serial (ej. COM3)'
                          : 'Puerto serial',
                      border: const OutlineInputBorder(),
                      isDense: true,
                    ),
                    style: const TextStyle(
                      fontSize: 13,
                      fontFamily: 'IBMPlexMono',
                    ),
                    onChanged: onSerialPortNameChanged,
                  ),
                ),
                SizedBox(
                  width: longRowWidth.clamp(220.0, availableWidth),
                  child: DropdownButtonFormField<String>(
                    isExpanded: true,
                    initialValue: availableSerialPorts.contains(serialPortName)
                        ? serialPortName
                        : null,
                    decoration: const InputDecoration(
                      labelText: 'Detectados',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    items: availableSerialPorts.map((port) {
                      return DropdownMenuItem(
                        value: port,
                        child: Text(
                          port,
                          overflow: TextOverflow.ellipsis,
                        ),
                      );
                    }).toList(),
                    onChanged: (value) {
                      if (value != null) {
                        onDetectedSerialPortChanged(value);
                      }
                    },
                  ),
                ),
                IconButton(
                  onPressed: onRefreshSerialPorts,
                  tooltip: 'Actualizar puertos',
                  icon: const Icon(Icons.refresh),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                SizedBox(
                  width: shortFieldWidth.clamp(140.0, availableWidth),
                  child: _buildIntDropdown(
                    value: baudRates.contains(serialBaudRate)
                        ? serialBaudRate
                        : 9600,
                    label: 'Baud rate',
                    options: baudRates,
                    onChanged: onSerialBaudRateChanged,
                  ),
                ),
                SizedBox(
                  width: shortFieldWidth.clamp(132.0, availableWidth),
                  child: _buildIntDropdown(
                    value: dataBitsOptions.contains(serialDataBits)
                        ? serialDataBits
                        : 8,
                    label: 'Data bits',
                    options: dataBitsOptions,
                    onChanged: onSerialDataBitsChanged,
                  ),
                ),
                SizedBox(
                  width: shortFieldWidth.clamp(138.0, availableWidth),
                  child: _buildStringDropdown(
                    value: parityLabels.containsKey(serialParity)
                        ? serialParity
                        : 'none',
                    label: 'Paridad',
                    options: parityLabels,
                    onChanged: onSerialParityChanged,
                  ),
                ),
                SizedBox(
                  width: shortFieldWidth.clamp(132.0, availableWidth),
                  child: _buildIntDropdown(
                    value: stopBitsOptions.contains(serialStopBits)
                        ? serialStopBits
                        : 1,
                    label: 'Stop bits',
                    options: stopBitsOptions,
                    onChanged: onSerialStopBitsChanged,
                  ),
                ),
                SizedBox(
                  width: shortFieldWidth.clamp(148.0, availableWidth),
                  child: _buildStringDropdown(
                    value: flowControlLabels.containsKey(serialFlowControl)
                        ? serialFlowControl
                        : 'none',
                    label: 'Flow control',
                    options: flowControlLabels,
                    onChanged: onSerialFlowControlChanged,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Align(
              alignment: Alignment.centerRight,
              child: ElevatedButton(
                onPressed: onSaveSerial,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    vertical: 16,
                    horizontal: 12,
                  ),
                  minimumSize: const Size(52, 52),
                ),
                child: const Icon(Icons.save_sharp, size: 18),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildIntDropdown({
    required int value,
    required String label,
    required List<int> options,
    required ValueChanged<int> onChanged,
  }) {
    return DropdownButtonFormField<int>(
      isExpanded: true,
      initialValue: value,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
        isDense: true,
      ),
      items: options.map((option) {
        return DropdownMenuItem(
          value: option,
          child: Text(
            option.toString(),
            overflow: TextOverflow.ellipsis,
          ),
        );
      }).toList(),
      onChanged: (selectedValue) {
        if (selectedValue != null) {
          onChanged(selectedValue);
        }
      },
    );
  }

  Widget _buildStringDropdown({
    required String value,
    required String label,
    required Map<String, String> options,
    required ValueChanged<String> onChanged,
  }) {
    return DropdownButtonFormField<String>(
      isExpanded: true,
      initialValue: value,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
        isDense: true,
      ),
      items: options.entries.map((entry) {
        return DropdownMenuItem(
          value: entry.key,
          child: Text(
            entry.value,
            overflow: TextOverflow.ellipsis,
          ),
        );
      }).toList(),
      onChanged: (selectedValue) {
        if (selectedValue != null) {
          onChanged(selectedValue);
        }
      },
    );
  }
}
