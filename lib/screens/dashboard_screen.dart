import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import '../managers/coagulation_manager.dart';
import '../theme/coag_theme.dart';
import '../widgets/sensor_tile.dart';
import '../widgets/stage_progress_bar.dart';
import '../widgets/coag_chart.dart';
import '../widgets/gamma_chart.dart';
import '../widgets/status_badge.dart';
import 'history_screen.dart';
import 'esp32_code_screen.dart';
import 'results_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> with TickerProviderStateMixin {
  int _currentTab = 0;
  bool _isDarkTheme = true;
  bool _navigatedToResults = false;

  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: _isDarkTheme ? CoagTheme.darkTheme : CoagTheme.lightTheme,
      child: Builder(builder: (context) {
        final isDark = Theme.of(context).brightness == Brightness.dark;

        return Consumer<CoagulationManager>(
          builder: (context, manager, _) {
            // Auto-navigate to Results when measurement completes
            if (manager.measurementStage == 'done' &&
                manager.lastResult != null &&
                !_navigatedToResults) {
              _navigatedToResults = true;
              WidgetsBinding.instance.addPostFrameCallback((_) {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => ChangeNotifierProvider.value(
                      value: manager,
                      child: ResultsScreen(result: manager.lastResult!),
                    ),
                  ),
                ).then((_) {
                  _navigatedToResults = false;
                  manager.resetMeasurement();
                });
              });
            }

            final screens = [
              _MonitorTab(
                manager: manager,
                isDark: isDark,
                pulseController: _pulseController,
              ),
              const HistoryScreen(),
              const Esp32CodeScreen(),
            ];

            return Scaffold(
              appBar: AppBar(
                title: const Text('CoagMonitor Studio'),
                actions: [
                  IconButton(
                    icon: Icon(_isDarkTheme ? Icons.light_mode_outlined : Icons.dark_mode_outlined),
                    tooltip: _isDarkTheme ? 'Switch to Light Mode' : 'Switch to Dark Mode',
                    onPressed: () => setState(() => _isDarkTheme = !_isDarkTheme),
                  ),
                ],
              ),
              body: IndexedStack(index: _currentTab, children: screens),
              bottomNavigationBar: BottomNavigationBar(
                currentIndex: _currentTab,
                onTap: (i) => setState(() => _currentTab = i),
                selectedItemColor: CoagTheme.primary,
                unselectedItemColor: isDark ? Colors.white38 : Colors.black38,
                backgroundColor: isDark ? CoagTheme.surfaceDark : Colors.white,
                elevation: 12,
                type: BottomNavigationBarType.fixed,
                items: const [
                  BottomNavigationBarItem(icon: Icon(Icons.monitor_heart_outlined), label: 'Monitor'),
                  BottomNavigationBarItem(icon: Icon(Icons.history_rounded), label: 'History'),
                  BottomNavigationBarItem(icon: Icon(Icons.memory_rounded), label: 'ESP32 Code'),
                ],
              ),
            );
          },
        );
      }),
    );
  }
}

// ─────────────────────────────────────────────
// Monitor Tab — contains idle + measuring states
// ─────────────────────────────────────────────
class _MonitorTab extends StatelessWidget {
  final CoagulationManager manager;
  final bool isDark;
  final AnimationController pulseController;

  const _MonitorTab({
    required this.manager,
    required this.isDark,
    required this.pulseController,
  });

  @override
  Widget build(BuildContext context) {
    if (manager.isMeasuring) {
      return _MeasuringView(manager: manager, isDark: isDark);
    }
    return _IdleView(manager: manager, isDark: isDark, pulseController: pulseController);
  }
}

// ─────────────────────────────────────────────
// IDLE VIEW
// ─────────────────────────────────────────────
class _IdleView extends StatelessWidget {
  final CoagulationManager manager;
  final bool isDark;
  final AnimationController pulseController;

  const _IdleView({
    required this.manager,
    required this.isDark,
    required this.pulseController,
  });

  @override
  Widget build(BuildContext context) {
    final bg = isDark ? CoagTheme.bgDark : CoagTheme.bgLight;
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Mode selector card
          _buildModeCard(context),
          const SizedBox(height: 14),

          // Show BLE scanner if in hardware mode and not connected
          if (!manager.isSimulationMode &&
              manager.connectionState != BluetoothConnectionState.connected)
            _buildBleScannerPanel(context)
          else ...[
            // Current Stage row
            _buildStageRow(),
            const SizedBox(height: 14),

            // Live Sensor 2x2 Grid
            _buildSensorGrid(),
            const SizedBox(height: 14),

            // Central idle graphic
            _buildIdleGraphic(context),
            const SizedBox(height: 14),

            // Signal Quality badge
            _buildSignalQualityRow(),
            const SizedBox(height: 14),

            // START button
            _buildStartButton(context),
          ],

          // Error panel
          if (manager.measurementStage == 'error')
            _buildErrorPanel(),
        ],
      ),
    );
  }

  Widget _buildModeCard(BuildContext context) {
    return _Card(
      isDark: isDark,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(children: [
            Icon(
              manager.isSimulationMode ? Icons.bolt : Icons.bluetooth_connected,
              color: CoagTheme.primary,
              size: 20,
            ),
            const SizedBox(width: 10),
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(
                'Mode: ${manager.isSimulationMode ? 'Simulator' : 'ESP32 Bluetooth'}',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
              ),
              Text(
                manager.isSimulationMode
                    ? 'Full feature testing without hardware'
                    : manager.connectionState == BluetoothConnectionState.connected
                        ? 'Connected: ${manager.connectedDevice?.platformName ?? 'ESP32'}'
                        : 'Disconnected from hardware',
                style: TextStyle(
                  fontSize: 11,
                  color: isDark ? CoagTheme.textDarkSecondary : CoagTheme.textLightSecondary,
                ),
              ),
            ]),
          ]),
          Switch(
            value: manager.isSimulationMode,
            onChanged: (val) => manager.toggleSimulationMode(val),
            activeColor: CoagTheme.primary,
          ),
        ],
      ),
    );
  }

  Widget _buildStageRow() {
    return _Card(
      isDark: isDark,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            'Current Stage',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 13,
              color: isDark ? CoagTheme.textDarkPrimary : CoagTheme.textLightPrimary,
            ),
          ),
          StatusBadge(label: 'SYSTEM IDLE', type: 'IDLE'),
        ],
      ),
    );
  }

  Widget _buildSensorGrid() {
    return GridView.count(
      crossAxisCount: 2,
      crossAxisSpacing: 10,
      mainAxisSpacing: 10,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      childAspectRatio: 1.9,
      children: [
        SensorTile(
          label: 'ADC Raw Value',
          value: manager.adcRaw.toString(),
          unit: 'counts',
          icon: Icons.graphic_eq,
          isDark: isDark,
          accentColor: CoagTheme.accentCyan,
        ),
        SensorTile(
          label: 'DC Intensity',
          value: manager.dcIntensity.toStringAsFixed(2),
          unit: 'V',
          icon: Icons.flash_on_rounded,
          isDark: isDark,
          accentColor: CoagTheme.signalGood,
        ),
        SensorTile(
          label: 'Cuff Pressure',
          value: manager.pressureMmhg.toStringAsFixed(0),
          unit: 'mmHg',
          icon: Icons.compress_rounded,
          isDark: isDark,
          accentColor: CoagTheme.statusElevated,
        ),
        SensorTile(
          label: 'Skin Temp',
          value: manager.skinTempC.toStringAsFixed(1),
          unit: '°C',
          icon: Icons.thermostat_rounded,
          isDark: isDark,
          accentColor: CoagTheme.signalWeak,
        ),
      ],
    );
  }

  Widget _buildIdleGraphic(BuildContext context) {
    return _Card(
      isDark: isDark,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 20),
        child: Column(
          children: [
            ScaleTransition(
              scale: Tween(begin: 0.94, end: 1.06).animate(
                CurvedAnimation(parent: pulseController, curve: Curves.easeInOut),
              ),
              child: Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: CoagTheme.primaryGradient,
                  boxShadow: [
                    BoxShadow(
                      color: CoagTheme.primary.withOpacity(0.4),
                      blurRadius: 20,
                      spreadRadius: 3,
                    )
                  ],
                ),
                child: const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 42),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'CoagMonitor Ready',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),
            Text(
              'Start a new measurement cycle.\nEnsure finger cuff is positioned correctly on proximal\nphalanx and fingertip sensor is seated firmly.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                height: 1.5,
                color: isDark ? CoagTheme.textDarkSecondary : CoagTheme.textLightSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSignalQualityRow() {
    return Row(
      children: [
        Text(
          'Signal Quality:',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: isDark ? CoagTheme.textDarkSecondary : CoagTheme.textLightSecondary,
          ),
        ),
        const SizedBox(width: 10),
        StatusBadge(label: manager.signalQuality, type: manager.signalQuality),
      ],
    );
  }

  Widget _buildStartButton(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: CoagTheme.primaryGradient,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: CoagTheme.primary.withOpacity(0.35),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: ElevatedButton(
          onPressed: () => manager.startMeasurement(),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.transparent,
            shadowColor: Colors.transparent,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          ),
          child: const Text(
            'START MEASUREMENT CYCLE',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 14,
              letterSpacing: 1,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildErrorPanel() {
    return Padding(
      padding: const EdgeInsets.only(top: 14),
      child: _Card(
        isDark: isDark,
        child: Row(children: [
          Icon(Icons.warning_amber_rounded, color: CoagTheme.signalPoor),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              manager.errorMessage,
              style: const TextStyle(color: CoagTheme.signalPoor, fontSize: 12),
            ),
          ),
        ]),
      ),
    );
  }

  Widget _buildBleScannerPanel(BuildContext context) {
    return _Card(
      isDark: isDark,
      child: Column(
        children: [
          Icon(
            Icons.bluetooth_searching_rounded,
            size: 48,
            color: manager.isScanning ? CoagTheme.primary : CoagTheme.textDarkSecondary,
          ),
          const SizedBox(height: 10),
          const Text('Connect Coagulation Device',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 6),
          Text(
            "Power on your ESP32 monitor. It should advertise as 'ESP32-Coag-Monitor'.",
            textAlign: TextAlign.center,
            style: TextStyle(
                fontSize: 12,
                color: isDark ? CoagTheme.textDarkSecondary : CoagTheme.textLightSecondary),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            height: 46,
            child: ElevatedButton(
              onPressed: manager.isScanning ? null : () => manager.startBleScan(),
              style: ElevatedButton.styleFrom(
                backgroundColor: CoagTheme.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: manager.isScanning
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : const Text('SCAN FOR DEVICES', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ),
          if (manager.scannedDevices.isNotEmpty) ...[
            const SizedBox(height: 16),
            ...manager.scannedDevices.map((result) {
              final name = result.device.platformName.isNotEmpty
                  ? result.device.platformName
                  : 'Unknown Device';
              return ListTile(
                dense: true,
                title: Text(name, style: const TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Text(result.device.remoteId.toString()),
                trailing: ElevatedButton(
                  onPressed: () => manager.connectDevice(result.device),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: CoagTheme.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    minimumSize: const Size(70, 32),
                  ),
                  child: const Text('Connect', style: TextStyle(fontSize: 12)),
                ),
              );
            }),
          ],
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
// MEASURING VIEW
// ─────────────────────────────────────────────
class _MeasuringView extends StatelessWidget {
  final CoagulationManager manager;
  final bool isDark;

  const _MeasuringView({required this.manager, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Top area: stage progress + countdown
        Container(
          color: isDark ? CoagTheme.surfaceDark : Colors.white,
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          child: Column(
            children: [
              StageProgressBar(currentStage: manager.measurementStage),
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  StatusBadge(
                    label: manager.measurementStage.toUpperCase(),
                    type: manager.measurementStage.toUpperCase(),
                  ),
                  Text(
                    '${manager.stageRemainingSeconds.toStringAsFixed(1)}s remaining',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: CoagTheme.accentCyan,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const Divider(height: 1, thickness: 1),

        // Live sensor readings strip
        Container(
          color: isDark ? CoagTheme.bgDark : CoagTheme.bgLight,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _MiniStat('ADC', manager.adcRaw.toString(), CoagTheme.accentCyan),
              _MiniStat('Γ Hz', manager.gammaHz.toStringAsFixed(1), CoagTheme.primary),
              _MiniStat('Pressure', '${manager.pressureMmhg.toStringAsFixed(0)} mmHg', CoagTheme.statusElevated),
              _MiniStat('Temp', '${manager.skinTempC.toStringAsFixed(1)}°C', CoagTheme.signalWeak),
            ],
          ),
        ),

        // Graphs — take remaining vertical space
        Expanded(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              children: [
                // Graph 1: Raw ADC signal (cyan, rolling 5s)
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: isDark ? CoagTheme.surfaceDark : Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                          color: isDark ? Colors.white12 : Colors.black12),
                    ),
                    padding: const EdgeInsets.fromLTRB(10, 10, 14, 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(children: [
                          Container(width: 12, height: 3, color: CoagTheme.accentCyan,
                              margin: const EdgeInsets.only(right: 6)),
                          Text('Raw Photodiode Signal',
                              style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: isDark ? CoagTheme.textDarkSecondary : CoagTheme.textLightSecondary)),
                        ]),
                        const SizedBox(height: 6),
                        Expanded(child: CoagChart(curvePoints: manager.adcPoints.toList())),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                // Graph 2: Gamma decay
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: isDark ? CoagTheme.surfaceDark : Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                          color: isDark ? Colors.white12 : Colors.black12),
                    ),
                    padding: const EdgeInsets.fromLTRB(10, 10, 14, 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(children: [
                          Container(width: 12, height: 3, color: CoagTheme.primary,
                              margin: const EdgeInsets.only(right: 6)),
                          Text('Gamma Decay (Γ Hz)',
                              style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: isDark ? CoagTheme.textDarkSecondary : CoagTheme.textLightSecondary)),
                          if (manager.gammaAsymptote != null) ...[
                            const SizedBox(width: 8),
                            Container(width: 16, height: 2,
                                color: CoagTheme.accentCyan.withOpacity(0.7),
                                margin: const EdgeInsets.only(right: 4)),
                            Text('Γ∞ ${manager.gammaAsymptote!.toStringAsFixed(1)} Hz',
                                style: const TextStyle(
                                    fontSize: 10, color: CoagTheme.accentCyan)),
                          ],
                        ]),
                        const SizedBox(height: 6),
                        Expanded(
                          child: GammaChart(
                            gammaPoints: manager.gammaPoints.toList(),
                            asymptote: manager.gammaAsymptote,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),

        // ABORT button
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
          child: SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton.icon(
              onPressed: () => manager.abortMeasurement(),
              icon: const Icon(Icons.stop_circle_outlined, color: Colors.white),
              label: const Text('ABORT MEASUREMENT',
                  style: TextStyle(
                      color: Colors.white, fontWeight: FontWeight.bold, letterSpacing: 0.8)),
              style: ElevatedButton.styleFrom(
                backgroundColor: CoagTheme.signalPoor,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                elevation: 0,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _MiniStat extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  const _MiniStat(this.label, this.value, this.color);

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(label, style: TextStyle(fontSize: 9, color: color, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
        const SizedBox(height: 2),
        Text(value, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w900, color: color)),
      ],
    );
  }
}

// ─────────────────────────────────────────────
// Shared card container
// ─────────────────────────────────────────────
class _Card extends StatelessWidget {
  final bool isDark;
  final Widget child;
  final EdgeInsets? padding;

  const _Card({required this.isDark, required this.child, this.padding});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: padding ?? const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? CoagTheme.surfaceDark : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? Colors.white.withOpacity(0.07) : Colors.black.withOpacity(0.05),
        ),
        boxShadow: CoagTheme.getCardShadow(isDark),
      ),
      child: child,
    );
  }
}