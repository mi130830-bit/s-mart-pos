class Expense {
  final int id;
  final String title;
  final double amount;
  final String category;
  final DateTime date;
  final String? note;

  Expense({
    required this.id,
    required this.title,
    required this.amount,
    required this.category,
    required this.date,
    this.note,
  });

  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'amount': amount,
      'category': category,
      'expenseDate': date.toIso8601String(),
      'note': note,
    };
  }

  factory Expense.fromMap(Map<String, dynamic> map) {
    return Expense(
      id: map['id'] ?? 0,
      title: map['title'] ?? '',
      amount: double.tryParse(map['amount'].toString()) ?? 0.0,
      category: map['category'] ?? 'General',
      date: DateTime.tryParse(map['expenseDate'].toString()) ?? DateTime.now(),
      note: map['note'],
    );
  }
}
