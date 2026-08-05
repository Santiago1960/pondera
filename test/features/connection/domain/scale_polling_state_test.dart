import 'package:flutter_test/flutter_test.dart';
import 'package:pondera/features/connection/domain/scale_polling_state.dart';

void main() {
  final start = DateTime.utc(2026, 8, 3);

  test('mantiene una sola consulta pendiente hasta recibir respuesta', () {
    final state = ScalePollingState(
      responseTimeout: const Duration(seconds: 2),
    );

    expect(state.beginRequest(start), isTrue);
    expect(
      state.beginRequest(start.add(const Duration(milliseconds: 500))),
      isFalse,
    );

    state.completeResponse();

    expect(
      state.beginRequest(start.add(const Duration(milliseconds: 501))),
      isTrue,
    );
  });

  test('detecta la falta de respuesta y permite reiniciar el ciclo', () {
    final state = ScalePollingState(
      responseTimeout: const Duration(seconds: 2),
    );
    state.beginRequest(start);

    expect(
      state.hasTimedOut(start.add(const Duration(milliseconds: 1999))),
      isFalse,
    );
    expect(state.hasTimedOut(start.add(const Duration(seconds: 2))), isTrue);

    state.reset();

    expect(state.waitingForResponse, isFalse);
    expect(state.beginRequest(start.add(const Duration(seconds: 2))), isTrue);
  });

  test('permite consultas periódicas cuando no exige respuesta', () {
    final state = ScalePollingState(
      responseTimeout: const Duration(seconds: 2),
    );

    expect(state.beginRequest(start), isTrue);
    expect(
      state.beginRequest(
        start.add(const Duration(milliseconds: 500)),
        trackResponse: false,
      ),
      isTrue,
    );
    expect(state.waitingForResponse, isFalse);
  });
}
