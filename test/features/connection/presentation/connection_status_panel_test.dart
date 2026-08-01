import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pondera/features/connection/presentation/connection_status_panel.dart';

void main() {
  testWidgets('muestra en rojo un rechazo aunque la balanza siga conectada', (
    tester,
  ) async {
    const message = 'Peso fuera del rango permitido. No se registró.';
    final colorScheme = ColorScheme.fromSeed(seedColor: Colors.blue);

    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(colorScheme: colorScheme),
        home: Scaffold(
          body: ConnectionStatusPanel(
            activeDeviceLabel: 'Ethernet 192.168.100.130:3004',
            uiStatusMessage: message,
            isConnected: true,
            isInteractionBlocked: false,
            isError: true,
            onToggleConnection: () {},
          ),
        ),
      ),
    );

    final text = tester.widget<Text>(find.text(message));
    expect(text.style?.color, colorScheme.error);
  });
}
