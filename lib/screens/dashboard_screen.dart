import 'dart:math';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import '../managers/coagulation_manager.dart';
import '../theme/coag_theme.dart';
import '../widgets/coag_chart.dart';
import '../widgets/status_badge.dart';
import 'history_screen.dart';
import 'esp32_code_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> with TickerProviderStateMixin {
  int _currentTab = 0;
  bool _isDarkTheme = true; // Premium Dark Theme by default

  late AnimationController _pulseController;
  late AnimationController _rotateController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);

    _rotateController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _rotateController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Provide a customized theme overlay to allow quick dynamic dark/light toggling
    return Theme(
      data: _isDarkTheme ? CoagTheme.darkTheme : CoagTheme.lightTheme,
      child: Builder(
        builder: (context) {
          final isDark = Theme.of(context).brightness == Brightness.dark;
          
          final List<Widget> screens = [
            _buildTestPanel(context, isDark),
            const HistoryScreen(),
            const Esp32CodeScreen(),
          ];

          return Scaffold(
            appBar: AppBar(
              title: const Text("CoagMonitor Studio"),
              actions: [
                IconButton(
                  icon: Icon(_isDarkTheme ? Icons.light_mode : Icons.dark_mode),
                  tooltip: _isDarkTheme ? "Switch to Light Mode" : "Switch to Dark Mode",
                  onPressed: () {
                    setState(() {
                      _isDarkTheme = !_isDarkTheme;
                    });
                  },
                ),
              ],
            ),
            body: screens[_currentTab],
            bottomNavigationBar: BottomNavigationBar(
              currentIndex: _currentTab,
              onTap: (index) => setState(() => _currentTab = index),
              selectedItemColor: CoagTheme.primary,
              unselectedItemColor: isDark ? Colors.white54 : Colors.black45,
              backgroundColor: isDark ? CoagTheme.surfaceDark : Colors.white,
              elevation: 10,
              items: const [
                BottomNavigationBarItem(
                  icon: Icon(Icons.speed),
                  label: "Monitor",
                ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.history),
                  label: "History",
                ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.code),
                  label: "ESP32 Code",
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  // --- MAIN MONITOR PANEL ---
  Widget _buildTestPanel(BuildContext context, bool isDark) {
    return Consumer<CoagulationManager>(
      builder: (context, manager, child) {
        return SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. Connection Mode Selector (Simulated vs Hardware BLE)
              _buildConfigSelectorCard(context, manager, isDark),
              const SizedBox(height: 16),

              // 2. Active Screen Content
              if (!manager.isSimulationMode && manager.connectionState != BluetoothConnectionState.connected)
                _buildBleScannerPanel(context, manager, isDark)
              else
                _buildActiveMonitorPanel(context, manager, isDark),
            ],
          ),
        );
      },
    );
  }

  // --- HARDWARE CONFIGURATION / MODE SELECTOR CARD ---
  Widget _buildConfigSelectorCard(BuildContext context, CoagulationManager manager, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? CoagTheme.surfaceDark : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark ? Colors.white.withOpacity(0.08) : Colors.black.withOpacity(0.05),
        ),
        boxShadow: CoagTheme.getCardShadow(isDark),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(
                    manager.isSimulationMode ? Icons.bolt_outlined : Icons.bluetooth_connected,
                    color: CoagTheme.primary,
                  ),
                  const SizedBox(width: 10),
                  Text(
                    "Mode: ${manager.isSimulationMode ? 'Simulator' : 'ESP32 Bluetooth'}",
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                ],
              ),
              Switch(
                value: manager.isSimulationMode,
                onChanged: (val) => manager.toggleSimulationMode(val),
                activeColor: CoagTheme.primary,
              ),
            ],
          ),
          if (manager.isSimulationMode)
            Padding(
              padding: const EdgeInsets.only(top: 8.0),
              child: Text(
                "Running in Simulator Mode. You can experience the full measurement loop and data graphs without connecting physical hardware.",
                style: TextStyle(
                  fontSize: 12,
                  color: isDark ? CoagTheme.textDarkSecondary : CoagTheme.textLightSecondary,
                  height: 1.4,
                ),
              ),
            )
          else
            Padding(
              padding: const EdgeInsets.only(top: 8.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    manager.connectionState == BluetoothConnectionState.connected
                        ? "Connected: ${manager.connectedDevice?.platformName ?? 'ESP32 Monitor'}"
                        : "Disconnected from hardware",
                    style: TextStyle(
                      fontSize: 12,
                      color: manager.connectionState == BluetoothConnectionState.connected
                          ? CoagTheme.statusNormal
                          : CoagTheme.statusHigh,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  if (manager.connectionState == BluetoothConnectionState.connected)
                    TextButton(
                      onPressed: () => manager.disconnectDevice(),
                      style: TextButton.styleFrom(
                        padding: EdgeInsets.zero,
                        minimumSize: const Size(50, 30),
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      child: const Text("Disconnect", style: TextStyle(color: CoagTheme.statusHigh)),
                    )
                ],
              ),
            ),
        ],
      ),
    );
  }

  // --- BLE SCANNER PANEL (When hardware mode active but disconnected) ---
  Widget _buildBleScannerPanel(BuildContext context, CoagulationManager manager, bool isDark) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? CoagTheme.surfaceDark : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark ? Colors.white.withOpacity(0.08) : Colors.black.withOpacity(0.05),
        ),
        boxShadow: CoagTheme.getCardShadow(isDark),
      ),
      child: Column(
        children: [
          Icon(
            Icons.bluetooth_searching,
            size: 50,
            color: manager.isScanning ? CoagTheme.primary : (isDark ? CoagTheme.textDarkSecondary : CoagTheme.textLightSecondary),
          ),
          const SizedBox(height: 12),
          const Text(
            "Connect Coagulation Device",
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
          ),
          const SizedBox(height: 6),
          Text(
            "Power on your ESP32 monitor. It should advertise as 'ESP32-Coag-Monitor'.",
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              color: isDark ? CoagTheme.textDarkSecondary : CoagTheme.textLightSecondary,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 20),

          // Scan Control Button
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              onPressed: manager.isScanning ? null : () => manager.startBleScan(),
              style: ElevatedButton.styleFrom(
                backgroundColor: CoagTheme.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: manager.isScanning
                  ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                    )
                  : const Text("SCAN FOR DEVICES", style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ),

          if (manager.scannedDevices.isNotEmpty) ...[
            const SizedBox(height: 20),
            const Align(
              alignment: Alignment.centerLeft,
              child: Text(
                "Devices Found:",
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              ),
            ),
            const SizedBox(height: 10),
            Container(
              constraints: const BoxConstraints(maxHeight: 250),
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: manager.scannedDevices.length,
                itemBuilder: (context, index) {
                  final result = manager.scannedDevices[index];
                  final name = result.device.platformName.isNotEmpty
                      ? result.device.platformName
                      : "Unknown Device";
                  final address = result.device.remoteId.toString();

                  return Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    color: isDark ? CoagTheme.cardDark : CoagTheme.cardLight,
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    child: ListTile(
                      title: Text(
                        name,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                      ),
                      subtitle: Text(address, style: const TextStyle(fontSize: 11)),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.wifi, size: 16, color: _getRssiColor(result.rssi)),
                          const SizedBox(width: 4),
                          Text("${result.rssi} dBm", style: const TextStyle(fontSize: 10)),
                          const SizedBox(width: 10),
                          ElevatedButton(
                            onPressed: () => manager.connectDevice(result.device),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: CoagTheme.primary,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(horizontal: 12),
                              minimumSize: const Size(60, 32),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                            child: const Text("Connect", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                          )
                        ],
                      ),
                    ),
                  );
                },
              ),
            )
          ] else if (!manager.isScanning) ...[
            const SizedBox(height: 20),
            Text(
              "No devices discovered yet. Click scan to begin searching.",
              style: TextStyle(
                fontSize: 12,
                color: (isDark ? CoagTheme.textDarkSecondary : CoagTheme.textLightSecondary).withOpacity(0.7),
                fontStyle: FontStyle.italic,
              ),
            )
          ]
        ],
      ),
    );
  }

  // Helper RSSI color mapping
  Color _getRssiColor(int rssi) {
    if (rssi > -60) return CoagTheme.statusNormal;
    if (rssi > -80) return CoagTheme.statusElevated;
    return CoagTheme.statusHigh;
  }

  // --- ACTIVE MONITOR PANEL (Wired up when simulator or connected) ---
  Widget _buildActiveMonitorPanel(BuildContext context, CoagulationManager manager, bool isDark) {
    return Column(
      children: [
        // Measurement Phase Indicator Widget
        _buildStateIndicatorCard(context, manager, isDark),
        const SizedBox(height: 16),

        // Core Workspace (Graph or dynamic status panel depending on states)
        _buildMeasurementMainDisplay(context, manager, isDark),
        const SizedBox(height: 16),

        // Action Trigger Button Panel
        _buildActionControlButtons(context, manager, isDark),
      ],
    );
  }

  // --- MEASUREMENT STATE BADGE CARD ---
  Widget _buildStateIndicatorCard(BuildContext context, CoagulationManager manager, bool isDark) {
    String label = "System Idle";
    switch (manager.measurementState) {
      case 'heating':
        label = "Chamber Heating";
        break;
      case 'insertStrip':
        label = "Insert Strip";
        break;
      case 'applyBlood':
        label = "Apply Blood Sample";
        break;
      case 'measuring':
        label = "Analyzing Blood Clotting";
        break;
      case 'completed':
        label = "Test Completed";
        break;
      case 'error':
        label = "Hardware Error";
        break;
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: isDark ? CoagTheme.surfaceDark : Colors.white,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(
          color: isDark ? Colors.white.withOpacity(0.08) : Colors.black.withOpacity(0.05),
        ),
        boxShadow: CoagTheme.getCardShadow(isDark),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text(
            "Current Stage",
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
          ),
          StatusBadge(label: label, type: manager.measurementState),
        ],
      ),
    );
  }

  // --- CORE VISUAL DISPLAY (Warming circle, real-time graph, or final medical report card) ---
  Widget _buildMeasurementMainDisplay(BuildContext context, CoagulationManager manager, bool isDark) {
    return Container(
      width: double.infinity,
      height: 350,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? CoagTheme.surfaceDark : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark ? Colors.white.withOpacity(0.08) : Colors.black.withOpacity(0.05),
        ),
        boxShadow: CoagTheme.getCardShadow(isDark),
      ),
      child: _buildPhaseSpecificContent(context, manager, isDark),
    );
  }

  Widget _buildPhaseSpecificContent(BuildContext context, CoagulationManager manager, bool isDark) {
    switch (manager.measurementState) {
      case 'idle':
        return Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ScaleTransition(
                scale: Tween(begin: 0.95, end: 1.05).animate(
                  CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
                ),
                child: Container(
                  width: 90,
                  height: 90,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: CoagTheme.primaryGradient,
                    boxShadow: [
                      BoxShadow(
                        color: CoagTheme.primary.withOpacity(0.4),
                        blurRadius: 15,
                        spreadRadius: 2,
                      )
                    ],
                  ),
                  child: const Icon(Icons.play_arrow, color: Colors.white, size: 45),
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                "CoagMonitor Ready",
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                "Start a new measurement cycle.\nEnsure a testing strip is on hand.",
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13,
                  color: isDark ? CoagTheme.textDarkSecondary : CoagTheme.textLightSecondary,
                  height: 1.4,
                ),
              ),
            ],
          ),
        );

      case 'heating':
        double progress = (manager.currentTemp - 24.5) / (37.0 - 24.5);
        progress = progress.clamp(0.0, 1.0);

        return Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Stack(
                alignment: Alignment.center,
                children: [
                  RotationTransition(
                    turns: _rotateController,
                    child: SizedBox(
                      width: 120,
                      height: 120,
                      child: CircularProgressIndicator(
                        value: progress,
                        strokeWidth: 8,
                        color: CoagTheme.statusElevated,
                        backgroundColor: isDark ? Colors.white10 : Colors.black12,
                      ),
                    ),
                  ),
                  Icon(Icons.thermostat, color: CoagTheme.statusElevated, size: 50),
                ],
              ),
              const SizedBox(height: 24),
              Text(
                "Heating Chamber...",
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                "${manager.currentTemp.toStringAsFixed(1)}°C / 37.0°C",
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w900,
                  color: CoagTheme.statusElevated,
                ),
              ),
              const SizedBox(height: 4),
              const Text("Incubating to core body temperature", style: TextStyle(fontSize: 12, color: Colors.grey)),
            ],
          ),
        );

      case 'insertStrip':
        return Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              AnimatedBuilder(
                animation: _pulseController,
                builder: (context, child) {
                  return Transform.translate(
                    offset: Offset(0, -10 * _pulseController.value),
                    child: Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: CoagTheme.primary.withOpacity(0.12),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(Icons.input_rounded, color: CoagTheme.primary, size: 60),
                    ),
                  );
                },
              ),
              const SizedBox(height: 20),
              const Text(
                "Insert Strip",
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              const Text(
                "Slide the testing strip cartridge into the bottom slot.",
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, color: Colors.grey),
              ),
              if (manager.isSimulationMode) ...[
                const SizedBox(height: 20),
                ElevatedButton(
                  onPressed: () => manager.insertStrip(),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: CoagTheme.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  child: const Text("Simulate Strip Insertion", style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ],
            ],
          ),
        );

      case 'applyBlood':
        return Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ScaleTransition(
                scale: Tween(begin: 0.9, end: 1.1).animate(
                  CurvedAnimation(parent: _pulseController, curve: Curves.elasticOut),
                ),
                child: Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: CoagTheme.statusHigh.withOpacity(0.12),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.bloodtype, color: CoagTheme.statusHigh, size: 60),
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                "Apply Blood Sample",
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              const Text(
                "Dispense a single drop of whole blood onto the well.",
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, color: Colors.grey),
              ),
              if (manager.isSimulationMode) ...[
                const SizedBox(height: 20),
                ElevatedButton(
                  onPressed: () => manager.applyBlood(),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: CoagTheme.statusHigh,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  child: const Text("Simulate Blood Application", style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ],
            ],
          ),
        );

      case 'measuring':
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Live Stats Row
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildLiveTelemetryItem("Time", "${manager.elapsedSeconds.toStringAsFixed(1)}s"),
                _buildLiveTelemetryItem("Signal", "${manager.currentSensorValue.toInt()}"),
                _buildLiveTelemetryItem("Temp", "${manager.currentTemp.toStringAsFixed(1)}°C"),
              ],
            ),
            const Divider(height: 20, thickness: 1),
            // The Live Chart
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(top: 8.0, right: 8.0),
                child: CoagChart(curvePoints: manager.curvePoints),
              ),
            ),
          ],
        );

      case 'completed':
        final inrStr = manager.finalINR?.toStringAsFixed(2) ?? "--";
        final ptStr = manager.finalPT?.toStringAsFixed(1) ?? "--";
        
        // Calculate status mapping locally
        String status = 'Normal';
        if (manager.finalINR != null) {
          double inr = manager.finalINR!;
          if (inr < 0.8) status = 'Low';
          else if (inr >= 0.8 && inr <= 1.2) status = 'Normal';
          else if (inr > 1.2 && inr < 2.0) status = 'Elevated';
          else if (inr >= 2.0 && inr <= 3.0) status = 'Therapeutic';
          else if (inr > 3.0 && inr <= 4.0) status = 'High';
          else status = 'Critical';
        }
        final statusColor = CoagTheme.getStatusColor(status);

        return Column(
          children: [
            const Text(
              "ANALYSIS COMPLETED",
              style: TextStyle(fontWeight: FontWeight.w900, fontSize: 14, letterSpacing: 1.5, color: Colors.grey),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildCompletedMetricCard("INR INDEX", inrStr, statusColor, true),
                _buildCompletedMetricCard("CLOT TIME", "${ptStr}s", isDark ? Colors.white : Colors.black, false),
              ],
            ),
            const SizedBox(height: 16),
            // Status Banner Description
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: statusColor.withOpacity(0.08),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: statusColor.withOpacity(0.2), width: 1),
              ),
              child: Row(
                children: [
                  Icon(Icons.shield_outlined, color: statusColor, size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      "Safety Status: ${status.toUpperCase()}",
                      style: TextStyle(
                        color: statusColor,
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const Spacer(),
            Text(
              "Saved to logs database automatically.",
              style: TextStyle(fontSize: 11, color: isDark ? Colors.white30 : Colors.black38, fontStyle: FontStyle.italic),
            ),
          ],
        );

      case 'error':
        return Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: CoagTheme.statusHigh.withOpacity(0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.warning_amber_rounded, color: CoagTheme.statusHigh, size: 50),
              ),
              const SizedBox(height: 16),
              const Text(
                "Hardware Connection Alert",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text(
                  manager.errorMessage,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 13, color: Colors.grey, height: 1.4),
                ),
              ),
            ],
          ),
        );

      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildLiveTelemetryItem(String title, String value) {
    return Column(
      children: [
        Text(
          title.toUpperCase(),
          style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 0.5, color: Colors.grey),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
        ),
      ],
    );
  }

  Widget _buildCompletedMetricCard(String title, String value, Color color, bool highlighted) {
    return Column(
      children: [
        Text(
          title,
          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey),
        ),
        const SizedBox(height: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          decoration: BoxDecoration(
            color: color.withOpacity(highlighted ? 0.12 : 0.05),
            borderRadius: BorderRadius.circular(15),
            border: Border.all(color: color.withOpacity(highlighted ? 0.3 : 0.1), width: 1),
          ),
          child: Text(
            value,
            style: TextStyle(
              fontSize: 34,
              fontWeight: FontWeight.w900,
              color: color,
            ),
          ),
        ),
      ],
    );
  }

  // --- BUTTON CONTROL BAR (Start, Cancel, Reset depending on current run state) ---
  Widget _buildActionControlButtons(BuildContext context, CoagulationManager manager, bool isDark) {
    final state = manager.measurementState;

    if (state == 'idle') {
      return SizedBox(
        width: double.infinity,
        height: 60,
        child: Container(
          decoration: BoxDecoration(
            gradient: CoagTheme.primaryGradient,
            borderRadius: BorderRadius.circular(16),
            boxShadow: CoagTheme.getCardShadow(isDark),
          ),
          child: ElevatedButton(
            onPressed: () => manager.startMeasurement(),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.transparent,
              foregroundColor: Colors.white,
              shadowColor: Colors.transparent,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            child: const Text(
              "START MEASUREMENT CYCLE",
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 0.5),
            ),
          ),
        ),
      );
    }

    // Cancel or Reset state buttons
    return Row(
      children: [
        Expanded(
          child: SizedBox(
            height: 55,
            child: OutlinedButton(
              onPressed: () => manager.resetMeasurement(),
              style: OutlinedButton.styleFrom(
                side: BorderSide(color: CoagTheme.statusHigh.withOpacity(0.5)),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: Text(
                state == 'completed' ? "NEW RUN" : "ABORT / RESET",
                style: const TextStyle(color: CoagTheme.statusHigh, fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ),
      ],
    );
  }
}