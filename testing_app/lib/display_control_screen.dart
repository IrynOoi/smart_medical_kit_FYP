// lib/display_control_screen.dart
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

class DisplayControlScreen extends StatefulWidget {
  const DisplayControlScreen({super.key});

  @override
  State<DisplayControlScreen> createState() => _DisplayControlScreenState();
}

class _DisplayControlScreenState extends State<DisplayControlScreen> {
  // ⚠️ Ensure this IP matches your ESP32's current IP address!
  final String espIp = "http://172.20.10.2";

  Future<void> sendDisplayCommand(String endpoint, String feedback) async {
    try {
      final response = await http.get(Uri.parse('$espIp$endpoint'));
      if (response.statusCode == 200) {
        debugPrint(feedback);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(feedback), duration: const Duration(seconds: 1)),
          );
        }
      }
    } catch (e) {
      debugPrint("Network Error: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Network error. Is the ESP32 reachable?')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('OLED Screen Control'),
        backgroundColor: Colors.teal,
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.screenshot, size: 80, color: Colors.teal),
            const SizedBox(height: 20),
            const Text(
              "I2C Display Options",
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 30),

            // 1. Hello World Button
            ElevatedButton.icon(
              onPressed: () => sendDisplayCommand('/display/hello', 'Printed "Hello world" on OLED'),
              icon: const Icon(Icons.text_fields),
              label: const Text('Say Hello World'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
                minimumSize: const Size(250, 50),
              ),
            ),
            const SizedBox(height: 15),

            // 2. Clear Screen Button
            ElevatedButton.icon(
              onPressed: () => sendDisplayCommand('/display/clear', 'Cleared OLED display'),
              icon: const Icon(Icons.clear),
              label: const Text('Clear Screen'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
                minimumSize: const Size(250, 50),
              ),
            ),
            const SizedBox(height: 15),

            // 3. Supervisor Name Button (⚠️ NEW BUTTON ADDED HERE)
            ElevatedButton.icon(
              onPressed: () => sendDisplayCommand('/display/sv', 'Displayed Supervisor Name'),
              icon: const Icon(Icons.person),
              label: const Text('Show Supervisor Name'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
                minimumSize: const Size(250, 50),
              ),
            ),
          ],
        ),
      ),
    );
  }
}