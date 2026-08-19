// lib/models/iot_device.dart

class IoTDevice {
  final int deviceId;
  final int patientId;
  final String deviceSerial;
  final int batteryLevel;
  final DateTime lastActiveTimestamp;

  IoTDevice({
    required this.deviceId,
    required this.patientId,
    required this.deviceSerial,
    required this.batteryLevel,
    required this.lastActiveTimestamp,
  });

  factory IoTDevice.fromJson(Map<String, dynamic> json) {
    return IoTDevice(
      deviceId: json['device_id'],
      patientId: json['patient_id'],
      deviceSerial: json['device_serial'],
      batteryLevel: json['battery_level'] ?? 100,
      lastActiveTimestamp: DateTime.parse(json['last_active_timestamp']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'device_id': deviceId,
      'patient_id': patientId,
      'device_serial': deviceSerial,
      'battery_level': batteryLevel,
      'last_active_timestamp': lastActiveTimestamp.toIso8601String(),
    };
  }
}
