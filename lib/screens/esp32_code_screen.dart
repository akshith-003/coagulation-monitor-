import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/coag_theme.dart';

class Esp32CodeScreen extends StatelessWidget {
  const Esp32CodeScreen({super.key});

  static const String esp32Sketch = r'''/*
  ESP32 Coagulation Monitor BLE Firmware
  
  This sketch implements a Bluetooth Low Energy (BLE) peripheral using the Nordic 
  UART Service (NUS). It receives commands from the Flutter App, heats the test chamber,
  waits for strip insertion/blood application, streams raw sensor values, and calculates PT/INR.

  Compatible with: ESP32, ESP32-WROOM-32, ESP32-S3, etc.
*/

#include <BLEDevice.h>
#include <BLEServer.h>
#include <BLEUtils.h>
#include <BLE2902.h>

// NUS UUIDs (standard Nordic UART Service)
#define SERVICE_UUID           "6e400001-b5a3-f393-e0a9-e50e24dcca9e"
#define RX_CHARACTERISTIC_UUID "6e400002-b5a3-f393-e0a9-e50e24dcca9e" // App writes to ESP32
#define TX_CHARACTERISTIC_UUID "6e400003-b5a3-f393-e0a9-e50e24dcca9e" // ESP32 notifies App

// Pin Definitions
const int TEMP_PIN = 34;      // Analog input for NTC Thermistor / Temperature sensor
const int OPTICAL_PIN = 35;   // Analog input for Phototransistor (Coagulation optical curve)
const int HEATER_PIN = 23;    // Digital output to control MOSFET/Heater element

// State Machine Variables
enum SystemState { IDLE, HEATING, INSERT_STRIP, APPLY_BLOOD, MEASURING, COMPLETED };
SystemState currentState = IDLE;

BLEServer* pServer = NULL;
BLECharacteristic* pTxCharacteristic;
bool deviceConnected = false;
bool oldDeviceConnected = false;
double currentTemp = 24.5;
unsigned long stateStartTime = 0;
unsigned long measurementStartTime = 0;

// Test Simulation constants (if physical sensors are not connected)
bool useDummySensors = true; 
double simulatedPtTime = 12.8; 

// BLE Server Connection Callback
class MyServerCallbacks: public BLEServerCallbacks {
    void onConnect(BLEServer* pServer) {
      deviceConnected = true;
    };
    void onDisconnect(BLEServer* pServer) {
      deviceConnected = false;
    }
};

// BLE Characteristic Write Callbacks (Receiving commands from Flutter App)
class MyCallbacks: public BLECharacteristicCallbacks {
    void onWrite(BLECharacteristic *pCharacteristic) {
      std::string rxValue = pCharacteristic->getValue();
      if (rxValue.length() > 0) {
        String command = "";
        for (int i = 0; i < rxValue.length(); i++) {
          if (rxValue[i] != '\n' && rxValue[i] != '\r') {
            command += rxValue[i];
          }
        }
        
        command.trim();
        Serial.println("Command Received: " + command);
        
        if (command == "START") {
          startMeasurement();
        } else if (command == "STRIP_INSERTED") {
          if (currentState == INSERT_STRIP) {
            currentState = APPLY_BLOOD;
            sendStatusUpdate("applyBlood", 37.0);
          }
        } else if (command == "BLOOD_APPLIED") {
          if (currentState == APPLY_BLOOD) {
            currentState = MEASURING;
            measurementStartTime = millis();
            sendStatusUpdate("measuring", 37.0);
          }
        } else if (command == "RESET") {
          resetSystem();
        }
      }
    }
    
    void startMeasurement() {
      currentState = HEATING;
      stateStartTime = millis();
      currentTemp = 25.0;
      digitalWrite(HEATER_PIN, HIGH); // Turn on heater
      Serial.println("Measurement started: Heating...");
    }
    
    void resetSystem() {
      currentState = IDLE;
      digitalWrite(HEATER_PIN, LOW); // Turn off heater
      sendStatusUpdate("idle", 25.0);
      Serial.println("System reset.");
    }
};

void sendStatusUpdate(String state, double temp) {
  if (!deviceConnected) return;
  String json = "{\"type\":\"status\",\"state\":\"" + state + "\",\"temp\":" + String(temp, 1) + "}\n";
  pTxCharacteristic->setValue(json.c_str());
  pTxCharacteristic->notify();
}

void setup() {
  Serial.begin(115200);
  pinMode(HEATER_PIN, OUTPUT);
  digitalWrite(HEATER_PIN, LOW);

  // Initialize BLE Device
  BLEDevice::init("ESP32-Coag-Monitor");

  // Create BLE Server
  pServer = BLEDevice::createServer();
  pServer->setCallbacks(new MyServerCallbacks());

  // Create BLE Service
  BLEService *pService = pServer->createService(SERVICE_UUID);

  // Create TX Characteristic (Notify)
  pTxCharacteristic = pService->createCharacteristic(
                      TX_CHARACTERISTIC_UUID,
                      BLECharacteristic::PROPERTY_NOTIFY
                    );
  pTxCharacteristic->addDescriptor(new BLE2902());

  // Create RX Characteristic (Write)
  BLECharacteristic *pRxCharacteristic = pService->createCharacteristic(
                                         RX_CHARACTERISTIC_UUID,
                                         BLECharacteristic::PROPERTY_WRITE
                                       );
  pRxCharacteristic->setCallbacks(new MyCallbacks());

  // Start service & advertising
  pService->start();
  pServer->getAdvertising()->start();
  Serial.println("ESP32 Coagulation BLE Server started. Ready for connection.");
}

double readTemperature() {
  if (useDummySensors) return currentTemp;
  // Read thermistor voltage and convert to Celsius
  int raw = analogRead(TEMP_PIN);
  double resistance = (4095.0 / raw) - 1.0;
  resistance = 10000.0 / resistance; // Assuming 10k thermistor
  // Steinhart-Hart equation or linear approximation
  double temp = 1.0 / (log(resistance / 10000.0) / 3950.0 + 1.0 / 298.15) - 273.15;
  return temp;
}

int readOpticalSensor() {
  if (useDummySensors) {
    if (currentState != MEASURING) return 920;
    
    // Simulate optical absorption sigmoid curve
    double elapsed = (millis() - measurementStartTime) / 1000.0;
    double exponent = -0.8 * (elapsed - simulatedPtTime);
    double sigmoid = 1.0 / (1.0 + exp(exponent));
    double rawValue = 920.0 - (920.0 - 340.0) * sigmoid;
    
    // Add small random noise
    return (int)(rawValue + random(-3, 3));
  }
  
  // Real sensor read
  return analogRead(OPTICAL_PIN);
}

void loop() {
  // Disconnect handler
  if (!deviceConnected && oldDeviceConnected) {
    delay(500); // Give the BLE stack time
    pServer->startAdvertising(); // Restart advertising
    Serial.println("Client disconnected. Restarting advertising...");
    currentState = IDLE;
    digitalWrite(HEATER_PIN, LOW);
    oldDeviceConnected = deviceConnected;
  }
  // Connect handler
  if (deviceConnected && !oldDeviceConnected) {
    oldDeviceConnected = deviceConnected;
    Serial.println("Client Connected!");
  }

  // State Machine Handling
  if (deviceConnected) {
    unsigned long now = millis();
    
    switch (currentState) {
      case IDLE:
        // Do nothing, wait for START command
        break;
        
      case HEATING:
        // Heat chamber to 37 degrees Celsius
        if (useDummySensors) {
          // Rise temp by 0.6 degrees every loop
          currentTemp += 0.6;
          if (currentTemp >= 37.0) currentTemp = 37.0;
        } else {
          currentTemp = readTemperature();
        }
        
        if (currentTemp >= 37.0) {
          digitalWrite(HEATER_PIN, LOW); // Maintain heating loop (simplified)
          currentState = INSERT_STRIP;
          sendStatusUpdate("insertStrip", 37.0);
          Serial.println("Target Temp reached (37C). Please insert strip.");
        } else {
          sendStatusUpdate("heating", currentTemp);
          delay(200);
        }
        break;
        
      case INSERT_STRIP:
        // Wait for strip insertion. In real app, you can hook a microswitch or optical interrupter.
        // For demonstration, we allow app to trigger it, or auto-detect if physical.
        if (!useDummySensors) {
          // If optical sensor detects strip block (e.g. signal drops below 100)
          if (analogRead(OPTICAL_PIN) < 200) {
            currentState = APPLY_BLOOD;
            sendStatusUpdate("applyBlood", 37.0);
            Serial.println("Strip detected. Waiting for blood sample.");
          }
        }
        delay(500);
        break;
        
      case APPLY_BLOOD:
        // Wait for blood drop.
        // In real app, optical value suddenly changes when blood fills the strip.
        if (!useDummySensors) {
          int opt = analogRead(OPTICAL_PIN);
          // Detect sudden drop in light when blood sample is applied
          if (opt > 500) { // adjusted to sensor calibration
            currentState = MEASURING;
            measurementStartTime = millis();
            sendStatusUpdate("measuring", 37.0);
            Serial.println("Blood detected! Starting clotting measurement...");
          }
        }
        delay(500);
        break;
        
      case MEASURING: {
        double elapsed = (now - measurementStartTime) / 1000.0;
        int sensorValue = readOpticalSensor();
        currentTemp = readTemperature();
        
        // Stream raw data point: {"type":"data","time":1.2,"value":910,"temp":37.0}
        String json = "{\"type\":\"data\",\"time\":" + String(elapsed, 1) + 
                      ",\"value\":" + String(sensorValue) + 
                      ",\"temp\":" + String(currentTemp, 1) + "}\n";
                      
        pTxCharacteristic->setValue(json.c_str());
        pTxCharacteristic->notify();
        
        // Stop measuring after 20 seconds
        double testDuration = useDummySensors ? (simulatedPtTime + 4.0) : 20.0;
        if (elapsed >= testDuration) {
          currentState = COMPLETED;
          double finalInr = pow((simulatedPtTime / 11.5), 1.05);
          
          // Send final results: {"type":"result","pt":12.8,"inr":1.12,"temp":37.0}
          String resultJson = "{\"type\":\"result\",\"pt\":" + String(simulatedPtTime, 1) + 
                              ",\"inr\":" + String(finalInr, 2) + 
                              ",\"temp\":" + String(currentTemp, 1) + "}\n";
                              
          pTxCharacteristic->setValue(resultJson.c_str());
          pTxCharacteristic->notify();
          
          Serial.println("Measurement finished. PT: " + String(simulatedPtTime, 1) + "s, INR: " + String(finalInr, 2));
        }
        delay(100); // 10Hz sampling
        break;
      }
      
      case COMPLETED:
        // Awaiting reset command from app
        break;
    }
  }
}
''';

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? CoagTheme.bgDark : CoagTheme.bgLight,
      appBar: AppBar(
        title: const Text("ESP32 Firmware Code"),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Arduino BLE Sketch",
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: isDark ? CoagTheme.textDarkPrimary : CoagTheme.textLightPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              "Flash this C++ code to your ESP32 board using Arduino IDE. "
              "It exposes the standard Nordic UART BLE Service to exchange JSON command packets "
              "and stream real-time coagulation telemetry to the app.",
              style: TextStyle(
                color: isDark ? CoagTheme.textDarkSecondary : CoagTheme.textLightSecondary,
                fontSize: 14,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 20),
            
            // Clipboard Copy Button Card
            InkWell(
              onTap: () {
                Clipboard.setData(const ClipboardData(text: esp32Sketch));
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: const Text('ESP32 Sketch copied to clipboard!'),
                    backgroundColor: CoagTheme.statusNormal,
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              },
              borderRadius: BorderRadius.circular(15),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: CoagTheme.primaryGradient,
                  borderRadius: BorderRadius.circular(15),
                  boxShadow: CoagTheme.getCardShadow(isDark),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: const [
                    Icon(Icons.copy, color: Colors.white),
                    SizedBox(width: 10),
                    Text(
                      "COPY SKETCH TO CLIPBOARD",
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Code Display View
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isDark ? CoagTheme.surfaceDark : Colors.white,
                borderRadius: BorderRadius.circular(15),
                border: Border.all(
                  color: isDark ? Colors.white.withOpacity(0.08) : Colors.black.withOpacity(0.05),
                ),
              ),
              child: const SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: SelectableText(
                  esp32Sketch,
                  style: TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 12,
                    height: 1.4,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
