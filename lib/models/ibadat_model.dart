class IbadatLog {
  final String type;
  final DateTime date;
  final int salahCount;
  final String sawmType;
  final int rakahCount;
  final int versesCount;
  final String surahName;
  final String sadaqatType;
  final String note;
  final double amount;

  IbadatLog({
    required this.type,
    required this.date,
    this.salahCount = 0,
    this.sawmType = '',
    this.rakahCount = 0,
    this.versesCount = 0,
    this.surahName = '',
    this.sadaqatType = '',
    this.note = '',
    this.amount = 0.0,
  });

  Map<String, dynamic> toJson() => {
    'type': type,
    'date': date.toIso8601String(),
    'salahCount': salahCount,
    'sawmType': sawmType,
    'rakahCount': rakahCount,
    'versesCount': versesCount,
    'surahName': surahName,
    'sadaqatType': sadaqatType,
    'note': note,
    'amount': amount,
  };

  factory IbadatLog.fromJson(Map<String, dynamic> json) => IbadatLog(
    type: json['type'],
    date: DateTime.parse(json['date']),
    salahCount: json['salahCount'] ?? 0,
    sawmType: json['sawmType'] ?? '',
    rakahCount: json['rakahCount'] ?? 0,
    versesCount: json['versesCount'] ?? 0,
    surahName: json['surahName'] ?? '',
    sadaqatType: json['sadaqatType'] ?? '',
    note: json['note'] ?? '',
    amount: json['amount']?.toDouble() ?? 0.0,
  );
}