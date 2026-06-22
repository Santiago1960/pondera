import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pondera/app/app_theme.dart';
import 'package:pondera/features/scale_reading/presentation/raw_data_log_panel.dart';

void main() {
  Widget buildPanel({
    required List<RawDataLogEntry> entries,
    int receptionSequence = 0,
  }) {
    return MaterialApp(
      theme: buildPonderaTheme(Brightness.light),
      home: Scaffold(
        body: RawDataLogPanel(
          entries: entries,
          receptionSequence: receptionSequence,
        ),
      ),
    );
  }

  testWidgets('muestra el estado vacío', (tester) async {
    await tester.pumpWidget(buildPanel(entries: const []));

    expect(find.text('Última trama recibida'), findsOneWidget);
    expect(find.text('Sin datos'), findsOneWidget);
    expect(find.text('Esperando datos de la balanza...'), findsOneWidget);
  });

  testWidgets('muestra la última trama y despliega las dos anteriores', (
    tester,
  ) async {
    final entries = [
      RawDataLogEntry(
        rawData: 'trama uno\r\n',
        receivedAt: DateTime(2026, 6, 20, 12, 0, 1),
      ),
      RawDataLogEntry(
        rawData: 'trama dos',
        receivedAt: DateTime(2026, 6, 20, 12, 0, 2),
      ),
      RawDataLogEntry(
        rawData: 'trama tres',
        receivedAt: DateTime(2026, 6, 20, 12, 0, 3),
      ),
    ];

    await tester.pumpWidget(buildPanel(entries: entries, receptionSequence: 3));

    expect(find.text('trama tres'), findsOneWidget);
    expect(find.text('Recibida 12:00:03'), findsOneWidget);
    expect(find.text('Ver 2 tramas anteriores'), findsOneWidget);
    expect(find.text(r'trama uno\r\n'), findsNothing);
    expect(find.text('trama dos'), findsNothing);

    await tester.tap(find.text('Ver 2 tramas anteriores'));
    await tester.pumpAndSettle();

    expect(find.text(r'trama uno\r\n'), findsOneWidget);
    expect(find.text('trama dos'), findsOneWidget);
    expect(find.text('12:00:01'), findsOneWidget);
    expect(find.text('12:00:02'), findsOneWidget);
  });
}
