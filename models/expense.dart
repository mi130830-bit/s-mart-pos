class Expense {
  final int id;
  final String title;
  final double amount;
  final String category;
  final DateTime date;
  final String? note; // Can be null
  final String type; // 'EXPENSE' or 'INCOME'

  Expense({
    required this.id,
    required this.title,
    required this.amount,
    required this.category,
    required this.date,
    this.note,
    this.type = 'EXPENSE',
  });

  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'amount': amount,
      'category': category,
      'expenseDate': date.toIso8601String(),
      'note': note,
      'type': type,
    };
  }

  factory Expense.fromMap(Map<String, dynamic> map) {
    return Expense(
      id: int.tryParse(map['id']?.toString() ?? '0') ?? 0,
      title: map['title']?.toString() ?? '',
      amount: double.tryParse(map['amount']?.toString() ?? '0') ?? 0.0,
      category: map['category']?.toString() ?? 'ทั่วไป',
      date: DateTime.tryParse(map['expenseDate']?.toString() ?? '') ?? DateTime.now(),
      note: map['note']?.toString(),
      type: map['type']?.toString() ?? 'EXPENSE',
    );
  }
}
