//bottom_nav_bar.dart
import 'package:flutter/material.dart';
import 'package:my_medical_kit_app/screens/patient_dashboard_page.dart';
import 'package:my_medical_kit_app/screens/caregiver_dashboard_page.dart';
import 'package:my_medical_kit_app/theme/colors.dart';
import 'package:my_medical_kit_app/screens/caregiver_medication_history_page.dart';
import 'package:my_medical_kit_app/screens/profile_page.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:my_medical_kit_app/screens/ai_analytics_page.dart';
import 'package:my_medical_kit_app/services/api_service.dart';
import 'package:my_medical_kit_app/screens/inventory_management_page.dart'; // 🌟 Importing the newly created full page

class ComingSoonPage extends StatelessWidget {
  final String title;
  const ComingSoonPage({super.key, required this.title});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        decoration: const BoxDecoration(gradient: AppColors.mainGradient),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.hourglass_empty_rounded,
                size: 80,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              title,
              style: const TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Feature Coming Soon',
              style: TextStyle(
                fontSize: 16,
                color: Colors.white.withOpacity(0.8),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class BottomNavBar extends StatefulWidget {
  const BottomNavBar({super.key});

  @override
  State<BottomNavBar> createState() => _BottomNavBarState();
}

class _BottomNavBarState extends State<BottomNavBar> {
  int selectedIndex = 0;

  // Role and ID loaded from SharedPreferences (saved during login)
  String _role = 'patient';
  int _userId = 0; // 🌟 ADDED: Store the user's ID
  bool _sessionLoaded = false;

  @override
  void initState() {
    super.initState();
    _loadRole();
  }

  Future<void> _loadRole() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _role = prefs.getString('role') ?? 'patient';

      // 🌟 ADDED: Fetch the correct ID based on the user's role
      if (_role == 'patient') {
        _userId = prefs.getInt('patient_id') ?? 1;
      } else {
        _userId = prefs.getInt('caregiver_id') ?? 1;
      }

      _sessionLoaded = true;
    });
  }

  // Pages change based on role
  List<Widget> get _pages {
    final homePage = _role == 'caregiver'
        ? const CaregiverDashboardPage() // caregiver sees their own dashboard
        : const PatientDashboardPage(); // patient sees patient dashboard

    return [
      homePage, // 0: Home (Dashboard)
      AiAnalyticsPage(caregiverId: _userId), // 🌟 1: AI Predict (LINKED!)
      const ComingSoonPage(title: 'Medication Assistant'), // 2: FAB (Chat)
      const MedicationHistoryScreen(), // 3: History
      const ProfilePage(), // 4: Profile
    ];
  }

  @override
  Widget build(BuildContext context) {
    // Show loading while reading SharedPreferences
    if (!_sessionLoaded) {
      return const Scaffold(
        backgroundColor: Color(0xFFF4F6FB),
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return PopScope(
      canPop: selectedIndex == 0,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) {
          setState(() => selectedIndex = 0); // go Home tab
        }
      },
      child: Scaffold(
        body: _pages[selectedIndex],

        floatingActionButton: FloatingActionButton(
          backgroundColor: AppColors.primaryPurple,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          onPressed: () => _showDeviceInventoryBottomSheet(context),
          child: const Icon(
            Icons.phonelink_setup_rounded, // Better icon for Device Management
            color: Colors.white,
            size: 28,
          ),
        ),
        floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,

        bottomNavigationBar: BottomAppBar(
          shape: const CircularNotchedRectangle(),
          notchMargin: 8,
          height: 60,
          padding: EdgeInsets.zero,
          color: Colors.white,
          elevation: 8,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildNavItem(Icons.home_outlined, 'Home', 0),
              _buildNavItem(Icons.analytics_outlined, 'AI Predict', 1),
              const SizedBox(width: 48),
              _buildNavItem(Icons.history_outlined, 'History', 3),
              _buildNavItem(Icons.person_outline, 'Profile', 4),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem(IconData icon, String label, int index) {
    final bool isSelected = selectedIndex == index;
    return InkWell(
      onTap: () => setState(() => selectedIndex = index),
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              color: isSelected ? AppColors.primaryPurple : Colors.grey,
              size: 22,
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                color: isSelected ? AppColors.primaryPurple : Colors.grey,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ==========================================
  // DEVICE & INVENTORY BOTTOM SHEET
  // ==========================================
  void _showDeviceInventoryBottomSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(24),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 50,
                  height: 5,
                  margin: const EdgeInsets.only(bottom: 20),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
              if (_role == 'patient') _buildPatientDeviceSheet()
              else _buildCaregiverDeviceSheet(),
              const SizedBox(height: 20),
            ],
          ),
        );
      },
    );
  }

  // ───────────────────────────────────────────
  // PATIENT VIEW: "My IoT Kit"
  // ───────────────────────────────────────────
  Widget _buildPatientDeviceSheet() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'My IoT Kit (DISP-10001)',
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: AppColors.textDark,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Manage your smart kit and reminders.',
          style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
        ),
        const SizedBox(height: 24),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _buildDeviceStatCard(Icons.battery_4_bar_rounded, 'Battery', '85%', Colors.green),
            _buildDeviceStatCard(Icons.wifi_rounded, 'Network', 'Online', Colors.blue),
            _buildDeviceStatCard(Icons.sync_rounded, 'Last Sync', 'Just now', Colors.orange),
          ],
        ),
        const SizedBox(height: 24),
        ElevatedButton.icon(
          onPressed: () {
            Navigator.pop(context);
            _showMockSnackBar('Buzzer test activated on DISP-10001! 🔊');
          },
          icon: const Icon(Icons.notifications_active_rounded),
          label: const Text('Test Device Buzzer / LED'),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primaryPurple,
            foregroundColor: Colors.white,
            minimumSize: const Size(double.infinity, 50),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
          ),
        ),
        const SizedBox(height: 12),
        TextButton.icon(
          onPressed: () {
            Navigator.pop(context);
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => InventoryManagementPage(
                  role: _role,
                  userId: _userId,
                ),
              ),
            );
          },
          icon: const Icon(Icons.open_in_new_rounded, size: 18),
          label: const Text('Open Full Device Page'),
          style: TextButton.styleFrom(
            foregroundColor: AppColors.primaryPurple,
            minimumSize: const Size(double.infinity, 50),
          ),
        ),
      ],
    );
  }

  // ───────────────────────────────────────────
  // CAREGIVER VIEW: "Device & Inventory"
  // ───────────────────────────────────────────
  Widget _buildCaregiverDeviceSheet() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Device & Inventory',
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: AppColors.textDark,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Manage connected patient kits and restock medications.',
          style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
        ),
        const SizedBox(height: 24),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.orange.withOpacity(0.1),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.orange.withOpacity(0.5)),
          ),
          child: Row(
            children: [
              const Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 28),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Low Stock Alert (DISP-10001)',
                      style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.textDark),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'John Doe\'s Amlodipine is running out (2 left).',
                      style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        ElevatedButton.icon(
          onPressed: () {
            Navigator.pop(context);
            _showMockSnackBar('Quick Restock successful! SQL `add_inventory_refill` executed.');
          },
          icon: const Icon(Icons.medication_rounded),
          label: const Text('Quick Restock (快捷补药)'),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF4CAF82),
            foregroundColor: Colors.white,
            minimumSize: const Size(double.infinity, 50),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
          ),
        ),
        const SizedBox(height: 12),
        TextButton.icon(
          onPressed: () {
            Navigator.pop(context);
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => InventoryManagementPage(
                  role: _role,
                  userId: _userId,
                ),
              ),
            );
          },
          icon: const Icon(Icons.open_in_new_rounded, size: 18),
          label: const Text('Open Full Inventory Page'),
          style: TextButton.styleFrom(
            foregroundColor: AppColors.primaryPurple,
            minimumSize: const Size(double.infinity, 50),
          ),
        ),
      ],
    );
  }

  Widget _buildDeviceStatCard(IconData icon, String label, String value, Color color) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: color, size: 28),
        ),
        const SizedBox(height: 8),
        Text(
          value,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey.shade600,
          ),
        ),
      ],
    );
  }

  void _showMockSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppColors.textDark,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.only(bottom: 80, left: 16, right: 16),
      ),
    );
  }
}
