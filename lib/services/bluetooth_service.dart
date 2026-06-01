import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:permission_handler/permission_handler.dart';

class CoagBluetoothService {
  // Nordic UART Service (NUS) UUIDs
  static const String nusServiceUuid = "6e400001-b5a3-f393-e0a9-e50e24dcca9e";
  static const String nusRxUuid = "6e400002-b5a3-f393-e0a9-e50e24dcca9e"; // Write
  static const String nusTxUuid = "6e400003-b5a3-f393-e0a9-e50e24dcca9e"; // Notify

  BluetoothDevice? _connectedDevice;
  BluetoothCharacteristic? _rxCharacteristic; // Write
  BluetoothCharacteristic? _txCharacteristic; // Notify
  StreamSubscription<BluetoothConnectionState>? _connectionStateSubscription;
  StreamSubscription<List<int>>? _txSubscription;

  // Stream controller to broadcast parsed JSON objects received from the device
  final _dataStreamController = StreamController<Map<String, dynamic>>.broadcast();
  Stream<Map<String, dynamic>> get incomingDataStream => _dataStreamController.stream;

  // Buffer to handle split packets across BLE MTU chunks
  String _rxBuffer = "";

  BluetoothDevice? get connectedDevice => _connectedDevice;
  bool get isConnected => _connectedDevice != null && _rxCharacteristic != null;

  // Request Bluetooth permissions dynamically
  Future<bool> requestPermissions() async {
    if (Platform.isAndroid) {
      Map<Permission, PermissionStatus> statuses = await [
        Permission.bluetoothScan,
        Permission.bluetoothConnect,
        Permission.location,
      ].request();

      return statuses[Permission.bluetoothScan] == PermissionStatus.granted &&
             statuses[Permission.bluetoothConnect] == PermissionStatus.granted;
    }
    // iOS handles permissions via Info.plist and system prompt on scan
    return true;
  }

  // Scan for BLE devices
  Stream<List<ScanResult>> get scanResults => FlutterBluePlus.scanResults;

  Future<void> startScan() async {
    bool hasPermissions = await requestPermissions();
    if (!hasPermissions) {
      throw Exception("Bluetooth permissions not granted.");
    }

    // Ensure Bluetooth is enabled
    if (await FlutterBluePlus.adapterState.first != BluetoothAdapterState.on) {
      throw Exception("Bluetooth adapter is turned off.");
    }

    // Start scanning (filtering can be added, but showing all and identifying is better)
    await FlutterBluePlus.startScan(timeout: const Duration(seconds: 15));
  }

  Future<void> stopScan() async {
    await FlutterBluePlus.stopScan();
  }

  // Connect to a device
  Future<void> connect(BluetoothDevice device, {Function(BluetoothConnectionState)? onStateChanged}) async {
    await stopScan();
    
    _connectedDevice = device;

    // Listen to connection state updates
    _connectionStateSubscription?.cancel();
    _connectionStateSubscription = device.connectionState.listen((state) {
      if (state == BluetoothConnectionState.disconnected) {
        _cleanupConnection();
      }
      if (onStateChanged != null) {
        onStateChanged(state);
      }
    });

    try {
      await device.connect(autoConnect: false).timeout(const Duration(seconds: 10));
      
      // Discover services
      List<BluetoothService> services = await device.discoverServices();
      
      for (var service in services) {
        if (service.uuid.toString().toLowerCase() == nusServiceUuid) {
          for (var char in service.characteristics) {
            String charUuid = char.uuid.toString().toLowerCase();
            if (charUuid == nusRxUuid) {
              _rxCharacteristic = char;
            } else if (charUuid == nusTxUuid) {
              _txCharacteristic = char;
            }
          }
        }
      }

      if (_txCharacteristic == null || _rxCharacteristic == null) {
        throw Exception("Device does not support standard Coagulation Monitor BLE service.");
      }

      // Enable notifications on the TX Characteristic
      await _txCharacteristic!.setNotifyValue(true);
      
      _txSubscription?.cancel();
      _txSubscription = _txCharacteristic!.onValueReceived.listen((bytes) {
        _handleRawBytes(bytes);
      });

    } catch (e) {
      await disconnect();
      rethrow;
    }
  }

  // Write commands to ESP32
  Future<void> sendCommand(String command) async {
    if (_rxCharacteristic == null) {
      throw Exception("No connected device or write characteristic found.");
    }
    // Append newline to command so ESP32 knows when command ends
    String fullCommand = command.endsWith('\n') ? command : '$command\n';
    await _rxCharacteristic!.write(utf8.encode(fullCommand));
  }

  // Handle bytes received from BLE notifications, reassemble split lines, and parse JSON
  void _handleRawBytes(List<int> bytes) {
    String incomingStr = utf8.decode(bytes, allowMalformed: true);
    _rxBuffer += incomingStr;

    // Split the buffer by newlines to parse complete JSON lines
    while (_rxBuffer.contains('\n')) {
      int newlineIndex = _rxBuffer.indexOf('\n');
      String line = _rxBuffer.substring(0, newlineIndex).trim();
      _rxBuffer = _rxBuffer.substring(newlineIndex + 1);

      if (line.isNotEmpty) {
        try {
          Map<String, dynamic> parsedJson = json.decode(line);
          _dataStreamController.add(parsedJson);
        } catch (e) {
          // Log parsing error or ignore malformed lines
          print("BLE JSON Parsing Error: $e, line: '$line'");
        }
      }
    }
  }

  // Disconnect device
  Future<void> disconnect() async {
    if (_connectedDevice != null) {
      try {
        await _connectedDevice!.disconnect();
      } catch (_) {}
    }
    _cleanupConnection();
  }

  // Reset variables upon disconnection
  void _cleanupConnection() {
    _txSubscription?.cancel();
    _txSubscription = null;
    _connectionStateSubscription?.cancel();
    _connectionStateSubscription = null;
    _rxCharacteristic = null;
    _txCharacteristic = null;
    _connectedDevice = null;
    _rxBuffer = "";
  }

  void dispose() {
    _dataStreamController.close();
    _cleanupConnection();
  }
}
