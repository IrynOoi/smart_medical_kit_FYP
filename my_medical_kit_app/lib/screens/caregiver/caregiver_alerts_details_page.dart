// //caregiver_alerts_details_page.dart
// import 'package:flutter/material.dart';
// import 'package:my_medical_kit_app/theme/colors.dart';
// import 'package:my_medical_kit_app/services/api/caregiver_service.dart';

// import 'caregiver_dashboard_page.dart';

// class CaregiverAlertsDetailsPage extends StatefulWidget {
//   final int caregiverId;
//   const CaregiverAlertsDetailsPage({super.key, required this.caregiverId});

//   @override
//   State<CaregiverAlertsDetailsPage> createState() =>
//       CaregiverAlertsDetailsPageState();
// }

// class CaregiverAlertsDetailsPageState
//     extends State<CaregiverAlertsDetailsPage> {

//   List<Map<String, dynamic>> _alerts = [];
//   bool _isLoading = true;
//   String _error = '';

//   @override
//   void initState() {
//     super.initState();
//     _fetchAlerts();
//   }

//   Future<void> _fetchAlerts() async {
//     setState(() {
//       _isLoading = true;
//       _error = '';
//     });
//     try {
//       // 這裡的 API 現在會支援回傳更多警告（透過後端設定 limit=50）
//       final data = await CaregiverService().getCaregiverAlerts(widget.caregiverId);
//       setState(() {
//         _alerts = data;
//         _isLoading = false;
//       });
//     } catch (e) {
//       setState(() {
//         _error = e.toString();
//         _isLoading = false;
//       });
//     }
//   }

//   String _formatDateTime(String? dtString) {
//     if (dtString == null) return '';
//     try {
//       final dt = DateTime.parse(dtString).toLocal();
//       return '${dt.day}/${dt.month}/${dt.year} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
//     } catch (_) {
//       return dtString.length > 16 ? dtString.substring(0, 16) : dtString;
//     }
//   }

//   String _formatSchedule(String cron) {
//     final parts = cron.split(' ');
//     if (parts.length < 5) return cron;
//     final minute = parts[0];
//     final hourPart = parts[1];
//     final dayOfMonth = parts[2];
//     final month = parts[3];
//     final dayOfWeek = parts[4];
//     String timeStr = '';
//     if (hourPart.contains(',')) {
//       final hours = hourPart
//           .split(',')
//           .map((h) => '${h.padLeft(2, '0')}:${minute.padLeft(2, '0')}')
//           .join(', ');
//       timeStr = hours;
//     } else {
//       timeStr = '${hourPart.padLeft(2, '0')}:${minute.padLeft(2, '0')}';
//     }
//     if (dayOfMonth == '*' && month == '*' && dayOfWeek == '*') {
//       return 'Daily at $timeStr';
//     } else if (dayOfMonth == '*' && month == '*' && dayOfWeek != '*') {
//       final days = dayOfWeek.split(',');
//       final dayNames = {
//         '0': 'Sun',
//         '1': 'Mon',
//         '2': 'Tue',
//         '3': 'Wed',
//         '4': 'Thu',
//         '5': 'Fri',
//         '6': 'Sat',
//         '7': 'Sun',
//       };
//       final readableDays = days.map((d) => dayNames[d] ?? d).join(', ');
//       return '$readableDays at $timeStr';
//     }
//     return cron;
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(
//         title: const Text(
//           'Recent Alerts',
//           style: TextStyle(fontWeight: FontWeight.bold),
//         ),
//         backgroundColor: AppColors.primaryPurple,
//         foregroundColor: Colors.white,
//         elevation: 0,
//       ),
//       backgroundColor: AppColors.primaryPurple.withValues(alpha: 0.05),
//       body: RefreshIndicator(
//         onRefresh: _fetchAlerts,
//         color: AppColors.primaryPurple,
//         child: _isLoading
//             ? const Center(child: CircularProgressIndicator())
//             : _error.isNotEmpty
//             ? Center(
//                 child: Column(
//                   mainAxisAlignment: MainAxisAlignment.center,
//                   children: [
//                     Text(
//                       'Error: $_error',
//                       style: const TextStyle(color: Colors.red),
//                     ),
//                     const SizedBox(height: 16),
//                     ElevatedButton(
//                       onPressed: _fetchAlerts,
//                       child: const Text('Retry'),
//                     ),
//                   ],
//                 ),
//               )
//             : _alerts.isEmpty
//             ? const Center(
//                 child: Text(
//                   'All Good! No recent alerts 🎉',
//                   style: TextStyle(fontSize: 16, color: Colors.grey),
//                 ),
//               )
//             : ListView.builder(
//                 padding: const EdgeInsets.all(16),
//                 itemCount: _alerts.length,
//                 itemBuilder: (_, i) {
//                   final act = _alerts[i];
//                   final isMissed = act['status'] == 'MISSED';
//                   final iconColor = isMissed ? Colors.redAccent : Colors.orange;

//                   return Card(
//                     elevation: 2,
//                     margin: const EdgeInsets.only(bottom: 12),
//                     shape: RoundedRectangleBorder(
//                       borderRadius: BorderRadius.circular(16),
//                     ),
//                     child: ListTile(
//                       contentPadding: const EdgeInsets.symmetric(
//                         horizontal: 16,
//                         vertical: 8,
//                       ),
//                       leading: Container(
//                         padding: const EdgeInsets.all(10),
//                         decoration: BoxDecoration(
//                           color: iconColor.withValues(alpha: 0.1),
//                           borderRadius: BorderRadius.circular(12),
//                         ),
//                         child: Icon(
//                           isMissed
//                               ? Icons.cancel_rounded
//                               : Icons.access_time_rounded,
//                           color: iconColor,
//                         ),
//                       ),
//                       title: Text(
//                         act['patient_name'] ?? 'Unknown Patient',
//                         style: const TextStyle(
//                           fontWeight: FontWeight.bold,
//                           fontSize: 15,
//                         ),
//                       ),
//                       subtitle: Padding(
//                         padding: const EdgeInsets.only(top: 6.0),
//                         child: Column(
//                           crossAxisAlignment: CrossAxisAlignment.start,
//                           children: [
//                             Text(
//                               'Dosage: ${formatDosage((act['dosage_tablet'] as num?)?.toDouble() ?? 0.0)}',
//                             ),
//                             Text(
//                               'Schedule: ${_formatSchedule(act['dispense_schedule'] ?? '')}',
//                             ),
//                             Text(
//                               'Inventory: ${act['current_inventory'] ?? 0} left',
//                             ),
//                           ],
//                         ),
//                       ),
//                       trailing: Text(
//                         _formatDateTime(act['scheduled_time']),
//                         style: TextStyle(
//                           color: Colors.grey.shade500,
//                           fontSize: 11,
//                         ),
//                         textAlign: TextAlign.right,
//                       ),
//                     ),
//                   );
//                 },
//               ),
//       ),
//     );
//   }
// }
