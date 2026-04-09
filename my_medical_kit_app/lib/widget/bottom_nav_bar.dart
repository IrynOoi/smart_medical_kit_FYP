//bottom_nav_bar.dart

import 'package:flutter/material.dart';
import 'package:my_medical_kit_app/theme/colors.dart';
import 'package:my_medical_kit_app/screens/medication_history_page.dart';

// Temporary placeholder page
class DummyPage extends StatelessWidget {
  final String title;
  const DummyPage({super.key, required this.title});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        decoration: const BoxDecoration(
          gradient: AppColors.mainGradient,
        ),
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

  // 🌟 Medical app pages
  final List<Widget> _pages = [
    const MedicationHistoryScreen(), // Page 0: Home (Medication History)
    const DummyPage(title: 'AI Analytics'), // Page 1: AI Analysis
    const DummyPage(title: 'Configuration'), // Page 2: Scheduling Settings
    const DummyPage(title: 'Patient Profile'), // Page 3: User Profile
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _pages[selectedIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: selectedIndex,
        type: BottomNavigationBarType.fixed,
        selectedItemColor: AppColors.primaryPurple,
        unselectedItemColor: Colors.grey,
        onTap: (index) => setState(() => selectedIndex = index),
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.medical_information),
            label: 'History',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.analytics),
            label: 'AI Predict',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.schedule),
            label: 'Schedule',
          ),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Profile'),
        ],
      ),
    );
  }
}
