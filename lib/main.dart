import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Pondera Piloto',
      theme: ThemeData(
        brightness: Brightness.dark,
        primarySwatch: Colors.blue,
      ),
      home: const MainScreen(),
    );
  }
}

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  // Configuración de red del indicador GI-410
  final String _ipAddress = '192.168.100.134';
  final int _port = 3004;

  // URL del Webhook de test en n8n
  final String _n8nUrl = 'https://n8n.bitgenial.com/webhook-test/pondera-recipe';

  Socket? _socket;
  bool _isConnected = false;
  bool _isReconnecting = false;
  String _statusMessage = 'Desconectado';
  
  // Lista para acumular las últimas tramas de texto recibidas
  final List<String> _receivedDataLog = [];

  // Variables para persistencia y limpieza de tramas
  String _savedRegex = '';
  String _cleanWeightDisplay = 'Sin receta';
  late SharedPreferences _prefs;

  @override
  void initState() {
    super.initState();
    _initSharedPreferences();
  }

  // Inicializa el almacenamiento local de la Mac
  void _initSharedPreferences() async {
    _prefs = await SharedPreferences.getInstance();
    setState(() {
      _savedRegex = _prefs.getString('pondera_recipe') ?? '';
      if (_savedRegex.isNotEmpty) {
        _cleanWeightDisplay = '---';
      }
    });
  }

    // Envía la última trama capturada a tu servidor n8n
  void _sendToN8nIa() async {
    if (_receivedDataLog.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Primero captura al menos una trama en bruto del indicador.')),
      );
      return;
    }

    // Tomamos la última ráfaga real de la báscula
    String rawData = _receivedDataLog.last;
    
    // Lo que el usuario ve en la pantalla física
    String expectedValue = "0.130"; 

    setState(() {
      _statusMessage = 'Enviando muestra a n8n...';
    });

    try {
      final response = await http.post(
        Uri.parse(_n8nUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'trama': rawData,
          'valor_esperado': expectedValue,
        }),
      );

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);
        String newRegex = responseData['regex_pattern'] ?? '';

        if (newRegex.isNotEmpty) {
          await _prefs.setString('pondera_recipe', newRegex);
          
          setState(() {
            _savedRegex = newRegex;
            _statusMessage = '¡Receta Regex guardada con éxito!';
            
            // AUTO-REFRESCO: Evaluamos la nueva receta inmediatamente 
            // sobre la trama actual para evitar que la UI se quede bloqueada
            final regExp = RegExp(_savedRegex);
            final match = regExp.firstMatch(rawData);
            if (match != null) {
              _cleanWeightDisplay = match.group(0) ?? '---';
            } else {
              _cleanWeightDisplay = '---';
            }
          });
        } else {
          setState(() {
            _statusMessage = 'n8n respondió pero no envió la llave regex_pattern';
          });
        }
      } else {
        setState(() {
          _statusMessage = 'Error en n8n. Estado: ${response.statusCode}';
        });
      }
    } catch (e) {
      setState(() {
        _statusMessage = 'Error de conexión con n8n: $e';
      });
    }
  }

  // Borra la receta de la memoria local
  void _clearRecipe() async {
    await _prefs.remove('pondera_recipe');
    setState(() {
      _savedRegex = '';
      _cleanWeightDisplay = 'Sin receta';
      _statusMessage = 'Receta eliminada.';
    });
  }

  String _socketBuffer = '';
  DateTime _lastDataTime = DateTime.now();
  
  void _connectToIndicator() async {
    if (_isReconnecting) return;

    setState(() {
      _statusMessage = 'Conectando a $_ipAddress:$_port...';
    });

    try {
      _socket?.destroy();
      _socket = null;

      _socket = await Socket.connect(_ipAddress, _port, timeout: const Duration(seconds: 4));
      
      _socket!.setOption(SocketOption.tcpNoDelay, true);
      _socket!.setRawOption(RawSocketOption.fromInt(0xFFFF, 0x0004, 1));

      setState(() {
        _isConnected = true;
        _isReconnecting = false;
        _statusMessage = '¡Conectado exitosamente!';
        _lastDataTime = DateTime.now();
      });

      _socket!.listen(
        (List<int> data) {
          try {
            _lastDataTime = DateTime.now(); // Registramos actividad real viva
            
            _socketBuffer += utf8.decode(data, allowMalformed: true);
            
            if (_socketBuffer.contains('\n') || _socketBuffer.contains('\r') || _socketBuffer.length > 60) {
              String incomingText = _socketBuffer;
              _socketBuffer = '';

              setState(() {
                _receivedDataLog.add(incomingText);
                if (_receivedDataLog.length > 15) {
                  _receivedDataLog.removeAt(0);
                }

                if (_savedRegex.isNotEmpty) {
                  final regExp = RegExp(_savedRegex);
                  final match = regExp.firstMatch(incomingText);
                  
                  if (match != null) {
                    _cleanWeightDisplay = match.group(0) ?? '---';
                  }
                } else {
                  _cleanWeightDisplay = 'Sin receta';
                }
              });
            }
          } catch (e) {
            print('Error al decodificar buffer: $e');
          }
        },
        onError: (error) {
          _handleDisconnection('Error de señal: $error');
        },
        onDone: () {
          _handleDisconnection('Puerto cerrado por el indicador.');
        },
        cancelOnError: false,
      );

      // GUARDIÁN RELAJADO (Heartbeat Industrial):
      // Monitorea en segundo plano, pero solo interviene si hay SILENCIO TOTAL por 10 segundos.
      Future.doWhile(() async {
        await Future.delayed(const Duration(seconds: 2));
        if (!_isConnected) return false; 
        
        // Calculamos la inactividad en milisegundos para precisión total
        final msSinceLastData = DateTime.now().difference(_lastDataTime).inMilliseconds;
        
        if (msSinceLastData >= 10000) { // 10 segundos libres de falsos positivos
          print('Caída real detectada (Sin datos por ${msSinceLastData / 1000}s). Reiniciando...');
          _handleDisconnection('Flujo interrumpido');
          return false;
        }
        return true;
      });

    } catch (e) {
      _handleDisconnection('No se pudo conectar: $e');
    }
  }

  void _handleDisconnection(String reason) {
    if (_isReconnecting) return;
    _socket?.destroy();
    _socket = null;

    setState(() {
      _isConnected = false;
      _isReconnecting = true;
      _statusMessage = '$reason. Reintentando...';
    });

    Future.delayed(const Duration(seconds: 3), () {
      if (_isReconnecting && !_isConnected) {
        _isReconnecting = false;
        _connectToIndicator();
      }
    });
  }

  void _disconnect(String message) {
    _socket?.destroy();
    setState(() {
      _isConnected = false;
      _statusMessage = message;
    });
  }

  @override
  void dispose() {
    _socket?.destroy();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Pondera - Piloto de Red + n8n'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Caja superior de peso limpio filtrado
            Card(
              color: Colors.blueGrey.shade900,
              child: Padding(
                padding: const EdgeInsets.all(15.0),
                child: Column(
                  children: [
                    const Text('PESO LIMPIO FILTRADO LOCALMENTE', style: TextStyle(fontSize: 12, color: Colors.blueAccent, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 5),
                    Text(
                      _cleanWeightDisplay,
                      style: const TextStyle(fontSize: 36, fontWeight: FontWeight.bold, color: Colors.amberAccent),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 10),
            // Panel de Control e integración
            Card(
              child: Padding(
                padding: const EdgeInsets.all(15.0),
                child: Column(
                  children: [
                    Text('Dispositivo: $_ipAddress:$_port', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 5),
                    Text('Estado: $_statusMessage', style: TextStyle(color: _isConnected ? Colors.green : Colors.orange, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 15),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        ElevatedButton(
                          onPressed: _isConnected ? () => _disconnect('Desconectado') : _connectToIndicator,
                          style: ElevatedButton.styleFrom(backgroundColor: _isConnected ? Colors.red.shade700 : Colors.blue.shade700),
                          child: Text(_isConnected ? 'Desconectar' : 'Conectar GI-400'),
                        ),
                        ElevatedButton(
                          onPressed: _sendToN8nIa,
                          style: ElevatedButton.styleFrom(backgroundColor: Colors.purple.shade700),
                          child: const Text('Enviar Trama a n8n'),
                        ),
                        if (_savedRegex.isNotEmpty)
                          TextButton(
                            onPressed: _clearRecipe,
                            child: const Text('Limpiar Receta', style: TextStyle(color: Colors.red)),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 10),
            Text(
              _savedRegex.isEmpty ? 'Receta Regex activa: Ninguna' : 'Receta Regex activa: $_savedRegex',
              style: TextStyle(color: _savedRegex.isEmpty ? Colors.redAccent : Colors.greenAccent, fontStyle: FontStyle.italic, fontSize: 12),
            ),
            const SizedBox(height: 15),
            const Text('Tramas recibidas en bruto (Data Log):', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: Colors.black87, borderRadius: BorderRadius.circular(5), border: Border.all(color: Colors.grey.shade800)),
                child: _receivedDataLog.isEmpty
                    ? const Center(child: Text('Esperando datos de la balanza...'))
                    : ListView.builder(
                        reverse: true,
                        itemCount: _receivedDataLog.length,
                        itemBuilder: (context, index) {
                          final text = _receivedDataLog[_receivedDataLog.length - 1 - index];
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 2.0),
                            child: Text(
                              text.replaceAll('\r', '\\r').replaceAll('\n', '\\n'),
                              style: const TextStyle(fontFamily: 'Courier', color: Colors.greenAccent),
                            ),
                          );
                        },
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}