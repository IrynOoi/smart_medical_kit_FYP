// lib/screens/patient_history_page.dart
// Displays the patient's medication adherence history: a list of logs (TAKEN/MISSED/PENDING)
// with details like scheduled time and dispensed time. A summary card shows the total number
// of doses taken. Data is fetched via PatientService and stored in a list of AdherenceLog objects.

import 'package:flutter/material.dart';
import 'package:my_medical_kit_app/theme/colors.dart';
import 'package:my_medical_kit_app/services/api/patient_service.dart';
import 'package:my_medical_kit_app/models/adherence_log.dart';
import 'package:shared_preferences/shared_preferences.dart';

class PatientHistoryPage extends StatefulWidget {
  const PatientHistoryPage({super.key});

  @override
  State<PatientHistoryPage> createState() => _PatientHistoryPageState();
}

class _PatientHistoryPageState extends State<PatientHistoryPage> {
  // State flags and data holders
  bool _isLoading = true;
  List<AdherenceLog> _logs = []; // List of logs fetched from the API
  int _patientId = 0; // Patient ID read from SharedPreferences

  // Computed property: number of logs with status TAKEN
  int get _takenCount => _logs.where((log) => log.isTaken).length;

  @override
  void initState() {
    super.initState();
    _loadPatientId(); // Start loading patient ID and logs
  }

  // ------------------------------------------------------------
  // DATA LOADING METHODS
  // ------------------------------------------------------------

  /// Reads patient_id from SharedPreferences and calls _loadLogs() if valid.
  Future<void> _loadPatientId() async {
    final prefs = await SharedPreferences.getInstance();
    final id = prefs.getInt('patient_id');
    if (id != null && id > 0) {
      _patientId = id;
      await _loadLogs();
    } else {
      setState(() => _isLoading = false); // No valid ID, stop loading state
    }
  }

  /// Fetches adherence logs from the API for the patient.
  /// Optional [showLoading] controls whether to show the loading spinner.
  Future<void> _loadLogs({bool showLoading = true}) async {
    if (showLoading) setState(() => _isLoading = true);
    try {
      final logs = await PatientService().getAdherenceLogs(
        _patientId,
        limit: 50,
      );
      setState(() {
        _logs = logs;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error loading history: $e')));
      }
    }
  }

  // ------------------------------------------------------------
  // HELPER FORMATTING METHODS
  // ------------------------------------------------------------

  /// Formats a DateTime to a human-readable string (DD/MM/YYYY HH:MM AM/PM).
  String _formatDateTime(DateTime dt) {
    final hours = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
    final amPm = dt.hour >= 12 ? 'PM' : 'AM';
    final minutes = dt.minute.toString().padLeft(2, '0');
    final day = dt.day.toString().padLeft(2, '0');
    final month = dt.month.toString().padLeft(2, '0');
    return '$day/$month/${dt.year} $hours:$minutes $amPm';
  }

  /// Returns the appropriate display time for a log entry.
  /// If the dose was taken and has a takenTime, show that; otherwise fallback to scheduledTime.
  String _formatDisplayTime(AdherenceLog log) {
    if (log.isTaken && log.takenTime != null) {
      return _formatDateTime(log.takenTime!);
    }
    if (log.scheduledTime != null) {
      return _formatDateTime(log.scheduledTime!);
    }
    return 'No timestamp';
  }

  // ------------------------------------------------------------
  // UI BUILDERS
  // ------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.primaryPurple.withValues(alpha: 0.05),
      appBar: AppBar(
        title: const Text(
          'Your Medication History',
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
          : _logs.isEmpty
          ? const Center(child: Text('No history available'))
          : Column(
              children: [
                // ─────────────────────────────────────────────────────
                // Total Doses Card (gradient, matches caregiver style)
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
                            '$_takenCount',
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
                    onRefresh: () => _loadLogs(showLoading: false),
                    color: AppColors.primaryPurple,
                    child: ListView.builder(
                      padding: const EdgeInsets.only(bottom: 24),
                      itemCount: _logs.length,
                      itemBuilder: (context, index) {
                        final log = _logs[index];
                        final isTaken = log.isTaken;
                        final isMissed = log.isMissed;

                        Color statusColor = Colors.orange; // default PENDING
                        Color bgColor = Colors.orange.shade50;

                        if (isTaken) {
                          statusColor = Colors.teal;
                          bgColor = Colors.teal.shade50;
                        } else if (isMissed) {
                          statusColor = Colors.redAccent;
                          bgColor = Colors.red.shade50;
                        }

                        final statusText = isTaken
                            ? 'Taken'
                            : isMissed
                            ? 'Missed'
                            : 'Pending';

                        // Format times
                        String scheduledStr = log.scheduledTime != null
                            ? _formatDateTime(log.scheduledTime!)
                            : 'No schedule';
                        String dispensedStr = (isTaken && log.takenTime != null)
                            ? _formatDateTime(log.takenTime!)
                            : (isTaken ? 'No dispense time' : 'Not taken');
                        String recordedStr = log.recordedAt != null
                            ? _formatDateTime(log.recordedAt!)
                            : 'Not recorded';

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
                            border: Border.all(color: Colors.grey.shade100),
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
                                                MainAxisAlignment.spaceBetween,
                                            children: [
                                              // Medication name
                                              Expanded(
                                                child: Text(
                                                  log.medicationName ??
                                                      'Unknown Medication',
                                                  style: const TextStyle(
                                                    fontSize: 16,
                                                    fontWeight: FontWeight.bold,
                                                    color: AppColors.textDark,
                                                  ),
                                                  maxLines: 1,
                                                  overflow:
                                                      TextOverflow.ellipsis,
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
                                                      BorderRadius.circular(8),
                                                ),
                                                child: Text(
                                                  statusText.toUpperCase(),
                                                  style: TextStyle(
                                                    fontSize: 12,
                                                    fontWeight: FontWeight.bold,
                                                    color: statusColor,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 12),
                                          // Scheduled time row
                                          Row(
                                            children: [
                                              Icon(
                                                Icons.schedule,
                                                size: 14,
                                                color: Colors.grey.shade600,
                                              ),
                                              const SizedBox(width: 4),
                                              Text(
                                                scheduledStr,
                                                style: TextStyle(
                                                  fontSize: 13,
                                                  color: Colors.grey.shade600,
                                                ),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 4),
                                          // Dispensed time row
                                          Row(
                                            children: [
                                              Icon(
                                                Icons.done_all,
                                                size: 14,
                                                color: isTaken
                                                    ? Colors.green
                                                    : Colors.grey.shade600,
                                              ),
                                              const SizedBox(width: 4),
                                              Text(
                                                dispensedStr,
                                                style: TextStyle(
                                                  fontSize: 13,
                                                  color: isTaken
                                                      ? Colors.green
                                                      : Colors.grey.shade600,
                                                ),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 4),
                                          // Recorded time row
                                          Row(
                                            children: [
                                              Icon(
                                                Icons.history,
                                                size: 14,
                                                color: Colors.grey.shade600,
                                              ),
                                              const SizedBox(width: 4),
                                              Text(
                                                recordedStr,
                                                style: TextStyle(
                                                  fontSize: 13,
                                                  color: Colors.grey.shade600,
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
