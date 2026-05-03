//main.dart
import 'package:flutter/material.dart';
import 'led_control_screen.dart';
import 'buzzer_control_screen.dart';
import 'stepper_control_screen.dart';
import 'display_control_screen.dart'; // ⚠️ Added import

void main() => runApp(const MyApp());

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Smart Medical Kit Dashboard',
      theme: ThemeData(primarySwatch: Colors.blue),
      home: const MainMenu(),
    );
  }
}

class MainMenu extends StatelessWidget {
  const MainMenu({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Smart Kit Dashboard')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              'Hardware Control Panel',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 40),

            // Button to go to LED Screen
            ElevatedButton.icon(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const LedControlScreen()),
                );
              },
              icon: const Icon(Icons.lightbulb),
              label: const Text('Open LED Controls'),
              style: ElevatedButton.styleFrom(minimumSize: const Size(250, 50)),
            ),
            const SizedBox(height: 20),

            // Button to go to Buzzer Screen
            ElevatedButton.icon(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const BuzzerControlScreen()),
                );
              },
              icon: const Icon(Icons.volume_up),
              label: const Text('Open Alarm Controls'),
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(250, 50),
                backgroundColor: Colors.deepPurple,
                foregroundColor: Colors.white,
              ),
            ),
            const SizedBox(height: 20),

            // Button to go to Motor Screen
            ElevatedButton.icon(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const StepperControlScreen()),
                );
              },
              icon: const Icon(Icons.settings),
              label: const Text('Open Motor Controls'),
              style: ElevatedButton.styleFrom(minimumSize: const Size(250, 50)),
            ),
            const SizedBox(height: 20),

            // Button to go to OLED Screen (NEW)
            ElevatedButton.icon(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const DisplayControlScreen()),
                );
              },
              icon: const Icon(Icons.screenshot),
              label: const Text('Open Display Controls'),
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(250, 50),
                backgroundColor: Colors.teal,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }
}