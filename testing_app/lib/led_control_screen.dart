// lib/led_control_screen.dart
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

class LedControlScreen extends StatefulWidget {
  const LedControlScreen({super.key});

  @override
  State<LedControlScreen> createState() => _LedControlScreenState();
}

class _LedControlScreenState extends State<LedControlScreen> {
  final String espIp = "http://172.20.10.2";

  Future<void> turnOnLed() async {
    try {
      final response = await http.get(Uri.parse('$espIp/led/on'));
      if (response.statusCode == 200) debugPrint("LED turned ON");
    } catch (e) {
      debugPrint("Error: $e");
    }
  }

  Future<void> turnOffLed() async {
    try {
      final response = await http.get(Uri.parse('$espIp/led/off'));
      if (response.statusCode == 200) debugPrint("LED turned OFF");
    } catch (e) {
      debugPrint("Error: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Visual Indicator Control'),
        backgroundColor: Colors.blue,
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.lightbulb, size: 80, color: Colors.blueAccent),
            const SizedBox(height: 20),
            const Text("LED Settings", style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
            const SizedBox(height: 30),

            ElevatedButton(
              onPressed: turnOnLed,
              style: ElevatedButton.styleFrom(backgroundColor: Colors.green, minimumSize: const Size(200, 50)),
              child: const Text('Turn ON LED', style: TextStyle(color: Colors.white, fontSize: 16)),
            ),
            const SizedBox(height: 15),
            ElevatedButton(
              onPressed: turnOffLed,
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red, minimumSize: const Size(200, 50)),
              child: const Text('Turn OFF LED', style: TextStyle(color: Colors.white, fontSize: 16)),
            ),
          ],
        ),
      ),
    );
  }
}