import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/measurement_result.dart';
import '../services/bluetooth_service.dart';
import '../services/simulation_service.dart';

class CoagulationManager extends ChangeNotifier {
  final CoagBluetoothService _bleService = CoagBluetoothService();
  final SimulationService _simService = SimulationService();

  // Settings
  bool _isSimulationMode = true;

  // Whether BLE is available on this platform
  bool get isBleSupported => !kIsWeb;

  // Bluetooth variables
  BluetoothConnectionState _connectionState = BluetoothConnectionState.disconnected;
  List<ScanResult> _scannedDevices = [];
  bool _isScanning = false;
  StreamSubscription<List<ScanResult>>? _scanSubscription;
  StreamSubscription<BluetoothAdapterState>? _adapterStateSubscription;
  BluetoothAdapterState _adapterState = BluetoothAdapterState.unknown;

  // Active measurement variables
  String _measurementState = "idle"; // idle, heating, insertStrip, applyBlood, measuring, completed, error
  double _currentTemp = 24.5;
  double _elapsedSeconds = 0.0;
  double _currentSensorValue = 0.0;
  double? _finalPT;
  double? _finalINR;
  List<double> _curvePoints = [];
  String _errorMessage = "";

  // Streams subscriptions
  StreamSubscription<Map<String, dynamic>>? _bleDataSubscription;
  StreamSubscription<Map<String, dynamic>>? _simDataSubscription;

  // Persistent History
  List<MeasurementResult> _history = [];

  // Getters
  bool get isSimulationMode => _isSimulationMode;
  BluetoothConnectionState get connectionState => _connectionState;
  BluetoothAdapterState get adapterState => _adapterState;
  List<ScanResult> get scannedDevices => _scannedDevices;
  bool get isScanning => _isScanning;
  String get measurementState => _measurementState;
  double get currentTemp => _currentTemp;
  double get elapsedSeconds => _elapsedSeconds;
  double get currentSensorValue => _currentSensorValue;
  double? get finalPT => _finalPT;
  double? get finalINR => _finalINR;
  List<double> get curvePoints => _curvePoints;
  List<MeasurementResult> get history => _history;
  String get errorMessage => _errorMessage;
  BluetoothDevice? get connectedDevice => _bleService.connectedDevice;

  CoagulationManager() {
    _init();
  }

  Future<void> _init() async {
    await loadHistory();

    // Only set up BLE listeners on platforms that support it (Android/iOS)
    if (isBleSupported) {
      // Listen to BLE adapter state changes
      _adapterStateSubscription = FlutterBluePlus.adapterState.listen((state) {
        _adapterState = state;
        notifyListeners();
      });

      // Listen to BLE scan results
      _scanSubscription = _bleService.scanResults.listen((results) {
        _scannedDevices = results;
        notifyListeners();
      });
    } else {
      // Force simulation mode on unsupported platforms (web)
      _isSimulationMode = true;
    }

    // Wire up telemetry data handlers
    _setupDataSubscriptions();
  }

  void toggleSimulationMode(bool enabled) {
    // Prevent switching to BLE mode on unsupported platforms
    if (!enabled && !isBleSupported) {
      _errorMessage = "Bluetooth is not supported on this platform. Please run the app on an Android device.";
      _measurementState = "error";
      notifyListeners();
      return;
    }

    if (_isSimulationMode == enabled) return;
    _isSimulationMode = enabled;
    resetMeasurement();
    
    if (!_isSimulationMode) {
      // Disconnect simulation, scan/prepare BLE
      _simService.stopSimulation();
    } else {
      // Disconnect BLE if connected
      _bleService.disconnect();
      _connectionState = BluetoothConnectionState.disconnected;
    }
    notifyListeners();
  }

  void _setupDataSubscriptions() {
    _bleDataSubscription?.cancel();
    _bleDataSubscription = _bleService.incomingDataStream.listen((data) {
      if (!_isSimulationMode) {
        _handleIncomingTelemetry(data);
      }
    });

    _simDataSubscription?.cancel();
    _simDataSubscription = _simService.stream.listen((data) {
      if (_isSimulationMode) {
        _handleIncomingTelemetry(data);
      }
    });
  }

  // Common parser for JSON packets from BLE or Simulator
  void _handleIncomingTelemetry(Map<String, dynamic> data) {
    final type = data['type'] as String?;
    
    if (type == 'status') {
      _measurementState = data['state'] ?? 'idle';
      if (data['temp'] != null) {
        _currentTemp = (data['temp'] as num).toDouble();
      }
      notifyListeners();
    } 
    else if (type == 'data') {
      _measurementState = "measuring";
      if (data['time'] != null) {
        _elapsedSeconds = (data['time'] as num).toDouble();
      }
      if (data['value'] != null) {
        _currentSensorValue = (data['value'] as num).toDouble();
        _curvePoints.add(_currentSensorValue);
      }
      if (data['temp'] != null) {
        _currentTemp = (data['temp'] as num).toDouble();
      }
      notifyListeners();
    } 
    else if (type == 'result') {
      _measurementState = "completed";
      _finalPT = (data['pt'] as num).toDouble();
      _finalINR = (data['inr'] as num).toDouble();
      if (data['temp'] != null) {
        _currentTemp = (data['temp'] as num).toDouble();
      }
      
      // Auto-save the completed measurement
      _autoSaveCompletedResult();
      notifyListeners();
    } 
    else if (type == 'error') {
      _measurementState = "error";
      _errorMessage = data['message'] ?? "An unknown device error occurred.";
      notifyListeners();
    }
  }

  // --- Bluetooth Controls ---
  
  Future<void> startBleScan() async {
    if (!isBleSupported) {
      _errorMessage = "Bluetooth is not available on this platform.";
      _measurementState = "error";
      notifyListeners();
      return;
    }

    // Check if Bluetooth adapter is on; if off, try to turn it on (Android only)
    try {
      BluetoothAdapterState currentState = await FlutterBluePlus.adapterState.first;
      if (currentState != BluetoothAdapterState.on) {
        // On Android, attempt to request the user to turn on Bluetooth
        await FlutterBluePlus.turnOn();
        // Wait briefly for adapter state to update
        await Future.delayed(const Duration(seconds: 2));
        currentState = await FlutterBluePlus.adapterState.first;
        if (currentState != BluetoothAdapterState.on) {
          _errorMessage = "Please turn on Bluetooth to scan for devices.";
          _measurementState = "error";
          notifyListeners();
          return;
        }
      }
    } catch (e) {
      // turnOn() may throw on iOS — that's OK, we just prompt the user
      _errorMessage = "Please enable Bluetooth in your device settings.";
      _measurementState = "error";
      notifyListeners();
      return;
    }

    _scannedDevices.clear();
    _isScanning = true;
    _errorMessage = "";
    _measurementState = "idle";
    notifyListeners();

    try {
      await _bleService.startScan();
    } catch (e) {
      _isScanning = false;
      _measurementState = "error";
      _errorMessage = e.toString();
      notifyListeners();
    }

    // Scanning auto-stops after timeout (15s), update state
    Future.delayed(const Duration(seconds: 16), () {
      if (_isScanning) {
        _isScanning = false;
        notifyListeners();
      }
    });
  }

  Future<void> stopBleScan() async {
    await _bleService.stopScan();
    _isScanning = false;
    notifyListeners();
  }

  Future<void> connectDevice(BluetoothDevice device) async {
    _measurementState = "idle";
    _errorMessage = "";
    notifyListeners();

    try {
      await _bleService.connect(device, onStateChanged: (state) {
        _connectionState = state;
        if (state == BluetoothConnectionState.disconnected) {
          resetMeasurement();
        }
        notifyListeners();
      });
      _connectionState = BluetoothConnectionState.connected;
      notifyListeners();
    } catch (e) {
      _connectionState = BluetoothConnectionState.disconnected;
      _measurementState = "error";
      _errorMessage = "Connection failed: ${e.toString().replaceAll('Exception: ', '')}";
      notifyListeners();
    }
  }

  Future<void> disconnectDevice() async {
    await _bleService.disconnect();
    _connectionState = BluetoothConnectionState.disconnected;
    resetMeasurement();
    notifyListeners();
  }

  // --- Measurement Controls ---

  void startMeasurement() {
    resetMeasurement();
    
    if (_isSimulationMode) {
      _measurementState = "heating";
      _simService.startSimulation();
    } else {
      if (!(_bleService.isConnected)) {
        _measurementState = "error";
        _errorMessage = "No device connected. Please connect your coagulation monitor.";
        notifyListeners();
        return;
      }
      // Send start command to ESP32
      _bleService.sendCommand("START");
    }
    notifyListeners();
  }

  // Trigger manually (used in simulation dashboard controls)
  void insertStrip() {
    if (_isSimulationMode) {
      _simService.triggerStripInserted();
    } else {
      _bleService.sendCommand("STRIP_INSERTED");
    }
  }

  void applyBlood() {
    if (_isSimulationMode) {
      _simService.triggerBloodApplied();
    } else {
      _bleService.sendCommand("BLOOD_APPLIED");
    }
  }

  void resetMeasurement() {
    _measurementState = "idle";
    _currentTemp = 24.5;
    _elapsedSeconds = 0.0;
    _currentSensorValue = 0.0;
    _finalPT = null;
    _finalINR = null;
    _curvePoints.clear();
    _errorMessage = "";
    
    if (_isSimulationMode) {
      _simService.stopSimulation();
    } else if (_bleService.isConnected) {
      _bleService.sendCommand("RESET");
    }
    notifyListeners();
  }

  // --- Local Database / History storage ---

  Future<void> loadHistory() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final historyList = prefs.getStringList('coag_history') ?? [];
      
      _history = historyList
          .map((item) => MeasurementResult.fromJson(item))
          .toList();
      
      // Sort history by date descending
      _history.sort((a, b) => b.timestamp.compareTo(a.timestamp));
      notifyListeners();
    } catch (e) {
      print("Error loading history: $e");
    }
  }

  Future<void> _autoSaveCompletedResult() async {
    if (_finalPT == null || _finalINR == null) return;

    final newResult = MeasurementResult(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      timestamp: DateTime.now(),
      pt: _finalPT!,
      inr: _finalINR!,
      averageTemperature: _currentTemp,
      curvePoints: List<double>.from(_curvePoints),
    );

    _history.insert(0, newResult);
    
    try {
      final prefs = await SharedPreferences.getInstance();
      final historyList = _history.map((item) => item.toJson()).toList();
      await prefs.setStringList('coag_history', historyList);
    } catch (e) {
      print("Error saving history: $e");
    }
  }

  Future<void> deleteHistoryItem(String id) async {
    _history.removeWhere((item) => item.id == id);
    
    try {
      final prefs = await SharedPreferences.getInstance();
      final historyList = _history.map((item) => item.toJson()).toList();
      await prefs.setStringList('coag_history', historyList);
      notifyListeners();
    } catch (e) {
      print("Error deleting item: $e");
    }
  }

  Future<void> clearHistory() async {
    _history.clear();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('coag_history');
      notifyListeners();
    } catch (e) {
      print("Error clearing history: $e");
    }
  }

  @override
  void dispose() {
    _adapterStateSubscription?.cancel();
    _scanSubscription?.cancel();
    _bleDataSubscription?.cancel();
    _simDataSubscription?.cancel();
    _bleService.dispose();
    _simService.dispose();
    super.dispose();
  }
}
