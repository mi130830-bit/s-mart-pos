enum ConditionType { itemQty, totalSpend, matchProduct }

enum ActionType { discountPercent, discountAmount, freeItem }

class Promotion {
  final int id;
  final String name;
  final DateTime? startDate;
  final DateTime? endDate;
  final bool isActive;
  final ConditionType conditionType;
  final double conditionValue; // e.g. 2 for Buy 2, 1000 for Spend 1000
  final ActionType actionType;
  final double actionValue; // e.g. 10.0 for 10%, 1 for 1 item
  final List<int> eligibleProductIds; // products that trigger or get discount

  Promotion({
    required this.id,
    required this.name,
    this.startDate,
    this.endDate,
    this.isActive = true,
    required this.conditionType,
    required this.conditionValue,
    required this.actionType,
    required this.actionValue,
    this.eligibleProductIds = const [],
  });

  bool get isValid {
    final now = DateTime.now();
    if (!isActive) return false;
    if (startDate != null && now.isBefore(startDate!)) return false;
    if (endDate != null && now.isAfter(endDate!)) return false;
    return true;
  }

  factory Promotion.fromJson(Map<String, dynamic> json) {
    return Promotion(
      id: int.tryParse(json['id'].toString()) ?? 0,
      name: json['name'] ?? '',
      startDate: json['startDate'] != null
          ? DateTime.tryParse(json['startDate'])
          : null,
      endDate:
          json['endDate'] != null ? DateTime.tryParse(json['endDate']) : null,
      isActive: (json['isActive'] == 1 || json['isActive'] == true),
      conditionType: ConditionType.values.firstWhere(
          (e) => e.name == (json['conditionType'] ?? 'totalSpend'),
          orElse: () => ConditionType.totalSpend),
      conditionValue: double.tryParse(json['conditionValue'].toString()) ?? 0.0,
      actionType: ActionType.values.firstWhere(
          (e) => e.name == (json['actionType'] ?? 'discountAmount'),
          orElse: () => ActionType.discountAmount),
      actionValue: double.tryParse(json['actionValue'].toString()) ?? 0.0,
      eligibleProductIds: (json['eligibleProductIds'] as String?)
              ?.split(',')
              .map((e) => int.tryParse(e) ?? 0)
              .where((e) => e > 0)
              .toList() ??
          [],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'startDate': startDate?.toIso8601String(),
      'endDate': endDate?.toIso8601String(),
      'isActive': isActive ? 1 : 0,
      'conditionType': conditionType.name,
      'conditionValue': conditionValue,
      'actionType': actionType.name,
      'actionValue': actionValue,
      'eligibleProductIds': eligibleProductIds.join(','),
    };
  }
}
