import 'dart:async';
import 'dart:math';

class SimulationService {
  final _streamController = StreamController<Map<String, dynamic>>.broadcast();
  Stream<Map<String, dynamic>> get stream => _streamController.stream;

  Timer? _timer;
  String _currentState = "idle";
  double _currentTemp = 24.5;
  double _elapsedTime = 0.0;
  
  // Clotting curve parameters
  double _pt = 12.0; // Random Prothrombin Time in seconds
  double _inr = 1.0;
  final double _startVal = 920.0;
  final double _endVal = 340.0;
  final double _steepness = 0.8;
  final _random = Random();

  String get currentState => _currentState;

  // Start the simulation cycle (begins heating)
  void startSimulation() {
    stopSimulation();
    _currentState = "heating";
    _currentTemp = 24.5;
    _elapsedTime = 0.0;
    
    // Randomize PT and INR for this run
    // PT range: 10.5 to 35.0 seconds
    _pt = 11.0 + _random.nextDouble() * 24.0;
    // Compute INR relative to normal mean PT of 11.5 seconds
    _inr = pow((_pt / 11.5), 1.05).toDouble();
    // Round to two decimal places
    _inr = double.parse(_inr.toStringAsFixed(2));
    _pt = double.parse(_pt.toStringAsFixed(1));

    _timer = Timer.periodic(const Duration(milliseconds: 250), (timer) {
      if (_currentState == "heating") {
        // Temperature rises to 37.0 degrees Celsius
        if (_currentTemp < 37.0) {
          _currentTemp += 0.5 + _random.nextDouble() * 0.8;
          if (_currentTemp >= 37.0) {
            _currentTemp = 37.0;
            _currentState = "insertStrip";
            _streamController.add({
              "type": "status",
              "state": "insertStrip",
              "temp": _currentTemp,
            });
          } else {
            _streamController.add({
              "type": "status",
              "state": "heating",
              "temp": double.parse(_currentTemp.toStringAsFixed(1)),
            });
          }
        }
      }
    });
  }

  // Trigger strip insertion
  void triggerStripInserted() {
    if (_currentState != "insertStrip") return;
    
    _currentState = "applyBlood";
    _streamController.add({
      "type": "status",
      "state": "applyBlood",
      "temp": 37.0,
    });
  }

  // Trigger blood drop application
  void triggerBloodApplied() {
    if (_currentState != "applyBlood") return;

    _currentState = "measuring";
    _elapsedTime = 0.0;
    
    _timer?.cancel();
    // Stream data points at 10Hz (every 100ms)
    _timer = Timer.periodic(const Duration(milliseconds: 100), (timer) {
      if (_currentState == "measuring") {
        _elapsedTime += 0.1;
        
        // Sigmoid formula: value = start - (start - end) / (1 + exp(-k * (t - t0)))
        // t0 is the clotting time (_pt)
        double exponent = -_steepness * (_elapsedTime - _pt);
        // Bound exponent to prevent overflow
        exponent = exponent.clamp(-20.0, 20.0);
        double sigmoid = 1.0 / (1.0 + exp(exponent));
        double rawVal = _startVal - (_startVal - _endVal) * sigmoid;
        
        // Add random electrical/optical noise (+/- 4 units)
        double noise = (_random.nextDouble() - 0.5) * 6.0;
        double finalVal = rawVal + noise;
        
        _streamController.add({
          "type": "data",
          "time": double.parse(_elapsedTime.toStringAsFixed(1)),
          "value": finalVal.round(),
          "temp": 37.0,
        });

        // Run measurement for 20 seconds, or until PT + 4 seconds (whichever is longer)
        double durationToRun = max(20.0, _pt + 4.0);
        if (_elapsedTime >= durationToRun) {
          _currentState = "completed";
          _timer?.cancel();
          
          _streamController.add({
            "type": "result",
            "pt": _pt,
            "inr": _inr,
            "temp": 37.0,
          });
        }
      }
    });
  }

  // Stop/reset the simulation
  void stopSimulation() {
    _timer?.cancel();
    _timer = null;
    _currentState = "idle";
    _currentTemp = 24.5;
    _elapsedTime = 0.0;
  }

  void dispose() {
    stopSimulation();
  }
}
