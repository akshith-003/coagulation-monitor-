import 'dart:async';
import 'dart:math';

/// DLS Simulation Service — generates realistic ESP32-like JSON data packets
/// using 3 patient profiles with exponential gamma decay curves + Gaussian noise.
class SimulationService {
  final _streamController = StreamController<Map<String, dynamic>>.broadcast();
  Stream<Map<String, dynamic>> get stream => _streamController.stream;

  Timer? _timer;
  String _currentStage = 'idle';
  double _elapsedMs = 0.0;
  final _random = Random();

  // --- Active Profile Parameters ---
  late _DlsProfile _profile;
  double _peakPressure = 0.0;

  String get currentStage => _currentStage;

  // Stage durations in milliseconds
  static const int _baselineDurationMs = 3000;
  static const int _inflatingDurationMs = 4000;
  static const int _occlusionDurationMs = 20000; // 20s — main measurement
  static const int _analysisDurationMs = 2000;

  int get _totalDurationMs =>
      _baselineDurationMs + _inflatingDurationMs + _occlusionDurationMs + _analysisDurationMs;

  /// Start a fresh simulation cycle
  void startSimulation() {
    stopSimulation();
    _elapsedMs = 0.0;
    _peakPressure = 0.0;
    _currentStage = 'baseline';

    // Pick a random patient profile
    final profiles = [_DlsProfile.hyper(), _DlsProfile.normal(), _DlsProfile.hypo()];
    _profile = profiles[_random.nextInt(3)];

    // Emit at 100ms intervals (10Hz) — matches ESP32 BLE notify rate
    _timer = Timer.periodic(const Duration(milliseconds: 100), _tick);
  }

  void _tick(Timer timer) {
    _elapsedMs += 100;

    final stageElapsedMs = _stageElapsedMs();
    _currentStage = _stageAtTime(_elapsedMs);

    // Compute sensor values based on current stage
    final adcRaw = _computeAdcRaw();
    final dcIntensity = _computeDcIntensity(adcRaw);
    final pressure = _computePressure();
    final skinTemp = 32.0 + _gaussian(0.0, 0.15);
    final gammaHz = _computeGamma(stageElapsedMs);

    if (pressure > _peakPressure) _peakPressure = pressure;

    _streamController.add({
      'stage': _currentStage.toUpperCase(),
      'adc_raw': adcRaw.round(),
      'dc_intensity': double.parse(dcIntensity.toStringAsFixed(3)),
      'gamma': double.parse(gammaHz.toStringAsFixed(2)),
      's_value': _profile.sMobility + _gaussian(0, 5),
      'pressure_mmhg': double.parse(pressure.toStringAsFixed(1)),
      'temp_c': double.parse(skinTemp.toStringAsFixed(2)),
      'timestamp_ms': _elapsedMs.round(),
      'stage_elapsed_ms': stageElapsedMs,
      'stage_remaining_ms': _stageRemainingMs(),
    });

    // Emit result packet when done
    if (_elapsedMs >= _totalDurationMs) {
      _emitResult();
      stopSimulation();
    }
  }

  String _stageAtTime(double elapsed) {
    if (elapsed < _baselineDurationMs) return 'baseline';
    if (elapsed < _baselineDurationMs + _inflatingDurationMs) return 'inflating';
    if (elapsed < _baselineDurationMs + _inflatingDurationMs + _occlusionDurationMs) {
      return 'occlusion';
    }
    return 'analysis';
  }

  double _stageElapsedMs() {
    if (_currentStage == 'baseline') return _elapsedMs;
    if (_currentStage == 'inflating') return _elapsedMs - _baselineDurationMs;
    if (_currentStage == 'occlusion') {
      return _elapsedMs - _baselineDurationMs - _inflatingDurationMs;
    }
    return _elapsedMs - _baselineDurationMs - _inflatingDurationMs - _occlusionDurationMs;
  }

  double _stageRemainingMs() {
    if (_currentStage == 'baseline') return _baselineDurationMs - _stageElapsedMs();
    if (_currentStage == 'inflating') return _inflatingDurationMs - _stageElapsedMs();
    if (_currentStage == 'occlusion') return _occlusionDurationMs - _stageElapsedMs();
    if (_currentStage == 'analysis') return _analysisDurationMs - _stageElapsedMs();
    return 0;
  }

  double _computeAdcRaw() {
    // Baseline ~1800 counts, drops during occlusion as blood is occluded
    double base = 1800.0;
    if (_currentStage == 'inflating') {
      final t = _stageElapsedMs() / _inflatingDurationMs;
      base = 1800 - 200 * t;
    } else if (_currentStage == 'occlusion') {
      base = 1600.0;
    } else if (_currentStage == 'analysis') {
      final t = _stageElapsedMs() / _analysisDurationMs;
      base = 1600 + 200 * t;
    }
    return (base + _gaussian(0, 25)).clamp(0, 4096);
  }

  double _computeDcIntensity(double adcRaw) {
    // DC intensity roughly scales with ADC raw (3.3V / 4096 count)
    return (adcRaw / 4096.0 * 3.3 + _gaussian(0, 0.02)).clamp(0, 3.3);
  }

  double _computePressure() {
    if (_currentStage == 'baseline') return 0.0;
    if (_currentStage == 'inflating') {
      final t = _stageElapsedMs() / _inflatingDurationMs;
      return (180 * t + _gaussian(0, 2)).clamp(0, 200);
    }
    if (_currentStage == 'occlusion') {
      return 180 + _gaussian(0, 3);
    }
    if (_currentStage == 'analysis') {
      final t = _stageElapsedMs() / _analysisDurationMs;
      return (180 * (1 - t) + _gaussian(0, 2)).clamp(0, 200);
    }
    return 0;
  }

  /// Exponential decay: γ(t) = γ∞ + (γ₀ - γ∞) * exp(-k * t) + noise
  double _computeGamma(double stageElapsedMs) {
    if (_currentStage != 'occlusion') {
      // Outside occlusion, show a stable high gamma (baseline blood flow)
      return _profile.gammaInitial + _gaussian(0, 1.5);
    }
    final t = stageElapsedMs / 1000.0; // convert to seconds
    final decayed = _profile.gammaAsymptote +
        (_profile.gammaInitial - _profile.gammaAsymptote) * exp(-_profile.decayK * t);
    return (decayed + _gaussian(0, 1.2)).clamp(0, 80);
  }

  void _emitResult() {
    // Calculate final DLS parameters
    final occlusionGammaPoints = _profile.occlusionGammaPoints;
    final gammaInitial = occlusionGammaPoints.isNotEmpty ? occlusionGammaPoints.first : _profile.gammaInitial;
    final gammaAsymptote = _profile.gammaAsymptote;
    final gammaDrop = gammaInitial - gammaAsymptote;
    final decayRate = _profile.decayK * gammaDrop;

    _streamController.add({
      'type': 'result',
      'gamma_initial': double.parse(gammaInitial.toStringAsFixed(2)),
      'gamma_asymptote': double.parse(gammaAsymptote.toStringAsFixed(2)),
      'gamma_drop': double.parse(gammaDrop.toStringAsFixed(2)),
      'decay_rate': double.parse(decayRate.toStringAsFixed(3)),
      's_mobility': _profile.sMobility,
      'decay_shape': _profile.decayShape,
      'dc_intensity': 1.84,
      'skin_temp_c': 32.4,
      'peak_pressure_mmhg': double.parse(_peakPressure.toStringAsFixed(1)),
      'signal_quality': 'GOOD',
      'duration_s': (_occlusionDurationMs / 1000.0),
    });
  }

  /// Stop and reset
  void stopSimulation() {
    _timer?.cancel();
    _timer = null;
    _currentStage = 'idle';
    _elapsedMs = 0.0;
  }

  void dispose() {
    stopSimulation();
    _streamController.close();
  }

  // --- Gaussian noise helper (Box-Muller) ---
  double _gaussian(double mean, double stdDev) {
    final u1 = _random.nextDouble();
    final u2 = _random.nextDouble();
    final z = sqrt(-2.0 * log(u1)) * cos(2.0 * pi * u2);
    return mean + z * stdDev;
  }
}

/// Internal data class defining a patient DLS profile
class _DlsProfile {
  final double gammaInitial; // Hz
  final double gammaAsymptote; // Hz
  final double decayK; // exponential rate constant
  final double sMobility; // au
  final String decayShape;
  final List<double> occlusionGammaPoints;

  _DlsProfile({
    required this.gammaInitial,
    required this.gammaAsymptote,
    required this.decayK,
    required this.sMobility,
    required this.decayShape,
  }) : occlusionGammaPoints = [];

  factory _DlsProfile.hyper() => _DlsProfile(
        gammaInitial: 42.0,
        gammaAsymptote: 14.0,
        decayK: 0.28, // fast
        sMobility: 140.0,
        decayShape: 'FAST',
      );

  factory _DlsProfile.normal() => _DlsProfile(
        gammaInitial: 46.0,
        gammaAsymptote: 22.0,
        decayK: 0.18, // moderate
        sMobility: 240.0,
        decayShape: 'MODERATE',
      );

  factory _DlsProfile.hypo() => _DlsProfile(
        gammaInitial: 54.0,
        gammaAsymptote: 36.0,
        decayK: 0.10, // slow
        sMobility: 380.0,
        decayShape: 'SLOW',
      );
}
