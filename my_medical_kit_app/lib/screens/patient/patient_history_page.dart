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

  /// Formats a DateTime to a human-readable string (Today/Yesterday or DD/MM/YYYY HH:MM).
  String _formatDateTime(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inDays == 0) {
      return 'Today ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    } else if (diff.inDays == 1) {
      return 'Yesterday ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    } else {
      return '${dt.day}/${dt.month}/${dt.year} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    }
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

  /// Builds the header with a gradient background, title, and subtitle.
  Widget _buildHeader() {
    final topPadding = MediaQuery.of(context).padding.top;
    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(24, topPadding + 16, 24, 32),
      decoration: const BoxDecoration(
        gradient: AppColors.mainGradient,
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(32),
          bottomRight: Radius.circular(32),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // (Commented out a custom back button; the AppBar is not used)
          // Row(
          //   mainAxisAlignment: MainAxisAlignment.spaceBetween,
          //   children: [
          //     const SizedBox(width: 38),
          //     const Text(
          //       'Medication History',
          //       style: TextStyle(
          //         color: Colors.white,
          //         fontSize: 18,
          //         fontWeight: FontWeight.bold,
          //       ),
          //     ),
          //     const SizedBox(width: 38),
          //   ],
          // ),
          const SizedBox(height: 24),
          const Text(
            'LOGS & RECORDS',
            style: TextStyle(
              fontSize: 14,
              letterSpacing: 1.5,
              color: Colors.white70,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Your History',
            style: TextStyle(
              fontSize: 34,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.premiumLight.withValues(alpha: 0.1),
      body: Column(
        children: [
          _buildHeader(),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _logs.isEmpty
                ? const Center(child: Text('No history available'))
                : RefreshIndicator(
                    onRefresh: () => _loadLogs(showLoading: false),
                    child: ListView.builder(
                      padding: const EdgeInsets.only(top: 8, bottom: 24),
                      itemCount: _logs.length + 1, // +1 for the summary card
                      itemBuilder: (context, index) {
                        // If index == 0, build the summary card (total doses taken).
                        if (index == 0) {
                          return Container(
                            margin: const EdgeInsets.fromLTRB(20, 16, 20, 16),
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(20),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.05),
                                  blurRadius: 10,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: AppColors.primaryPurple.withOpacity(
                                      0.1,
                                    ),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.checklist_rounded,
                                    color: AppColors.primaryPurple,
                                    size: 28,
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      const Text(
                                        'Total Doses Taken',
                                        style: TextStyle(
                                          color: Colors.grey,
                                          fontSize: 14,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        '$_takenCount',
                                        style: const TextStyle(
                                          color: AppColors.premiumDark,
                                          fontSize: 32,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 14,
                                    vertical: 8,
                                  ),
                                  decoration: BoxDecoration(
                                    color: AppColors.premiumLight.withOpacity(
                                      0.2,
                                    ),
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Text(
                                    '${_logs.length} total logs',
                                    style: const TextStyle(
                                      color: AppColors.premiumDark,
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          );
                        }

                        // Otherwise, display a single log entry.
                        final log = _logs[index - 1];
                        final isTaken = log.isTaken;
                        final isMissed = log.isMissed;
                        // Determine the status colour and text label
                        final statusColor = isTaken
                            ? Colors.green
                            : isMissed
                            ? Colors.redAccent
                            : Colors.orange;
                        final statusText = isTaken
                            ? 'Taken'
                            : isMissed
                            ? 'Missed'
                            : 'Pending';

                        // Format scheduled and dispensed times for display
                        String scheduledStr = log.scheduledTime != null
                            ? _formatDateTime(log.scheduledTime!)
                            : 'No schedule';
                        String dispensedStr = (isTaken && log.takenTime != null)
                            ? _formatDateTime(log.takenTime!)
                            : (isTaken ? 'No dispense time' : 'Not taken');

                        return Container(
                          margin: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.03),
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              ListTile(
                                contentPadding: const EdgeInsets.only(
                                  left: 16,
                                  right: 16,
                                  top: 8,
                                ),
                                leading: CircleAvatar(
                                  backgroundColor: statusColor.withValues(
                                    alpha: 0.1,
                                  ),
                                  child: Icon(
                                    isTaken
                                        ? Icons.check_circle
                                        : isMissed
                                        ? Icons.cancel
                                        : Icons.schedule,
                                    color: statusColor,
                                  ),
                                ),
                                title: Text(
                                  log.medicationName ?? 'Unknown Medication',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                    color: AppColors.premiumDark,
                                  ),
                                ),
                                trailing: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 6,
                                  ),
                                  decoration: BoxDecoration(
                                    color: statusColor.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Text(
                                    statusText,
                                    style: TextStyle(
                                      color: statusColor,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                              ),
                              Padding(
                                padding: const EdgeInsets.fromLTRB(
                                  20,
                                  0,
                                  20,
                                  16,
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    _buildDetailRow(
                                      Icons.schedule,
                                      'Scheduled',
                                      scheduledStr,
                                    ),
                                    const SizedBox(height: 8),
                                    _buildDetailRow(
                                      Icons.done_all,
                                      'Dispensed',
                                      dispensedStr,
                                      color: isTaken
                                          ? Colors.green
                                          : Colors.grey,
                                    ),
                                  ],
                                ),
                              ),
                            ],
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

  /// Helper widget to display a single detail row (icon + label + value).
  Widget _buildDetailRow(
    IconData icon,
    String label,
    String value, {
    Color? color, // Optional colour for the value text
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: color ?? Colors.grey.shade500),
        const SizedBox(width: 8),
        SizedBox(
          width: 80,
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13,
              color: Colors.grey.shade500,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: TextStyle(
              fontSize: 13,
              color: color ?? Colors.black87,
              fontWeight: color != null ? FontWeight.w600 : FontWeight.normal,
            ),
          ),
        ),
      ],
    );
  }
}
