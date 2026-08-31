class Adhkar {
  final String id;
  final String title;
  final String arabic;
  final String translation;
  final int count;
  final String category; // 'morning', 'evening', 'general'

  Adhkar({
    required this.id,
    required this.title,
    required this.arabic,
    required this.translation,
    required this.count,
    required this.category,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'arabic': arabic,
    'translation': translation,
    'count': count,
    'category': category,
  };

  factory Adhkar.fromJson(Map<String, dynamic> json) => Adhkar(
    id: json['id'],
    title: json['title'],
    arabic: json['arabic'],
    translation: json['translation'],
    count: json['count'],
    category: json['category'],
  );
}

class AdhkarLog {
  final String adhkarId;
  final DateTime date;
  final int count;

  AdhkarLog({
    required this.adhkarId,
    required this.date,
    required this.count,
  });

  Map<String, dynamic> toJson() => {
    'adhkarId': adhkarId,
    'date': date.toIso8601String(),
    'count': count,
  };

  factory AdhkarLog.fromJson(Map<String, dynamic> json) => AdhkarLog(
    adhkarId: json['adhkarId'],
    date: DateTime.parse(json['date']),
    count: json['count'] ?? 0,
  );
}