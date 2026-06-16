class SpecialHoliday {
  final int id;
  final DateTime date;
  final String name;
  final DateTime createdAt;

  SpecialHoliday({
    required this.id,
    required this.date,
    required this.name,
    required this.createdAt,
  });

  factory SpecialHoliday.fromJson(Map<String, dynamic> json) {
    return SpecialHoliday(
      id: int.tryParse(json['id']?.toString() ?? '0') ?? 0,
      date: json['date'] != null ? DateTime.parse(json['date'].toString()) : DateTime.now(),
      name: json['name']?.toString() ?? '',
      createdAt: json['created_at'] != null ? DateTime.parse(json['created_at'].toString()) : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'date': date.toIso8601String().split('T')[0],
      'name': name,
      'created_at': createdAt.toIso8601String(),
    };
  }
}
