// lib/stepper_control_screen.dart
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

class StepperControlScreen extends StatefulWidget {
  const StepperControlScreen({super.key});

  @override
  State<StepperControlScreen> createState() => _StepperControlScreenState();
}

class _StepperControlScreenState extends State<StepperControlScreen> {
  // ⚠️ Update this to your current ESP32 IP
  final String espIp = "http://172.20.10.2";

  Future<void> sendMotorCommand(String endpoint, String successMessage) async {
    try {
      final response = await http.get(Uri.parse('$espIp$endpoint'));
      if (response.statusCode == 200) {
        debugPrint(successMessage);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(successMessage),
              duration: const Duration(seconds: 1),
            ),
          );
        }
      } else {
        debugPrint("Failed with status: ${response.statusCode}");
      }
    } catch (e) {
      debugPrint("Network Error: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Network error. Is the ESP32 on?')),
        );
      }
    }
  }

  // A helper widget to create standard buttons quickly
  Widget buildMotorButton(
      String endpoint,
      String label,
      IconData icon,
      Color color,
      ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: ElevatedButton.icon(
        onPressed: () => sendMotorCommand(endpoint, label),
        icon: Icon(icon),
        label: Text(label),
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: Colors.white,
          minimumSize: const Size(250, 45),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Triple Motor Control'),
        backgroundColor: Colors.orange,
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(vertical: 20),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // ==============================
              // MOTOR 1 SECTION
              // ==============================
              const Text(
                "Medication 1 (Motor 1)",
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Colors.blue,
                ),
              ),
              const SizedBox(height: 15),
              buildMotorButton(
                '/stepper/forward',
                'M1: 360° Forward',
                Icons.rotate_right,
                Colors.blue,
              ),
              buildMotorButton(
                '/stepper/backward',
                'M1: 360° Backward',
                Icons.rotate_left,
                Colors.blue[800]!,
              ),
              buildMotorButton(
                '/stepper/180',
                'M1: 180° (Half Turn)',
                Icons.pie_chart_outline,
                Colors.lightBlue,
              ),
              buildMotorButton(
                '/stepper/90',
                'M1: 90° (Quarter Turn)',
                Icons.pie_chart,
                Colors.lightBlue[800]!,
              ),

              const Padding(
                padding: EdgeInsets.symmetric(vertical: 20, horizontal: 40),
                child: Divider(thickness: 3),
              ),

              // ==============================
              // MOTOR 2 SECTION
              // ==============================
              const Text(
                "Medication 2 (Motor 2)",
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Colors.green,
                ),
              ),
              const SizedBox(height: 15),
              buildMotorButton(
                '/stepper2/forward',
                'M2: 360° Forward',
                Icons.rotate_right,
                Colors.green,
              ),
              buildMotorButton(
                '/stepper2/backward',
                'M2: 360° Backward',
                Icons.rotate_left,
                Colors.green[800]!,
              ),
              buildMotorButton(
                '/stepper2/180',
                'M2: 180° (Half Turn)',
                Icons.pie_chart_outline,
                Colors.lightGreen,
              ),
              buildMotorButton(
                '/stepper2/90',
                'M2: 90° (Quarter Turn)',
                Icons.pie_chart,
                Colors.lightGreen[800]!,
              ),

              const Padding(
                padding: EdgeInsets.symmetric(vertical: 20, horizontal: 40),
                child: Divider(thickness: 3),
              ),

              // ==============================
              // MOTOR 3 SECTION (NEW)
              // ==============================
              const Text(
                "Medication 3 (Motor 3)",
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Colors.purple,
                ),
              ),
              const SizedBox(height: 15),
              buildMotorButton(
                '/stepper3/forward',
                'M3: 360° Forward',
                Icons.rotate_right,
                Colors.purple,
              ),
              buildMotorButton(
                '/stepper3/backward',
                'M3: 360° Backward',
                Icons.rotate_left,
                Colors.purple[800]!,
              ),
              buildMotorButton(
                '/stepper3/180',
                'M3: 180° (Half Turn)',
                Icons.pie_chart_outline,
                Colors.deepPurpleAccent,
              ),
              buildMotorButton(
                '/stepper3/90',
                'M3: 90° (Quarter Turn)',
                Icons.pie_chart,
                Colors.deepPurple,
              ),
            ],
          ),
        ),
      ),
    );
  }
}