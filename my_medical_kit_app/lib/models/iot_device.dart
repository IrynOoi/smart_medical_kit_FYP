// lib/models/iot_device.dart

class IoTDevice {
  final int? deviceId;
  final int? patientId;
  final String deviceSerial;
  final int? batteryLevel;
  final DateTime? lastActiveTimestamp;
  final String? lastKnownIp;
  final bool isAwake;

  IoTDevice({
    this.deviceId,
    this.patientId,
    required this.deviceSerial,
    this.batteryLevel,
    this.lastActiveTimestamp,
    this.lastKnownIp,
    this.isAwake = true,
  });

  factory IoTDevice.fromJson(Map<String, dynamic> json) {
    DateTime? parsedDate;
    final rawTimestamp = json['last_active_timestamp'] ?? json['last_battery_report'];
    if (rawTimestamp != null) {
      parsedDate = DateTime.tryParse(rawTimestamp.toString());
    }

    final rawAwake = json['is_awake'];
    final bool awake = !(rawAwake == false || rawAwake == 0);

    final rawBatt = json['battery_level'] ?? json['battery'];
    final int? batt = rawBatt != null ? (rawBatt as num).toInt() : null;

    return IoTDevice(
      deviceId: json['device_id'] is num ? (json['device_id'] as num).toInt() : null,
      patientId: json['patient_id'] is num ? (json['patient_id'] as num).toInt() : null,
      deviceSerial: json['device_serial']?.toString() ?? 'Unknown',
      batteryLevel: batt,
      lastActiveTimestamp: parsedDate,
      lastKnownIp: json['last_known_ip']?.toString(),
      isAwake: awake,
    );
  }

  /// Device is considered Online if it has a heartbeat within 24 hours AND is not sleeping.
  bool get isOnline {
    if (lastActiveTimestamp == null) return false;
    final diffHours = DateTime.now().difference(lastActiveTimestamp!).inHours;
    return diffHours < 24 && isAwake;
  }

  bool get isLowBattery => isOnline && batteryLevel != null && batteryLevel! < 20;

  String get batteryDisplay => isOnline && batteryLevel != null ? '$batteryLevel%' : '--';

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
