import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../managers/coagulation_manager.dart';
import '../models/measurement_result.dart';
import '../theme/coag_theme.dart';
import '../widgets/coag_chart.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  String _searchQuery = "";

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Scaffold(
      backgroundColor: isDark ? CoagTheme.bgDark : CoagTheme.bgLight,
      appBar: AppBar(
        title: const Text("Measurement History"),
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_sweep_outlined),
            tooltip: "Clear All",
            onPressed: () => _confirmClearHistory(context),
          )
        ],
      ),
      body: Column(
        children: [
          // Search & Filters Panel
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              onChanged: (val) => setState(() => _searchQuery = val.toLowerCase()),
              decoration: InputDecoration(
                hintText: "Search by status (e.g. Normal, Therapeutic)...",
                prefixIcon: const Icon(Icons.search),
                filled: true,
                fillColor: isDark ? CoagTheme.surfaceDark : Colors.white,
                contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 16),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(15),
                  borderSide: BorderSide(
                    color: isDark ? Colors.white.withOpacity(0.08) : Colors.black.withOpacity(0.05),
                  ),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(15),
                  borderSide: BorderSide(
                    color: isDark ? Colors.white.withOpacity(0.08) : Colors.black.withOpacity(0.05),
                  ),
                ),
              ),
            ),
          ),
          
          Expanded(
            child: Consumer<CoagulationManager>(
              builder: (context, manager, child) {
                final filteredList = manager.history.where((result) {
                  return result.status.toLowerCase().contains(_searchQuery) ||
                         DateFormat('yyyy-MM-dd HH:mm')
                             .format(result.timestamp)
                             .contains(_searchQuery);
                }).toList();

                if (filteredList.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.history_toggle_off,
                          size: 60,
                          color: isDark ? CoagTheme.textDarkSecondary : CoagTheme.textLightSecondary,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          manager.history.isEmpty ? "No records found" : "No matching records",
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: isDark ? CoagTheme.textDarkPrimary : CoagTheme.textLightPrimary,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          manager.history.isEmpty 
                            ? "Completed runs will automatically save here."
                            : "Try adjusting your search criteria.",
                          style: TextStyle(
                            color: isDark ? CoagTheme.textDarkSecondary : CoagTheme.textLightSecondary,
                          ),
                        ),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: filteredList.length,
                  itemBuilder: (context, index) {
                    final item = filteredList[index];
                    return _buildHistoryCard(context, item, isDark);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHistoryCard(BuildContext context, MeasurementResult result, bool isDark) {
    final statusColor = CoagTheme.getStatusColor(result.status);
    final formattedDate = DateFormat('MMM d, yyyy  •  hh:mm a').format(result.timestamp);

    return Dismissible(
      key: Key(result.id),
      direction: DismissDirection.endToStart,
      background: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.only(right: 20),
        decoration: BoxDecoration(
          color: CoagTheme.statusHigh,
          borderRadius: BorderRadius.circular(20),
        ),
        alignment: Alignment.centerRight,
        child: const Icon(Icons.delete, color: Colors.white, size: 28),
      ),
      confirmDismiss: (direction) async {
        return await showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text("Delete Record"),
            content: const Text("Are you sure you want to delete this measurement from history?"),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text("CANCEL"),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text("DELETE", style: TextStyle(color: CoagTheme.statusHigh)),
              ),
            ],
          ),
        );
      },
      onDismissed: (direction) {
        Provider.of<CoagulationManager>(context, listen: false).deleteHistoryItem(result.id);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Record deleted"),
            behavior: SnackBarBehavior.floating,
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: isDark ? CoagTheme.surfaceDark : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isDark ? Colors.white.withOpacity(0.08) : Colors.black.withOpacity(0.05),
          ),
          boxShadow: CoagTheme.getCardShadow(isDark),
        ),
        child: InkWell(
          onTap: () => _showResultDetails(context, result),
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                // Safe Status Colored Bar
                Container(
                  width: 5,
                  height: 60,
                  decoration: BoxDecoration(
                    color: statusColor,
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                const SizedBox(width: 16),

                // Main Info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        formattedDate,
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark ? CoagTheme.textDarkSecondary : CoagTheme.textLightSecondary,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          _buildValueLabel("INR", result.inr.toStringAsFixed(2)),
                          const SizedBox(width: 20),
                          _buildValueLabel("PT", "${result.pt.toStringAsFixed(1)}s"),
                        ],
                      ),
                    ],
                  ),
                ),

                // Status Indicator
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(30),
                    border: Border.all(color: statusColor.withOpacity(0.2), width: 1),
                  ),
                  child: Text(
                    result.status.toUpperCase(),
                    style: TextStyle(
                      color: statusColor,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
                const SizedBox(width: 4),
                Icon(
                  Icons.chevron_right,
                  color: isDark ? CoagTheme.textDarkSecondary : CoagTheme.textLightSecondary,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildValueLabel(String label, String value) {
    return RichText(
      text: TextSpan(
        children: [
          TextSpan(
            text: "$label: ",
            style: const TextStyle(
              fontSize: 14,
              color: Colors.grey,
              fontWeight: FontWeight.w500,
            ),
          ),
          TextSpan(
            text: value,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Theme.of(context).brightness == Brightness.dark 
                ? CoagTheme.textDarkPrimary 
                : CoagTheme.textLightPrimary,
            ),
          ),
        ],
      ),
    );
  }

  void _confirmClearHistory(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Clear History"),
        content: const Text("Are you sure you want to delete all historical logs? This cannot be undone."),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text("CANCEL"),
          ),
          TextButton(
            onPressed: () {
              Provider.of<CoagulationManager>(context, listen: false).clearHistory();
              Navigator.of(context).pop();
            },
            child: const Text("CLEAR ALL", style: TextStyle(color: CoagTheme.statusHigh)),
          ),
        ],
      ),
    );
  }

  void _showResultDetails(BuildContext context, MeasurementResult result) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final statusColor = CoagTheme.getStatusColor(result.status);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          height: MediaQuery.of(context).size.height * 0.85,
          decoration: BoxDecoration(
            color: isDark ? CoagTheme.bgDark : CoagTheme.bgLight,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
          ),
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Pull Bar
              Center(
                child: Container(
                  width: 50,
                  height: 5,
                  decoration: BoxDecoration(
                    color: isDark ? Colors.white.withOpacity(0.2) : Colors.black.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // Title
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        "Test Details",
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        DateFormat('MMMM d, yyyy  •  hh:mm a').format(result.timestamp),
                        style: TextStyle(
                          fontSize: 13,
                          color: isDark ? CoagTheme.textDarkSecondary : CoagTheme.textLightSecondary,
                        ),
                      ),
                    ],
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded),
                    onPressed: () => Navigator.of(context).pop(),
                  )
                ],
              ),
              const Divider(height: 30),

              // Measurement values card
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: isDark ? CoagTheme.surfaceDark : Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: CoagTheme.getCardShadow(isDark),
                  border: Border.all(
                    color: isDark ? Colors.white.withOpacity(0.08) : Colors.black.withOpacity(0.05),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildModalMetric("INR", result.inr.toStringAsFixed(2), statusColor),
                    Container(
                      width: 1,
                      height: 50,
                      color: isDark ? Colors.white.withOpacity(0.1) : Colors.black.withOpacity(0.1),
                    ),
                    _buildModalMetric("PT (Time)", "${result.pt.toStringAsFixed(1)}s", isDark ? CoagTheme.textDarkPrimary : CoagTheme.textLightPrimary),
                    Container(
                      width: 1,
                      height: 50,
                      color: isDark ? Colors.white.withOpacity(0.1) : Colors.black.withOpacity(0.1),
                    ),
                    _buildModalMetric("Temp", "${result.averageTemperature.toStringAsFixed(1)}°C", isDark ? CoagTheme.textDarkPrimary : CoagTheme.textLightPrimary),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Clinical Advice card
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(15),
                  border: Border.all(color: statusColor.withOpacity(0.2), width: 1),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.info_outline, color: statusColor, size: 18),
                        const SizedBox(width: 8),
                        Text(
                          "SAFETY STATUS: ${result.status.toUpperCase()}",
                          style: TextStyle(
                            color: statusColor,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      result.healthAdvice,
                      style: TextStyle(
                        fontSize: 14,
                        color: isDark ? CoagTheme.textDarkPrimary : CoagTheme.textLightPrimary,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 25),

              // Graph section
              Text(
                "Coagulation Optical Curve",
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: isDark ? CoagTheme.textDarkPrimary : CoagTheme.textLightPrimary,
                ),
              ),
              const SizedBox(height: 10),
              
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: isDark ? CoagTheme.surfaceDark : Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: isDark ? Colors.white.withOpacity(0.08) : Colors.black.withOpacity(0.05),
                    ),
                  ),
                  child: CoagChart(
                    curvePoints: result.curvePoints,
                    finalPT: result.pt,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildModalMetric(String label, String value, Color color) {
    return Column(
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            color: Colors.grey,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          value,
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }
}
