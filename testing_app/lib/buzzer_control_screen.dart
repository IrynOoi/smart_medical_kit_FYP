//buzzer_control_screen.dart
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

class BuzzerControlScreen extends StatefulWidget {
  const BuzzerControlScreen({super.key});

  @override
  State<BuzzerControlScreen> createState() => _BuzzerControlScreenState();
}

class _BuzzerControlScreenState extends State<BuzzerControlScreen> {
  final String espIp = "http://172.20.10.2";

  Future<void> turnOnBuzzer() async {
    try {
      final response = await http.get(Uri.parse('$espIp/buzzer/on'));
      if (response.statusCode == 200) debugPrint("BUZZER turned ON");
    } catch (e) {
      debugPrint("Error: $e");
    }
  }

  Future<void> turnOffBuzzer() async {
    try {
      final response = await http.get(Uri.parse('$espIp/buzzer/off'));
      if (response.statusCode == 200) debugPrint("BUZZER turned OFF");
    } catch (e) {
      debugPrint("Error: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Audio Alarm Control'),
        backgroundColor: Colors.deepPurple,
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.volume_up, size: 80, color: Colors.deepPurple),
            const SizedBox(height: 20),
            const Text("Buzzer Settings", style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
            const SizedBox(height: 30),

            ElevatedButton(
              onPressed: turnOnBuzzer,
              style: ElevatedButton.styleFrom(backgroundColor: Colors.green, minimumSize: const Size(200, 50)),
              child: const Text('Turn ON Buzzer', style: TextStyle(color: Colors.white, fontSize: 16)),
            ),
            const SizedBox(height: 15),
            ElevatedButton(
              onPressed: turnOffBuzzer,
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red, minimumSize: const Size(200, 50)),
              child: const Text('Turn OFF Buzzer', style: TextStyle(color: Colors.white, fontSize: 16)),
            ),
          ],
        ),
      ),
    );
  }
}