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
    return Row(
      children: [
        Expanded(
          flex: 3,
          child: TextField(
            controller: ipController,
            decoration: const InputDecoration(
              labelText: 'Dirección IP',
              border: OutlineInputBorder(),
              isDense: true,
            ),
            style: const TextStyle(fontSize: 13, fontFamily: 'IBMPlexMono'),
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          flex: 2,
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
        const SizedBox(width: 10),
        ElevatedButton(
          onPressed: onSaveNetwork,
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
          ),
          child: const Icon(Icons.save_sharp, size: 18),
        ),
      ],
    );
  }

  Widget _buildSerialSettings() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              flex: 3,
              child: TextField(
                controller: serialPortController,
                decoration: InputDecoration(
                  labelText: Platform.isWindows
                      ? 'Puerto serial (ej. COM3)'
                      : 'Puerto serial',
                  border: const OutlineInputBorder(),
                  isDense: true,
                ),
                style: const TextStyle(fontSize: 13, fontFamily: 'IBMPlexMono'),
                onChanged: onSerialPortNameChanged,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              flex: 2,
              child: DropdownButtonFormField<String>(
                initialValue: availableSerialPorts.contains(serialPortName)
                    ? serialPortName
                    : null,
                decoration: const InputDecoration(
                  labelText: 'Detectados',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
                items: availableSerialPorts.map((port) {
                  return DropdownMenuItem(value: port, child: Text(port));
                }).toList(),
                onChanged: (value) {
                  if (value != null) {
                    onDetectedSerialPortChanged(value);
                  }
                },
              ),
            ),
            const SizedBox(width: 10),
            IconButton(
              onPressed: onRefreshSerialPorts,
              tooltip: 'Actualizar puertos',
              icon: const Icon(Icons.refresh),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: _buildIntDropdown(
                value: baudRates.contains(serialBaudRate)
                    ? serialBaudRate
                    : 9600,
                label: 'Baud rate',
                options: baudRates,
                onChanged: onSerialBaudRateChanged,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _buildIntDropdown(
                value: dataBitsOptions.contains(serialDataBits)
                    ? serialDataBits
                    : 8,
                label: 'Data bits',
                options: dataBitsOptions,
                onChanged: onSerialDataBitsChanged,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _buildStringDropdown(
                value: parityLabels.containsKey(serialParity)
                    ? serialParity
                    : 'none',
                label: 'Paridad',
                options: parityLabels,
                onChanged: onSerialParityChanged,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _buildIntDropdown(
                value: stopBitsOptions.contains(serialStopBits)
                    ? serialStopBits
                    : 1,
                label: 'Stop bits',
                options: stopBitsOptions,
                onChanged: onSerialStopBitsChanged,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
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
              padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
            ),
            child: const Icon(Icons.save_sharp, size: 18),
          ),
        ),
      ],
    );
  }

  Widget _buildIntDropdown({
    required int value,
    required String label,
    required List<int> options,
    required ValueChanged<int> onChanged,
  }) {
    return DropdownButtonFormField<int>(
      initialValue: value,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
        isDense: true,
      ),
      items: options.map((option) {
        return DropdownMenuItem(value: option, child: Text(option.toString()));
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
      initialValue: value,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
        isDense: true,
      ),
      items: options.entries.map((entry) {
        return DropdownMenuItem(value: entry.key, child: Text(entry.value));
      }).toList(),
      onChanged: (selectedValue) {
        if (selectedValue != null) {
          onChanged(selectedValue);
        }
      },
    );
  }
}
