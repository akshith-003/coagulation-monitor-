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

  // --- Settings ---
  bool _isSimulationMode = true;
  bool get isBleSupported => !kIsWeb;

  // --- BLE State ---
  BluetoothConnectionState _connectionState = BluetoothConnectionState.disconnected;
  List<ScanResult> _scannedDevices = [];
  bool _isScanning = false;
  StreamSubscription<List<ScanResult>>? _scanSubscription;
  StreamSubscription<BluetoothAdapterState>? _adapterStateSubscription;
  BluetoothAdapterState _adapterState = BluetoothAdapterState.unknown;

  // --- Measurement Stage ---
  // Stages: idle | baseline | inflating | occlusion | analysis | done | error
  String _measurementStage = 'idle';
  double _stageRemainingSeconds = 0.0;
  bool _isMeasuring = false;

  // --- Live Sensor Values (updated at 10Hz) ---
  int _adcRaw = 1847;
  double _dcIntensity = 1.84;
  double _pressureMmhg = 0.0;
  double _skinTempC = 32.4;
  double _gammaHz = 0.0;
  double _peakPressureMmhg = 0.0;

  // --- Data Collections (for live graphs) ---
  /// Rolling ADC points for raw photodiode graph (last 5s at 10Hz = 50 points)
  final List<double> _adcPoints = [];
  /// Gamma decay points for full occlusion window (0-20s at 10Hz = 200 points)
  final List<double> _gammaPoints = [];
  /// Time axis for gamma points (seconds since occlusion start)
  double _occlusionElapsedSeconds = 0.0;
  /// Detected asymptote (Hz) — shown as dashed line after ~12s
  double? _gammaAsymptote;

  // --- Results ---
  DlsMeasurementResult? _lastResult;

  // --- Error ---
  String _errorMessage = '';

  // --- History ---
  List<DlsMeasurementResult> _history = [];
  int _nextMeasurementIndex = 1;

  // --- Streams ---
  StreamSubscription<Map<String, dynamic>>? _bleDataSubscription;
  StreamSubscription<Map<String, dynamic>>? _simDataSubscription;

  // --- Getters ---
  bool get isSimulationMode => _isSimulationMode;
  BluetoothConnectionState get connectionState => _connectionState;
  BluetoothAdapterState get adapterState => _adapterState;
  List<ScanResult> get scannedDevices => _scannedDevices;
  bool get isScanning => _isScanning;
  bool get isMeasuring => _isMeasuring;
  String get measurementStage => _measurementStage;
  double get stageRemainingSeconds => _stageRemainingSeconds;

  // Live sensors
  int get adcRaw => _adcRaw;
  double get dcIntensity => _dcIntensity;
  double get pressureMmhg => _pressureMmhg;
  double get skinTempC => _skinTempC;
  double get gammaHz => _gammaHz;
  double get peakPressureMmhg => _peakPressureMmhg;

  // Signal quality based on DC intensity
  String get signalQuality {
    if (_dcIntensity > 1.5) return 'GOOD';
    if (_dcIntensity >= 0.8) return 'WEAK';
    return 'POOR';
  }

  // Graph data
  List<double> get adcPoints => List.unmodifiable(_adcPoints);
  List<double> get gammaPoints => List.unmodifiable(_gammaPoints);
  double get occlusionElapsedSeconds => _occlusionElapsedSeconds;
  double? get gammaAsymptote => _gammaAsymptote;

  // Results
  DlsMeasurementResult? get lastResult => _lastResult;
  String get errorMessage => _errorMessage;
  List<DlsMeasurementResult> get history => List.unmodifiable(_history);
  BluetoothDevice? get connectedDevice => _bleService.connectedDevice;

  // Compatibility getters used by dashboard (legacy) - now just aliases
  String get measurementState => _measurementStage;
  double get currentTemp => _skinTempC;
  double get elapsedSeconds => _occlusionElapsedSeconds;
  double get currentSensorValue => _gammaHz;
  List<double> get curvePoints => _gammaPoints;

  CoagulationManager() {
    _init();
  }

  Future<void> _init() async {
    await _loadHistory();

    if (isBleSupported) {
      _adapterStateSubscription = FlutterBluePlus.adapterState.listen((state) {
        _adapterState = state;
        notifyListeners();
      });

      _scanSubscription = _bleService.scanResults.listen((results) {
        _scannedDevices = results;
        notifyListeners();
      });
    } else {
      _isSimulationMode = true;
    }

    _setupDataSubscriptions();
  }

  void toggleSimulationMode(bool enabled) {
    if (!enabled && !isBleSupported) {
      _errorMessage = 'Bluetooth is not supported on this platform.';
      _measurementStage = 'error';
      notifyListeners();
      return;
    }
    if (_isSimulationMode == enabled) return;
    _isSimulationMode = enabled;
    resetMeasurement();
    if (!_isSimulationMode) {
      _simService.stopSimulation();
    } else {
      _bleService.disconnect();
      _connectionState = BluetoothConnectionState.disconnected;
    }
    notifyListeners();
  }

  void _setupDataSubscriptions() {
    _bleDataSubscription?.cancel();
    _bleDataSubscription = _bleService.incomingDataStream.listen((data) {
      if (!_isSimulationMode) _handlePacket(data);
    });

    _simDataSubscription?.cancel();
    _simDataSubscription = _simService.stream.listen((data) {
      if (_isSimulationMode) _handlePacket(data);
    });
  }

  /// Parse incoming data packet (from BLE or Simulator)
  void _handlePacket(Map<String, dynamic> data) {
    // Check if this is a result packet
    if (data['type'] == 'result') {
      _handleResultPacket(data);
      return;
    }

    // Live telemetry packet
    final stageStr = (data['stage'] as String? ?? '').toLowerCase();
    if (stageStr.isNotEmpty && stageStr != _measurementStage) {
      _measurementStage = stageStr;
    }

    if (data['adc_raw'] != null) {
      _adcRaw = (data['adc_raw'] as num).toInt();
      // Rolling 5s window: 50 points at 10Hz
      _adcPoints.add(_adcRaw.toDouble());
      if (_adcPoints.length > 50) _adcPoints.removeAt(0);
    }

    if (data['dc_intensity'] != null) {
      _dcIntensity = (data['dc_intensity'] as num).toDouble();
    }

    if (data['gamma'] != null) {
      _gammaHz = (data['gamma'] as num).toDouble();
      if (_measurementStage == 'occlusion') {
        _gammaPoints.add(_gammaHz);
        _occlusionElapsedSeconds = _gammaPoints.length * 0.1;
        // Detect asymptote after 12s (120 points)
        if (_gammaPoints.length >= 120) {
          // Asymptote = average of last 20 points
          final last20 = _gammaPoints.sublist(_gammaPoints.length - 20);
          _gammaAsymptote = last20.reduce((a, b) => a + b) / 20;
        }
      }
    }

    if (data['pressure_mmhg'] != null) {
      _pressureMmhg = (data['pressure_mmhg'] as num).toDouble();
      if (_pressureMmhg > _peakPressureMmhg) _peakPressureMmhg = _pressureMmhg;
    }

    if (data['temp_c'] != null) {
      _skinTempC = (data['temp_c'] as num).toDouble();
    }

    if (data['stage_remaining_ms'] != null) {
      _stageRemainingSeconds = (data['stage_remaining_ms'] as num).toDouble() / 1000.0;
    }

    notifyListeners();
  }

  void _handleResultPacket(Map<String, dynamic> data) {
    _measurementStage = 'done';
    _isMeasuring = false;

    // Use asymptote detected live, or fallback to packet value
    final gammaAsymptote = _gammaAsymptote ??
        (data['gamma_asymptote'] as num?)?.toDouble() ?? 22.0;
    final gammaInitial = (data['gamma_initial'] as num?)?.toDouble() ?? _gammaHz;
    final gammaDrop = gammaInitial - gammaAsymptote;

    _lastResult = DlsMeasurementResult(
      id: _generateId(),
      timestamp: DateTime.now(),
      gammaInitial: gammaInitial,
      gammaAsymptote: gammaAsymptote,
      gammaDrop: gammaDrop,
      decayRate: (data['decay_rate'] as num?)?.toDouble() ?? (gammaDrop / 20.0),
      sMobility: (data['s_mobility'] as num?)?.toDouble() ?? 240.0,
      decayShape: data['decay_shape'] ?? 'MODERATE',
      dcIntensity: _dcIntensity,
      skinTempC: _skinTempC,
      peakPressureMmhg: _peakPressureMmhg,
      signalQuality: signalQuality,
      durationSeconds: (data['duration_s'] as num?)?.toDouble() ?? _occlusionElapsedSeconds,
      adcRawPoints: List<double>.from(_adcPoints),
      gammaPoints: List<double>.from(_gammaPoints),
    );

    notifyListeners();
  }

  // --- BLE Controls ---

  Future<void> startBleScan() async {
    if (!isBleSupported) return;
    try {
      final state = await FlutterBluePlus.adapterState.first;
      if (state != BluetoothAdapterState.on) {
        await FlutterBluePlus.turnOn();
        await Future.delayed(const Duration(seconds: 2));
      }
    } catch (_) {}

    _scannedDevices.clear();
    _isScanning = true;
    notifyListeners();

    try {
      await _bleService.startScan();
    } catch (e) {
      _isScanning = false;
      _measurementStage = 'error';
      _errorMessage = e.toString();
      notifyListeners();
    }

    Future.delayed(const Duration(seconds: 16), () {
      if (_isScanning) {
        _isScanning = false;
        notifyListeners();
      }
    });
  }

  Future<void> connectDevice(BluetoothDevice device) async {
    try {
      await _bleService.connect(device, onStateChanged: (state) {
        _connectionState = state;
        if (state == BluetoothConnectionState.disconnected) resetMeasurement();
        notifyListeners();
      });
      _connectionState = BluetoothConnectionState.connected;
      notifyListeners();
    } catch (e) {
      _connectionState = BluetoothConnectionState.disconnected;
      _measurementStage = 'error';
      _errorMessage = 'Connection failed: ${e.toString().replaceAll('Exception: ', '')}';
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
    _isMeasuring = true;
    _lastResult = null;

    if (_isSimulationMode) {
      _measurementStage = 'baseline';
      _simService.startSimulation();
    } else {
      if (!_bleService.isConnected) {
        _measurementStage = 'error';
        _errorMessage = 'No device connected. Please connect your coagulation monitor.';
        _isMeasuring = false;
        notifyListeners();
        return;
      }
      _measurementStage = 'baseline';
      _bleService.sendCommand('START');
    }
    notifyListeners();
  }

  void abortMeasurement() {
    _simService.stopSimulation();
    if (_bleService.isConnected) _bleService.sendCommand('ABORT');
    resetMeasurement();
  }

  void resetMeasurement() {
    _measurementStage = 'idle';
    _isMeasuring = false;
    _stageRemainingSeconds = 0.0;
    _adcPoints.clear();
    _gammaPoints.clear();
    _gammaHz = 0.0;
    _pressureMmhg = 0.0;
    _peakPressureMmhg = 0.0;
    _occlusionElapsedSeconds = 0.0;
    _gammaAsymptote = null;
    _errorMessage = '';
    if (_isSimulationMode) _simService.stopSimulation();
    notifyListeners();
  }

  // --- History / Persistence ---

  Future<void> saveResult(DlsMeasurementResult result) async {
    _history.insert(0, result);
    _nextMeasurementIndex++;
    await _persistHistory();
    notifyListeners();
  }

  Future<void> deleteHistoryItem(String id) async {
    _history.removeWhere((item) => item.id == id);
    await _persistHistory();
    notifyListeners();
  }

  Future<void> clearHistory() async {
    _history.clear();
    await _persistHistory();
    notifyListeners();
  }

  String _generateId() {
    return 'CM-${_nextMeasurementIndex.toString().padLeft(3, '0')}';
  }

  Future<void> _loadHistory() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      // Clear any legacy data (old INR/PT model format)
      final raw = prefs.getStringList('dls_history') ?? [];
      _history = raw.map((s) => DlsMeasurementResult.fromJson(s)).toList();
      _history.sort((a, b) => b.timestamp.compareTo(a.timestamp));
      _nextMeasurementIndex = _history.length + 1;
      notifyListeners();
    } catch (e) {
      _history = [];
      _nextMeasurementIndex = 1;
    }
  }

  Future<void> _persistHistory() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList('dls_history', _history.map((e) => e.toJson()).toList());
    } catch (_) {}
  }

  /// Build a full CSV string from history
  String buildCsv() {
    final buffer = StringBuffer();
    buffer.writeln(DlsMeasurementResult.csvHeader());
    for (final r in _history) {
      buffer.writeln(r.toCsvRow());
    }
    return buffer.toString();
  }

  /// Returns pairs of [gammaAsymptote, labInr] for correlation plot
  /// Only entries that have labInr filled in
  List<List<double>> get correlationData {
    return _history
        .where((r) => r.labInr != null)
        .map((r) => [r.gammaAsymptote, r.labInr!])
        .toList();
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
