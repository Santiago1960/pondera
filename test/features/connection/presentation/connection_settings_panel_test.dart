import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pondera/features/connection/domain/connection_type.dart';
import 'package:pondera/features/connection/presentation/connection_settings_panel.dart';

void main() {
  testWidgets('los desplegables seriales conservan sus tipos y etiquetas', (
    tester,
  ) async {
    final ipController = TextEditingController(text: '192.168.100.130');
    final portController = TextEditingController(text: '3000');
    final serialPortController = TextEditingController(text: 'COM3');
    addTearDown(ipController.dispose);
    addTearDown(portController.dispose);
    addTearDown(serialPortController.dispose);
    int? selectedBaudRate;
    String? selectedParity;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: ConnectionSettingsPanel(
              selectedConnectionType: ConnectionType.serial,
              isConnected: false,
              ipController: ipController,
              portController: portController,
              serialPortController: serialPortController,
              serialPortName: 'COM3',
              availableSerialPorts: const ['COM3'],
              serialBaudRate: 9600,
              serialDataBits: 8,
              serialStopBits: 1,
              serialParity: 'none',
              serialFlowControl: 'none',
              baudRates: const [9600, 19200],
              dataBitsOptions: const [7, 8],
              stopBitsOptions: const [1, 2],
              parityLabels: const {'none': 'Ninguna', 'even': 'Par'},
              flowControlLabels: const {'none': 'Ninguno'},
              onConnectionTypeChanged: (_) {},
              onSaveNetwork: () {},
              onSerialPortNameChanged: (_) {},
              onDetectedSerialPortChanged: (_) {},
              onRefreshSerialPorts: () {},
              onSerialBaudRateChanged: (value) => selectedBaudRate = value,
              onSerialDataBitsChanged: (_) {},
              onSerialStopBitsChanged: (_) {},
              onSerialParityChanged: (value) => selectedParity = value,
              onSerialFlowControlChanged: (_) {},
              onSaveSerial: () {},
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Enlace con la balanza'));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('serial-Baud rate-dropdown')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('19200').last);
    await tester.pumpAndSettle();
    expect(selectedBaudRate, 19200);

    await tester.tap(find.byKey(const ValueKey('serial-Paridad-dropdown')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Par').last);
    await tester.pumpAndSettle();
    expect(selectedParity, 'even');
  });
}
