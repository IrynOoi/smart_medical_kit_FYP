// lib/models/iot_device.dart

class IoTDevice {
  final int deviceId;
  final int? patientId;
  final String deviceSerial;
  final int? batteryLevel;
  final DateTime? lastActiveTimestamp;
  final String? lastKnownIp;
  final bool isAwake;

  IoTDevice({
    required this.deviceId,
    this.patientId,
    required this.deviceSerial,
    this.batteryLevel,
    this.lastActiveTimestamp,
    this.lastKnownIp,
    this.isAwake = true,
  });

  factory IoTDevice.fromJson(Map<String, dynamic> json) {
    final rawBatt = json['battery_level'] ?? json['battery'];
    final int? batt = rawBatt is num ? rawBatt.toInt() : (rawBatt != null ? int.tryParse(rawBatt.toString()) : null);
    
    DateTime? timestamp;
    final rawTs = json['last_active_timestamp'] ?? json['last_battery_report'];
    if (rawTs != null) {
      timestamp = DateTime.tryParse(rawTs.toString());
    }

    final rawAwake = json['is_awake'];
    final bool awake = !(rawAwake == false || rawAwake == 0);

    return IoTDevice(
      deviceId: json['device_id'] ?? json['id'] ?? 0,
      patientId: json['patient_id'],
      deviceSerial: json['device_serial'] ?? 'Unknown',
      batteryLevel: batt,
      lastActiveTimestamp: timestamp,
      lastKnownIp: json['last_known_ip'],
      isAwake: awake,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'device_id': deviceId,
      'patient_id': patientId,
      'device_serial': deviceSerial,
      'battery_level': batteryLevel,
      'last_active_timestamp': lastActiveTimestamp?.toIso8601String(),
      'last_known_ip': lastKnownIp,
      'is_awake': isAwake,
    };
  }
}

