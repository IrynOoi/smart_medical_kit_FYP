// lib/models/inventory.dart

class Inventory {
  final int inventoryId;       // matches inventory_id in DB
  final int prescriptionId;
  final int changeAmount;      // positive = refill, negative = dispense
  final int newBalance;
  final String reason;         // 'dispense', 'refill', etc.
  final DateTime createdAt;

  Inventory({
    required this.inventoryId,
    required this.prescriptionId,
    required this.changeAmount,
    required this.newBalance,
    required this.reason,
    required this.createdAt,
  });

  bool get isDispense => changeAmount < 0;
  bool get isRefill => changeAmount > 0;

  factory Inventory.fromJson(Map<String, dynamic> json) {
    return Inventory(
      inventoryId: json['inventory_id'],
      prescriptionId: json['prescription_id'],
      changeAmount: json['change_amount'],
      newBalance: json['new_balance'],
      reason: json['reason'],
      createdAt: DateTime.parse(json['created_at']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'inventory_id': inventoryId,
      'prescription_id': prescriptionId,
      'change_amount': changeAmount,
      'new_balance': newBalance,
      'reason': reason,
      'created_at': createdAt.toIso8601String(),
    };
  }
}
