// caregiver_medication_history_page.dart
// Caregiver view of medication adherence history. Shows a summary card with total doses taken
// across all patients, and a list of recent dose records (TAKEN, MISSED, PENDING) with patient names,
// medication names, status badges, and scheduled times. Data is fetched from the API using CaregiverService.
// (The AI Doctor feature is commented out – it was a patient‑specific feature.)

import 'package:flutter/material.dart';
import 'package:my_medical_kit_app/theme/colors.dart';
import 'package:my_medical_kit_app/services/api/caregiver_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class MedicationHistoryScreen extends StatefulWidget {
  const MedicationHistoryScreen({super.key});

  @override
  State<MedicationHistoryScreen> createState() =>
      _MedicationHistoryScreenState();
}

class _MedicationHistoryScreenState extends State<MedicationHistoryScreen> {
  // ⚠️ Hardcoded server IP – used for the AI feature (commented out), not currently in use.
  final String serverIp = "172.20.10.9";

  // Data holders
  List<Map<String, dynamic>> _alerts = []; // List of dose records (log entries)
  int _totalDoses = 0; // Total doses taken across all patients
  bool _isLoading = true;
  String _error = '';
  int _caregiverId = 0; // Caregiver ID fetched from SharedPreferences

  @override
  void initState() {
    super.initState();
    _initializeData(); // Start loading data when screen is created
  }

  // Fetches caregiver data from the API.
  // If [showLoading] is true (default), shows the loading spinner; otherwise updates silently.
  Future<void> _initializeData({bool showLoading = true}) async {
    setState(() {
      if (showLoading) _isLoading = true;
      _error = '';
    });

    try {
      // Get the caregiver ID from SharedPreferences (set during login)
      final prefs = await SharedPreferences.getInstance();
      _caregiverId = prefs.getInt('caregiver_id') ?? 0;

      // If no caregiver ID is found, show an error.
      if (_caregiverId == 0) {
        setState(() {
          _error = 'Session expired. Please login again.';
          _isLoading = false;
        });
        return;
      }

      // Fetch overview stats (including total taken count) and recent logs.
      final overview = await CaregiverService().getCaregiverOverview(
        _caregiverId,
      );
      final allLogs = await CaregiverService().getAllRecentLogs(_caregiverId);

      // Debug prints to verify data (kept as per original).
      print("✅ Overview: $overview");
      print("✅ Logs count: ${allLogs.length}");

      setState(() {
        // overview IS already the data map – access keys directly.
        final rawCount = overview['taken_count'];
        _totalDoses = rawCount is int
            ? rawCount
            : int.tryParse(rawCount?.toString() ?? '0') ?? 0;

        // allLogs IS already List<Map<String,dynamic>>
        _alerts = allLogs;
        _isLoading = false;
      });
    } catch (e) {
      print("❌ Error: $e");
      setState(() {
        _error = 'Failed to load data: $e';
        _isLoading = false;
      });
    }
  }

  /*
  // ------------------------------------------------------------------
  // (Commented out) AI Doctor feature – used a hardcoded patient and
  // a local prediction endpoint. This was probably moved to a separate
  // screen or is no longer used in the caregiver flow.
  // ------------------------------------------------------------------
  Future<void> _askAIDoctor() async {
    final String apiUrl = "http://$serverIp:5000/predict";
    final Map<String, dynamic> patientData = {
      "age": 78,
      "day_of_week": "Friday",
      "time_of_day": "Evening",
      "history": [1, 0, 1],
    };

    try {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(child: CircularProgressIndicator()),
      );

      final response = await http.post(
        Uri.parse(apiUrl),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode(patientData),
      );

      if (!context.mounted) return;
      Navigator.pop(context);
      if (!context.mounted) return;

      if (response.statusCode == 200) {
        final result = jsonDecode(response.body);
        _showResultDialog(
          probability: result['forget_probability'],
          level: result['warning_level'],
          message: result['message'],
        );
      } else {
        throw Exception("Server error code: ${response.statusCode}");
      }
    } catch (e) {
      if (mounted) {
        if (Navigator.canPop(context)) Navigator.pop(context);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Unable to connect to AI: $e')));
      }
    }
  }

  void _showResultDialog({
    required double probability,
    required String level,
    required String message,
  }) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('🧠 AI Prediction Result'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Probability of forgetting medication: ${(probability * 100).toStringAsFixed(0)}%',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            Text(
              'Warning Level: $level',
              style: TextStyle(
                color: level == 'High' ? Colors.red : Colors.green,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 10),
            Text('System Recommendation: $message'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }
  */

  // Helper to format a DateTime string to a human-readable format (DD/MM/YYYY HH:MM AM/PM).
  String _formatDateTime(String? dateTimeStr) {
    if (dateTimeStr == null) return '';
    try {
      final dt = DateTime.parse(dateTimeStr).toLocal();
      final hours = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
      final amPm = dt.hour >= 12 ? 'PM' : 'AM';
      final minutes = dt.minute.toString().padLeft(2, '0');
      final day = dt.day.toString().padLeft(2, '0');
      final month = dt.month.toString().padLeft(2, '0');
      return '$day/$month/${dt.year} $hours:$minutes $amPm';
    } catch (e) {
      return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.primaryPurple.withValues(alpha: 0.05),
      appBar: AppBar(
        title: const Text(
          'Doses Taken & History',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        backgroundColor: AppColors.primaryPurple,
        iconTheme: const IconThemeData(color: Colors.white),
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.primaryPurple),
            )
          : _error.isNotEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, color: Colors.red, size: 48),
                  const SizedBox(height: 16),
                  Text(
                    'Error: $_error',
                    style: const TextStyle(color: Colors.red),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: _initializeData,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primaryPurple,
                      foregroundColor: Colors.white,
                    ),
                    child: const Text('Retry'),
                  ),
                ],
              ),
            )
          : Column(
              children: [
                // ─────────────────────────────────────────────────────
                // Total Doses Card (fixed header with gradient)
                // ─────────────────────────────────────────────────────
                Container(
                  margin: const EdgeInsets.all(16),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 28,
                  ),
                  decoration: BoxDecoration(
                    gradient: AppColors.mainGradient,
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.premiumDark.withValues(alpha: 0.3),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Total Doses Taken',
                            style: TextStyle(
                              fontSize: 16,
                              color: Colors.white70,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            '$_totalDoses',
                            style: const TextStyle(
                              fontSize: 40,
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.2),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.medication,
                          color: Colors.white,
                          size: 40,
                        ),
                      ),
                    ],
                  ),
                ),

                // ─────────────────────────────────────────────────────
                // Recent Activity Title
                // ─────────────────────────────────────────────────────
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                  child: Row(
                    children: [
                      Icon(
                        Icons.history_rounded,
                        color: AppColors.primaryPurple,
                        size: 24,
                      ),
                      SizedBox(width: 8),
                      Text(
                        'Recent Activity',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textDark,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),

                // ─────────────────────────────────────────────────────
                // Scrollable list with RefreshIndicator
                // ─────────────────────────────────────────────────────
                Expanded(
                  child: RefreshIndicator(
                    onRefresh: () => _initializeData(showLoading: false),
                    color: AppColors.primaryPurple,
                    child: _alerts.isEmpty
                        ? const Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.history_toggle_off,
                                  size: 64,
                                  color: Colors.grey,
                                ),
                                SizedBox(height: 16),
                                Text(
                                  'No recent dose records',
                                  style: TextStyle(
                                    fontSize: 16,
                                    color: Colors.grey,
                                  ),
                                ),
                              ],
                            ),
                          )
                        : ListView.builder(
                            padding: const EdgeInsets.only(bottom: 24),
                            itemCount: _alerts.length,
                            itemBuilder: (context, index) {
                              final act = _alerts[index];
                              final status =
                                  act['status']?.toString().toUpperCase() ??
                                  'UNKNOWN';
                              final isTaken = status == 'TAKEN';
                              final isMissed = status == 'MISSED';

                              // Determine status colour and background based on status.
                              Color statusColor =
                                  Colors.orange; // default PENDING
                              Color bgColor = Colors.orange.shade50;

                              if (isTaken) {
                                statusColor = Colors.teal;
                                bgColor = Colors.teal.shade50;
                              } else if (isMissed) {
                                statusColor = Colors.redAccent;
                                bgColor = Colors.red.shade50;
                              }

                              // Each log entry is displayed as a card with a left colour bar.
                              return Container(
                                margin: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 8,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(16),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.grey.withValues(alpha: 0.1),
                                      blurRadius: 8,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                  border: Border.all(
                                    color: Colors.grey.shade100,
                                  ),
                                ),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(16),
                                  child: IntrinsicHeight(
                                    child: Row(
                                      children: [
                                        // Colored indicator bar on the left.
                                        Container(width: 6, color: statusColor),
                                        Expanded(
                                          child: Padding(
                                            padding: const EdgeInsets.all(16),
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Row(
                                                  mainAxisAlignment:
                                                      MainAxisAlignment
                                                          .spaceBetween,
                                                  children: [
                                                    // Patient name
                                                    Expanded(
                                                      child: Text(
                                                        act['patient_name'] ??
                                                            'Patient',
                                                        style: const TextStyle(
                                                          fontSize: 16,
                                                          fontWeight:
                                                              FontWeight.bold,
                                                          color: AppColors
                                                              .textDark,
                                                        ),
                                                        maxLines: 1,
                                                        overflow: TextOverflow
                                                            .ellipsis,
                                                      ),
                                                    ),
                                                    // Status badge
                                                    Container(
                                                      padding:
                                                          const EdgeInsets.symmetric(
                                                            horizontal: 8,
                                                            vertical: 4,
                                                          ),
                                                      decoration: BoxDecoration(
                                                        color: bgColor,
                                                        borderRadius:
                                                            BorderRadius.circular(
                                                              8,
                                                            ),
                                                      ),
                                                      child: Text(
                                                        status,
                                                        style: TextStyle(
                                                          fontSize: 12,
                                                          fontWeight:
                                                              FontWeight.bold,
                                                          color: statusColor,
                                                        ),
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                                const SizedBox(height: 8),
                                                // Medication name
                                                Text(
                                                  '${act['medication_name'] ?? 'Medication'}',
                                                  style: const TextStyle(
                                                    fontSize: 14,
                                                    color: Colors.black87,
                                                  ),
                                                ),
                                                const SizedBox(height: 8),
                                                // Scheduled time
                                                Row(
                                                  children: [
                                                    Icon(
                                                      Icons.schedule,
                                                      size: 14,
                                                      color:
                                                          Colors.grey.shade600,
                                                    ),
                                                    const SizedBox(width: 4),
                                                    Text(
                                                      _formatDateTime(
                                                        act['scheduled_time'],
                                                      ),
                                                      style: TextStyle(
                                                        fontSize: 13,
                                                        color: Colors
                                                            .grey
                                                            .shade600,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                  ),
                ),
              ],
            ),
    );
  }
}
