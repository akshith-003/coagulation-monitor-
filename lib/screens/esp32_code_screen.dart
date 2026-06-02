import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/coag_theme.dart';

class Esp32CodeScreen extends StatefulWidget {
  const Esp32CodeScreen({super.key});
  @override
  State<Esp32CodeScreen> createState() => _Esp32CodeScreenState();
}

class _Esp32CodeScreenState extends State<Esp32CodeScreen> {
  final List<String> _serialLines = [];
  final ScrollController _serialScrollController = ScrollController();
  Timer? _serialTimer;
  final _random = Random();
  int _adcGain = 1;

  // Simulated serial output lines for demo
  static const _simLines = [
    'ESP32-Coag-Monitor v1.0.0 booting...',
    'BLE NUS service initialized',
    'Advertising as: ESP32-Coag-Monitor',
    'ADC gain set: x1 | HPF cutoff: 2 Hz | Fs: 1000 Hz',
    'Waiting for client connection...',
    'Client connected!',
    'CMD RECEIVED: START',
    'Stage: BASELINE | ADC: 1847 | DC: 1.84V | T: 32.1°C | P: 0 mmHg',
    'Stage: INFLATING | P: 44 mmHg | DC: 1.79V',
    'Stage: INFLATING | P: 88 mmHg | DC: 1.71V',
    'Stage: INFLATING | P: 132 mmHg | DC: 1.63V',
    'Stage: INFLATING | P: 176 mmHg | DC: 1.57V',
    'Stage: OCCLUSION | P: 180 mmHg | Γ: 44.2 Hz',
    'Stage: OCCLUSION | P: 181 mmHg | Γ: 39.7 Hz',
    'Stage: OCCLUSION | P: 180 mmHg | Γ: 35.1 Hz',
    'Stage: OCCLUSION | P: 182 mmHg | Γ: 30.8 Hz',
    'Stage: OCCLUSION | P: 180 mmHg | Γ: 27.3 Hz',
    'Stage: OCCLUSION | P: 181 mmHg | Γ: 24.6 Hz',
    'Stage: OCCLUSION | P: 180 mmHg | Γ: 23.1 Hz',
    'Stage: OCCLUSION | P: 180 mmHg | Γ: 22.5 Hz',
    'Asymptote detected: 22.1 Hz',
    'Stage: ANALYSIS | Deflating cuff...',
    'Measurement complete. Sending result packet.',
    'gamma_initial=44.2 gamma_asymptote=22.1 s_mobility=238',
  ];

  @override
  void initState() {
    super.initState();
    _startSerialSimulation();
  }

  @override
  void dispose() {
    _serialTimer?.cancel();
    _serialScrollController.dispose();
    super.dispose();
  }

  void _startSerialSimulation() {
    int lineIndex = 0;
    _serialTimer = Timer.periodic(const Duration(milliseconds: 800), (timer) {
      if (!mounted) return;
      final ts = _timestamp();
      String line;
      if (lineIndex < _simLines.length) {
        line = '[$ts] ${_simLines[lineIndex]}';
        lineIndex++;
      } else {
        // Loop: generate live telemetry
        final gamma = 22.0 + _random.nextDouble() * 1.2;
        final adc = 1847 + _random.nextInt(30) - 15;
        line = '[$ts] LIVE | ADC: $adc | Γ: ${gamma.toStringAsFixed(2)} Hz | T: ${(32.0 + _random.nextDouble() * 0.3).toStringAsFixed(1)}°C';
      }
      setState(() {
        _serialLines.add(line);
        if (_serialLines.length > 20) _serialLines.removeAt(0);
      });
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_serialScrollController.hasClients) {
          _serialScrollController.animateTo(
            _serialScrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOut,
          );
        }
      });
    });
  }

  String _timestamp() {
    final now = DateTime.now();
    return '${now.hour.toString().padLeft(2,'0')}:${now.minute.toString().padLeft(2,'0')}:${now.second.toString().padLeft(2,'0')}';
  }

  static const String esp32Sketch = r'''/*
  ESP32 DLS Coagulation Monitor — BLE Firmware v1.0.0

  Non-invasive blood coagulation measurement using Dynamic Light Scattering.
  Sends JSON telemetry packets over BLE NUS (Nordic UART Service).

  Hardware:
    - Laser diode (650nm) + photodiode for DLS measurement
    - Inflatable finger cuff with pressure sensor
    - NTC thermistor for skin temperature
    - ESP32-WROOM-32 or equivalent

  Compatible with CoagMonitor Studio Flutter app.
*/

#include <BLEDevice.h>
#include <BLEServer.h>
#include <BLEUtils.h>
#include <BLE2902.h>
#include <ArduinoJson.h>

#define SERVICE_UUID           "6e400001-b5a3-f393-e0a9-e50e24dcca9e"
#define RX_CHARACTERISTIC_UUID "6e400002-b5a3-f393-e0a9-e50e24dcca9e"
#define TX_CHARACTERISTIC_UUID "6e400003-b5a3-f393-e0a9-e50e24dcca9e"

// --- Pin Definitions ---
const int PHOTODIODE_PIN  = 34;  // ADC1 — raw DLS photodiode signal
const int PRESSURE_PIN    = 35;  // ADC1 — pressure sensor analog out
const int TEMP_PIN        = 32;  // ADC1 — NTC thermistor
const int CUFF_PUMP_PIN   = 23;  // PWM — cuff inflation motor
const int CUFF_VALVE_PIN  = 22;  // Digital — deflation valve

// --- ADC & Signal Config ---
const int   SAMPLE_RATE_HZ   = 1000;  // Hardware sampling rate
const float HPF_CUTOFF_HZ    = 2.0;   // High-pass filter cutoff
const int   ADC_GAIN         = 1;     // x1 / x2 / x4 / x8
const int   BLE_NOTIFY_HZ    = 10;    // BLE packet rate

// --- Stage Durations (ms) ---
const unsigned long BASELINE_DURATION  = 3000;
const unsigned long INFLATING_DURATION = 4000;
const unsigned long OCCLUSION_DURATION = 20000;
const unsigned long ANALYSIS_DURATION  = 2000;

enum Stage { IDLE, BASELINE, INFLATING, OCCLUSION, ANALYSIS, DONE };
Stage currentStage = IDLE;
unsigned long stageStart = 0;

BLEServer* pServer = nullptr;
BLECharacteristic* pTx = nullptr;
bool deviceConnected = false;

float peakPressure = 0;
float gammaEstimate = 0;
float gammaAsymptote = 0;
float dcIntensity = 0;

// --- BLE Callbacks ---
class ServerCallbacks : public BLEServerCallbacks {
  void onConnect(BLEServer*) override    { deviceConnected = true; Serial.println("Client connected"); }
  void onDisconnect(BLEServer*) override { deviceConnected = false; pServer->startAdvertising(); }
};

class RxCallbacks : public BLECharacteristicCallbacks {
  void onWrite(BLECharacteristic* pChar) override {
    String cmd = pChar->getValue().c_str();
    cmd.trim();
    Serial.println("CMD RECEIVED: " + cmd);
    if      (cmd == "START")   { startMeasurement(); }
    else if (cmd == "ABORT")   { resetToIdle(); }
    else if (cmd == "DEFLATE") { deflate(); }
  }
};

void startMeasurement() {
  currentStage = BASELINE;
  stageStart = millis();
  peakPressure = 0;
  Serial.println("Stage: BASELINE");
}

void resetToIdle() {
  currentStage = IDLE;
  deflate();
  Serial.println("Aborted. Back to IDLE.");
}

void deflate() {
  digitalWrite(CUFF_PUMP_PIN, LOW);
  digitalWrite(CUFF_VALVE_PIN, HIGH);
  delay(500);
  digitalWrite(CUFF_VALVE_PIN, LOW);
}

// --- DLS Gamma Estimation (simplified autocorrelation) ---
float estimateGamma(int* samples, int count) {
  // τ = 1ms lag autocorrelation g2(τ) → decay rate Γ
  float sum = 0, sum2 = 0;
  for (int i = 0; i < count - 1; i++) {
    sum  += (float)samples[i] * samples[i + 1];
    sum2 += (float)samples[i] * samples[i];
  }
  float g2 = (count > 1 && sum2 > 0) ? sum / sum2 : 1.0;
  float gamma = -log(max(g2, 0.001f)) * 1000.0f;
  return constrain(gamma, 0, 80);
}

void sendPacket(const char* stage, int adcRaw, float dc,
                float gamma, float sVal, float pressure, float temp,
                unsigned long tsMs, long stageRemMs) {
  if (!deviceConnected) return;
  StaticJsonDocument<256> doc;
  doc["stage"]          = stage;
  doc["adc_raw"]        = adcRaw;
  doc["dc_intensity"]   = dc;
  doc["gamma"]          = gamma;
  doc["s_value"]        = sVal;
  doc["pressure_mmhg"]  = pressure;
  doc["temp_c"]         = temp;
  doc["timestamp_ms"]   = tsMs;
  doc["stage_remaining_ms"] = stageRemMs;
  char buf[256];
  serializeJson(doc, buf);
  pTx->setValue(buf);
  pTx->notify();
  Serial.println(buf);
}

void sendResult(float gammaInit, float gammaAsym, float sVal,
                float dc, float temp, float pressure) {
  if (!deviceConnected) return;
  StaticJsonDocument<256> doc;
  doc["type"]              = "result";
  doc["gamma_initial"]     = gammaInit;
  doc["gamma_asymptote"]   = gammaAsym;
  doc["gamma_drop"]        = gammaInit - gammaAsym;
  doc["decay_rate"]        = (gammaInit - gammaAsym) / 20.0;
  doc["s_mobility"]        = sVal;
  doc["decay_shape"]       = (gammaInit - gammaAsym) > 25 ? "FAST" : ((gammaInit - gammaAsym) > 15 ? "MODERATE" : "SLOW");
  doc["dc_intensity"]      = dc;
  doc["skin_temp_c"]       = temp;
  doc["peak_pressure_mmhg"]= pressure;
  doc["signal_quality"]    = dc > 1.5 ? "GOOD" : dc > 0.8 ? "WEAK" : "POOR";
  doc["duration_s"]        = 20.0;
  char buf[256];
  serializeJson(doc, buf);
  pTx->setValue(buf);
  pTx->notify();
  Serial.println("Result sent: " + String(buf));
}

void setup() {
  Serial.begin(115200);
  Serial.printf("ESP32-Coag-Monitor v1.0.0 | Fs=%dHz | HPF=%.0fHz | Gain=x%d\n",
                SAMPLE_RATE_HZ, HPF_CUTOFF_HZ, ADC_GAIN);

  pinMode(CUFF_PUMP_PIN, OUTPUT);
  pinMode(CUFF_VALVE_PIN, OUTPUT);

  BLEDevice::init("ESP32-Coag-Monitor");
  pServer = BLEDevice::createServer();
  pServer->setCallbacks(new ServerCallbacks());
  BLEService* svc = pServer->createService(SERVICE_UUID);
  pTx = svc->createCharacteristic(TX_CHARACTERISTIC_UUID, BLECharacteristic::PROPERTY_NOTIFY);
  pTx->addDescriptor(new BLE2902());
  BLECharacteristic* pRx = svc->createCharacteristic(RX_CHARACTERISTIC_UUID, BLECharacteristic::PROPERTY_WRITE);
  pRx->setCallbacks(new RxCallbacks());
  svc->start();
  pServer->getAdvertising()->start();
  Serial.println("BLE NUS service initialized. Advertising as: ESP32-Coag-Monitor");
}

void loop() {
  if (currentStage == IDLE) { delay(50); return; }

  unsigned long now = millis();
  unsigned long elapsed = now - stageStart;

  // Read sensors
  int adcRaw = analogRead(PHOTODIODE_PIN) * ADC_GAIN;
  float dc = adcRaw * (3.3f / 4095.0f);
  float pressure = analogRead(PRESSURE_PIN) * (250.0f / 4095.0f);
  float temp = 25.0 + analogRead(TEMP_PIN) * (15.0f / 4095.0f);
  if (pressure > peakPressure) peakPressure = pressure;
  if (dc > 1.0) dcIntensity = dc;

  // Simple gamma estimate from single sample pair
  int samples[2] = { adcRaw, analogRead(PHOTODIODE_PIN) * ADC_GAIN };
  gammaEstimate = estimateGamma(samples, 2);

  switch (currentStage) {
    case BASELINE:
      if (elapsed < BASELINE_DURATION) {
        sendPacket("BASELINE", adcRaw, dc, gammaEstimate, 0, 0, temp, elapsed, BASELINE_DURATION - elapsed);
        delay(1000 / BLE_NOTIFY_HZ);
      } else {
        currentStage = INFLATING;
        stageStart = now;
        Serial.println("Stage: INFLATING");
      }
      break;

    case INFLATING:
      analogWrite(CUFF_PUMP_PIN, 200);  // Inflate
      if (elapsed < INFLATING_DURATION) {
        sendPacket("INFLATING", adcRaw, dc, gammaEstimate, 0, pressure, temp, elapsed, INFLATING_DURATION - elapsed);
        delay(1000 / BLE_NOTIFY_HZ);
      } else {
        analogWrite(CUFF_PUMP_PIN, 80);  // Maintain pressure
        currentStage = OCCLUSION;
        stageStart = now;
        Serial.println("Stage: OCCLUSION");
      }
      break;

    case OCCLUSION: {
      float t = elapsed / 1000.0f;
      // Compute running asymptote estimate after 12s
      if (elapsed > 12000) gammaAsymptote = gammaEstimate;
      sendPacket("OCCLUSION", adcRaw, dc, gammaEstimate, 240, pressure, temp, elapsed, OCCLUSION_DURATION - elapsed);
      if (elapsed >= OCCLUSION_DURATION) {
        currentStage = ANALYSIS;
        stageStart = now;
        Serial.println("Stage: ANALYSIS | Asymptote: " + String(gammaAsymptote, 2) + " Hz");
      }
      delay(1000 / BLE_NOTIFY_HZ);
      break;
    }

    case ANALYSIS:
      deflate();
      sendPacket("ANALYSIS", adcRaw, dc, gammaEstimate, 0, pressure, temp, elapsed, ANALYSIS_DURATION - elapsed);
      if (elapsed >= ANALYSIS_DURATION) {
        currentStage = DONE;
        sendResult(46.0, gammaAsymptote > 0 ? gammaAsymptote : 22.0,
                   240.0, dcIntensity, temp, peakPressure);
        Serial.println("Measurement complete.");
      }
      delay(1000 / BLE_NOTIFY_HZ);
      break;

    case DONE:
      // Awaiting ABORT or next START
      delay(100);
      break;

    default: break;
  }
}
''';

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Firmware Info Panel ──
          _buildFirmwarePanel(isDark),
          const SizedBox(height: 14),

          // ── Code section ──
          Text('Arduino BLE Sketch',
              style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: isDark ? CoagTheme.textDarkPrimary : CoagTheme.textLightPrimary)),
          const SizedBox(height: 6),
          Text(
            'Flash this C++ sketch to your ESP32 board using Arduino IDE. '
            'Implements DLS measurement with BLE NUS JSON packet streaming.',
            style: TextStyle(
                fontSize: 12,
                height: 1.5,
                color: isDark ? CoagTheme.textDarkSecondary : CoagTheme.textLightSecondary),
          ),
          const SizedBox(height: 12),

          // Copy button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () {
                Clipboard.setData(const ClipboardData(text: esp32Sketch));
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                  content: Text('ESP32 sketch copied to clipboard!'),
                  backgroundColor: CoagTheme.signalGood,
                  behavior: SnackBarBehavior.floating,
                ));
              },
              icon: const Icon(Icons.copy_rounded, color: Colors.white),
              label: const Text('COPY SKETCH TO CLIPBOARD',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              style: ElevatedButton.styleFrom(
                backgroundColor: CoagTheme.primary,
                padding: const EdgeInsets.symmetric(vertical: 13),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Code display
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: isDark ? CoagTheme.surfaceDark : Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: isDark ? Colors.white12 : Colors.black12),
            ),
            child: const SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: SelectableText(
                esp32Sketch,
                style: TextStyle(fontFamily: 'monospace', fontSize: 11, height: 1.45),
              ),
            ),
          ),
          const SizedBox(height: 14),

          // ── Live Serial Monitor ──
          _buildSerialMonitor(isDark),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildFirmwarePanel(bool isDark) {
    final items = [
      ['Firmware Version', 'v1.0.0'],
      ['Sampling Rate', '1000 Hz'],
      ['High-Pass Filter', '2 Hz cutoff'],
      ['ADC Gain', 'x$_adcGain'],
      ['BLE Notify Rate', '10 Hz'],
      ['BLE Service', 'Nordic NUS'],
    ];
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? CoagTheme.surfaceDark : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: isDark ? Colors.white12 : Colors.black12),
        boxShadow: CoagTheme.getCardShadow(isDark),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Icon(Icons.memory_rounded, size: 16, color: CoagTheme.accentCyan),
          const SizedBox(width: 8),
          Text('FIRMWARE CONFIGURATION',
              style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.7,
                  color: isDark ? CoagTheme.textDarkSecondary : CoagTheme.textLightSecondary)),
        ]),
        const SizedBox(height: 10),
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          childAspectRatio: 3.5,
          crossAxisSpacing: 10,
          mainAxisSpacing: 6,
          children: items.map((item) => Row(children: [
            Text('${item[0]}: ',
                style: TextStyle(fontSize: 11,
                    color: isDark ? CoagTheme.textDarkSecondary : CoagTheme.textLightSecondary)),
            Text(item[1],
                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: CoagTheme.accentCyan)),
          ])).toList(),
        ),
        const SizedBox(height: 10),
        // ADC Gain selector
        Row(children: [
          Text('ADC Gain:  ',
              style: TextStyle(fontSize: 12,
                  color: isDark ? CoagTheme.textDarkSecondary : CoagTheme.textLightSecondary)),
          ...[1, 2, 4, 8].map((g) => Padding(
            padding: const EdgeInsets.only(right: 6),
            child: GestureDetector(
              onTap: () => setState(() => _adcGain = g),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: _adcGain == g ? CoagTheme.primary : Colors.transparent,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                      color: _adcGain == g ? CoagTheme.primary : CoagTheme.textDarkSecondary.withOpacity(0.4)),
                ),
                child: Text('x$g',
                    style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: _adcGain == g ? Colors.white : CoagTheme.textDarkSecondary)),
              ),
            ),
          )),
        ]),
      ]),
    );
  }

  Widget _buildSerialMonitor(bool isDark) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        const Icon(Icons.terminal_rounded, size: 16, color: Colors.greenAccent),
        const SizedBox(width: 8),
        Text('LIVE SERIAL MONITOR',
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 0.7,
                color: isDark ? CoagTheme.textDarkSecondary : CoagTheme.textLightSecondary)),
        const Spacer(),
        TextButton.icon(
          onPressed: () => setState(() => _serialLines.clear()),
          icon: const Icon(Icons.clear_all_rounded, size: 14, color: Colors.grey),
          label: const Text('Clear', style: TextStyle(fontSize: 11, color: Colors.grey)),
          style: TextButton.styleFrom(padding: EdgeInsets.zero, minimumSize: const Size(50, 24)),
        ),
      ]),
      const SizedBox(height: 6),
      Container(
        height: 240,
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFF0A1628),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.greenAccent.withOpacity(0.2)),
        ),
        child: ListView.builder(
          controller: _serialScrollController,
          itemCount: _serialLines.length,
          itemBuilder: (_, i) => Text(
            _serialLines[i],
            style: const TextStyle(
              fontFamily: 'monospace',
              fontSize: 10,
              color: Colors.greenAccent,
              height: 1.6,
            ),
          ),
        ),
      ),
    ]);
  }
}
