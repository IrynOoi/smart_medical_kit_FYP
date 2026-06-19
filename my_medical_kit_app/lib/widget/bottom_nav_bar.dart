// bottom_nav_bar.dart - A bottom navigation bar with a central floating action button.
// Dynamically switches pages based on user role (patient/caregiver) and includes
// a persistent bottom bar with home, AI, inventory (FAB), history, and profile tabs.

import 'package:flutter/material.dart';
import 'package:my_medical_kit_app/screens/patient/patient_dashboard_page.dart';
import 'package:my_medical_kit_app/screens/caregiver/caregiver_dashboard_page.dart';
import 'package:my_medical_kit_app/screens/patient/patient_history_page.dart';
import 'package:my_medical_kit_app/theme/colors.dart';
import 'package:my_medical_kit_app/screens/caregiver/caregiver_medication_history_page.dart';
import 'package:my_medical_kit_app/screens/profile_page.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:my_medical_kit_app/screens/caregiver/ai_analytics_page_caregiver.dart';
import 'package:my_medical_kit_app/screens/patient/ai_prediction_patient.dart';

// Import the two role‑specific inventory pages (separate screens for patient and caregiver)
import 'package:my_medical_kit_app/screens/patient/patient_inventory_page.dart';
import 'package:my_medical_kit_app/screens/caregiver/caregiver_inventory_page.dart';

// ----------------------------------------------------------------------
// ComingSoonPage – a placeholder screen for features not yet implemented.
// Used when a tab points to an unfinished feature.
// ----------------------------------------------------------------------
class ComingSoonPage extends StatelessWidget {
  final String title; // Title of the feature

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
            // Circular icon with hourglass
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.hourglass_empty_rounded,
                size: 80,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 24),
            // Feature title (e.g., "Smart Reminders")
            Text(
              title,
              style: const TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 8),
            // Subtitle
            Text(
              'Feature Coming Soon',
              style: TextStyle(
                fontSize: 16,
                color: Colors.white.withValues(alpha: 0.8),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ----------------------------------------------------------------------
// BottomNavBar – the main navigation widget for the app after login.
// It displays a bottom bar with 5 items (Home, AI, Inventory via FAB, History, Profile).
// The content changes depending on the user's role (patient or caregiver).
// ----------------------------------------------------------------------
class BottomNavBar extends StatefulWidget {
  const BottomNavBar({super.key});

  @override
  State<BottomNavBar> createState() => _BottomNavBarState();
}

class _BottomNavBarState extends State<BottomNavBar> {
  int selectedIndex =
      0; // Current selected tab index (0=Home, 1=AI, 2=Inventory (FAB), 3=History, 4=Profile)

  // Role and user ID loaded from SharedPreferences after login
  String _role = 'patient';
  int _userId = 0;
  bool _sessionLoaded = false; // Flag to avoid building before data is ready

  @override
  void initState() {
    super.initState();
    _loadRole(); // Load user session data
  }

  // ----------------------------------------------------------------------
  // Load the logged‑in user's role and ID from SharedPreferences.
  // Then update the state so the UI can reflect the correct role.
  // ----------------------------------------------------------------------
  Future<void> _loadRole() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _role = prefs.getString('role') ?? 'patient';

      // Retrieve the appropriate ID based on role
      if (_role == 'patient') {
        _userId = prefs.getInt('patient_id') ?? 1;
      } else {
        _userId = prefs.getInt('caregiver_id') ?? 1;
      }

      _sessionLoaded = true;
    });
  }

  // ----------------------------------------------------------------------
  // Build the list of pages based on the current role.
  // Each tab corresponds to a different widget.
  // ----------------------------------------------------------------------
  List<Widget> get _pages {
    // Home page: depends on role
    final homePage = _role == 'caregiver'
        ? const CaregiverDashboardPage()
        : const PatientDashboardPage();

    // History page: also role‑specific
    Widget historyPage;
    if (_role == 'patient') {
      historyPage = const PatientHistoryPage();
    } else {
      historyPage = const MedicationHistoryScreen();
    }

    // AI / Analytics page: role‑specific (patient sees prediction, caregiver sees analytics)
    Widget aiPage;
    if (_role == 'patient') {
      aiPage = const AIPredictionPatientPage();
    } else {
      aiPage = AiAnalyticsPage(caregiverId: _userId);
    }

    // Inventory page: dynamic based on role (patient vs caregiver)
    Widget inventoryPage;
    if (_role == 'patient') {
      inventoryPage = PatientInventoryPage(userId: _userId);
    } else {
      inventoryPage = CaregiverInventoryPage(userId: _userId);
    }

    // Return the list of pages in the order of the bottom bar indices
    return [
      homePage, // Index 0: Home
      aiPage, // Index 1: AI Predict
      inventoryPage, // 👉 Index 2: Inventory (accessed via FAB)
      historyPage, // Index 3: History
      const ProfilePage(), // Index 4: Profile
    ];
  }

  @override
  Widget build(BuildContext context) {
    // Show a loading indicator while session data is being loaded
    if (!_sessionLoaded) {
      return const Scaffold(
        backgroundColor: Color(0xFFF4F6FB),
        body: Center(child: CircularProgressIndicator()),
      );
    }

    // Wrap the scaffold with PopScope to handle Android back button behaviour.
    // If the user is on the home tab (index 0), allow back navigation (pop).
    // Otherwise, go back to the home tab.
    return PopScope(
      canPop: selectedIndex == 0,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) {
          setState(() => selectedIndex = 0);
        }
      },
      child: Scaffold(
        // Display the currently selected page
        body: _pages[selectedIndex],

        // ----------------------------------------------------------------------
        // Floating Action Button – centrally placed in the bottom bar.
        // Tapping it selects the Inventory tab (index 2).
        // ----------------------------------------------------------------------
        floatingActionButton: SizedBox(
          height: 62,
          width: 62,
          child: FloatingActionButton(
            backgroundColor: AppColors.primaryPurple,
            elevation: 4,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(22),
            ),
            onPressed: () {
              setState(() {
                selectedIndex = 2; // Switch to Inventory page
              });
            },
            child: const Icon(
              Icons.inventory_rounded,
              color: Colors.white,
              size: 36,
            ),
          ),
        ),
        // Position the FAB in the centre of the bottom app bar
        floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,

        // ----------------------------------------------------------------------
        // Bottom Navigation Bar with a notch for the FAB.
        // It displays four items: Home, AI Predict, History, Profile.
        // The Inventory button is the FAB itself.
        // ----------------------------------------------------------------------
        bottomNavigationBar: BottomAppBar(
          shape: const CircularNotchedRectangle(), // Notch for FAB
          notchMargin: 8,
          height: 60,
          padding: EdgeInsets.zero,
          color: Colors.white,
          elevation: 8,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              // Home tab
              _buildNavItem(Icons.home_outlined, 'Home', 0),
              // AI tab
              _buildNavItem(Icons.analytics_outlined, 'AI Predict', 1),
              // Spacer to align with the FAB notch
              const SizedBox(width: 48),
              // History tab
              _buildNavItem(Icons.history_outlined, 'History', 3),
              // Profile tab
              _buildNavItem(Icons.person_outline, 'Profile', 4),
            ],
          ),
        ),
      ),
    );
  }

  // ----------------------------------------------------------------------
  // Helper to build each navigation item (icon + label).
  // Highlights the item if it matches the selected index.
  // ----------------------------------------------------------------------
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
