//bottom_nav_bar.dart

import 'package:flutter/material.dart';
import 'package:my_medical_kit_app/screens/patient_dashboard_page.dart';
import 'package:my_medical_kit_app/screens/caregiver_dashboard_page.dart';
import 'package:my_medical_kit_app/screens/patient_history_page.dart';
import 'package:my_medical_kit_app/theme/colors.dart';
import 'package:my_medical_kit_app/screens/caregiver_medication_history_page.dart';
import 'package:my_medical_kit_app/screens/profile_page.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:my_medical_kit_app/screens/ai_analytics_page.dart';
import 'package:my_medical_kit_app/screens/inventory_management_page.dart';

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
  int _userId = 0;
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
        ? const CaregiverDashboardPage()
        : const PatientDashboardPage();

    Widget historyPage;
    if (_role == 'patient') {
      historyPage = const PatientHistoryPage();
    } else {
      // 照顾者的历史页面，可以复用或单独写
      historyPage = const MedicationHistoryScreen(); // 或者你的照顾者历史页
    }

    return [
      homePage,
      AiAnalyticsPage(caregiverId: _userId),
      InventoryManagementPage(role: _role, userId: _userId),
      historyPage,
      const ProfilePage(),
    ];
  }

  @override
  Widget build(BuildContext context) {
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
          setState(() => selectedIndex = 0);
        }
      },
      child: Scaffold(
        body: _pages[selectedIndex],

        floatingActionButton: SizedBox(
          height: 62, // Enlarge height
          width: 62, // Enlarge width
          child: FloatingActionButton(
            backgroundColor: AppColors.primaryPurple,
            elevation: 4,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(
                22,
              ), // Make it slightly rounder to match the size
            ),
            onPressed: () {
              setState(() {
                selectedIndex = 2;
              });
            },
            child: const Icon(
              Icons.inventory_rounded,
              color: Colors.white,
              size: 36, // 👇 Enlarge the icon
            ),
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
}
