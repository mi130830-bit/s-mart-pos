import 'dart:convert';

/// Advanced Promotion Model
class Promotion {
  final int id;
  final String name;
  final String type; // simple, buy_x_get_y, bundle, tier
  final DateTime? startDate;
  final DateTime? endDate;
  final String? startTime; // "HH:mm"
  final String? endTime; // "HH:mm"
  final List<int> daysOfWeek; // 1=Mon, 7=Sun
  final bool memberOnly;
  final int priority;
  final bool isActive;

  // JSON Rules
  final Map<String, dynamic> conditions;
  final Map<String, dynamic> rewards;

  // Legacy fields (kept for backward compatibility during migration)
  // They will be mapped to conditions/rewards if JSON is empty

  Promotion({
    required this.id,
    required this.name,
    this.type = 'simple',
    this.startDate,
    this.endDate,
    this.startTime,
    this.endTime,
    this.daysOfWeek = const [],
    this.memberOnly = false,
    this.priority = 0,
    this.isActive = true,
    this.conditions = const {},
    this.rewards = const {},
  });

  bool get isValid {
    final now = DateTime.now();
    if (!isActive) return false;

    // Date Range
    if (startDate != null && now.isBefore(startDate!)) return false;
    if (endDate != null && now.isAfter(endDate!)) return false;

    // Time Range (Simple string compare works for 24h format "HH:mm")
    if (startTime != null && endTime != null) {
      final nowTime =
          "${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}";
      if (nowTime.compareTo(startTime!) < 0 ||
          nowTime.compareTo(endTime!) > 0) {
        return false;
      }
    }

    // Days of Week
    if (daysOfWeek.isNotEmpty && !daysOfWeek.contains(now.weekday)) {
      return false;
    }

    return true;
  }

  factory Promotion.fromJson(Map<String, dynamic> json) {
    // Parse JSON columns
    Map<String, dynamic> parseJsonCol(dynamic val) {
      if (val == null) return {};
      if (val is Map) return Map<String, dynamic>.from(val);
      if (val is String && val.isNotEmpty) {
        try {
          return jsonDecode(val);
        } catch (_) {}
      }
      return {};
    }

    return Promotion(
      id: int.tryParse(json['id'].toString()) ?? 0,
      name: json['name'] ?? '',
      type: json['type'] ?? 'simple',
      startDate: json['startDate'] != null
          ? DateTime.tryParse(json['startDate'].toString())
          : null,
      endDate: json['endDate'] != null
          ? DateTime.tryParse(json['endDate'].toString())
          : null,
      startTime: json['start_time'], // DB column usually snake_case
      endTime: json['end_time'],
      daysOfWeek: (json['days_of_week'] as String?)
              ?.split(',')
              .map((e) => int.tryParse(e) ?? 0)
              .where((e) => e > 0)
              .toList() ??
          [],
      memberOnly: (json['member_only'] == 1 || json['member_only'] == true),
      priority: int.tryParse(json['priority'].toString()) ?? 0,
      isActive: (json['isActive'] == 1 || json['isActive'] == true),
      conditions: parseJsonCol(json['conditions']),
      rewards: parseJsonCol(json['rewards']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'type': type,
      'startDate': startDate?.toIso8601String(),
      'endDate': endDate?.toIso8601String(),
      'start_time': startTime,
      'end_time': endTime,
      'days_of_week': daysOfWeek.join(','),
      'member_only': memberOnly ? 1 : 0,
      'priority': priority,
      'isActive': isActive ? 1 : 0,
      'conditions': jsonEncode(conditions),
      'rewards': jsonEncode(rewards),
    };
  }
}
