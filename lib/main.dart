import 'package:flutter/material.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  final notificationSettings =
      await FirebaseMessaging.instance.requestPermission(provisional: true);
  print('User granted permission: ${notificationSettings.authorizationStatus}');
  var token = await FirebaseMessaging.instance.getToken();
  print('Token: $token');
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Prender Led con Firebase',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.black),
        useMaterial3: true,
      ),
      home: const MyHomePage(title: 'Prende tu LED 🐣'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  BluetoothDevice? _connectedDevice;
  BluetoothCharacteristic? _characteristic;
  bool _ledStatus = false;
  bool _connecting =
      false; // Nuevo estado para controlar el proceso de conexión

  void _connect() async {
    setState(() {
      _connecting = true; // Iniciar el proceso de conexión
    });

    FlutterBluePlus.startScan(timeout: Duration(seconds: 5));

    var subscription = FlutterBluePlus.scanResults.listen((results) {
      for (ScanResult r in results) {
        if (r.device.name == 'BT04-A') {
          _connectToDevice(r.device);
          FlutterBluePlus.stopScan();
          break;
        }
      }
    });

    await Future.delayed(Duration(seconds: 5));
    subscription.cancel();
  }

  void _connectToDevice(BluetoothDevice device) async {
    try {
      await device.connect();
      List<BluetoothService> services = await device.discoverServices();
      for (var service in services) {
        for (var characteristic in service.characteristics) {
          if (characteristic.properties.write) {
            setState(() {
              _connectedDevice = device;
              _characteristic = characteristic;
              _connecting = false; // Finalizar el proceso de conexión
            });
            return;
          }
        }
      }
      _showConnectError(); // Mostrar mensaje de error si no se encontró característica de escritura
    } catch (e) {
      print('Error de conexión: $e');
      _showConnectError(); // Mostrar mensaje de error si hubo una excepción al conectar
    }
  }

  void _showConnectError() {
    setState(() {
      _connecting = false; // Finalizar el proceso de conexión
    });
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Error de Conexión'),
          content: Text('No se pudo conectar al dispositivo Bluetooth.'),
          actions: <Widget>[
            TextButton(
              child: Text('OK'),
              onPressed: () {
                Navigator.of(context).pop(); // Cerrar el AlertDialog
              },
            ),
          ],
        );
      },
    );
  }

  void _sendCommand(String command) async {
    if (_characteristic != null) {
      await _characteristic!.write(utf8.encode(command), withoutResponse: true);
      print('Comando enviado');
    } else {
      print('No se puede enviar el comando');
    }
  }

  void toggleLed(bool status) async {
    try {
      print('Status: $status');
      var url = Uri.parse('https://sendmessagefcm-amvvensafa-uc.a.run.app');

      var data = {
        "data": {"status": status ? "on" : "off"},
        "topic": "led_arduino"
      };

      var response = await http.post(
        url,
        headers: {"Content-Type": "application/json"},
        body: json.encode(data),
      );
      print('Response: ${response.body}');

      _sendCommand(status ? '1' : '0');
    } catch (e) {
      print('Error: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: Text(widget.title),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  _connectedDevice != null
                      ? Icons.circle
                      : Icons.circle_outlined,
                  color: _connectedDevice != null ? Colors.green : Colors.red,
                ),
                SizedBox(width: 10),
                Text(
                  _connectedDevice != null ? 'Conectado' : 'Desconectado',
                  style: TextStyle(fontSize: 18),
                ),
              ],
            ),
            SizedBox(height: 20),
            if (_connecting)
              CircularProgressIndicator() // Mostrar indicador de carga mientras se conecta
            else if (_connectedDevice == null)
              ElevatedButton.icon(
                onPressed: () {
                  _connect();
                },
                icon: Icon(Icons.bluetooth),
                label: Text('Conectar'),
              ),
            SizedBox(height: 20),
            GestureDetector(
              onTap: _connectedDevice != null
                  ? () {
                      setState(() {
                        _ledStatus = !_ledStatus;
                      });
                      toggleLed(_ledStatus);
                    }
                  : () {
                      _showConnectError(); // Mostrar mensaje de error al intentar encender el LED sin conexión
                    },
              child: Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  color: _connectedDevice != null
                      ? (_ledStatus ? Colors.red : Colors.grey)
                      : Colors.grey[400],
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Icon(
                    Icons.power_settings_new,
                    color: Colors.white,
                    size: 50,
                  ),
                ),
              ),
            ),
            Text(_ledStatus ? 'Encendido' : 'Apagado'),
          ],
        ),
      ),
    );
  }
}
