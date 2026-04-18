class Shelf {
  final int id;
  final String name;

  Shelf({required this.id, required this.name});

  factory Shelf.fromJson(Map<String, dynamic> json) {
    return Shelf(
      id: int.tryParse(json['id'].toString()) ?? 0,
      name: json['name']?.toString() ?? '',
    );
  }
}
