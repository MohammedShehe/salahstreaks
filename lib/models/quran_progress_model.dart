class QuranProgress {
  int juz;
  int pagesRead;
  int totalPages;
  DateTime lastRead;
  int dailyGoalPages;

  QuranProgress({
    required this.juz,
    this.pagesRead = 0,
    this.totalPages = 20,
    required this.lastRead,
    this.dailyGoalPages = 5,
  });

  Map<String, dynamic> toJson() => {
    'juz': juz,
    'pagesRead': pagesRead,
    'totalPages': totalPages,
    'lastRead': lastRead.toIso8601String(),
    'dailyGoalPages': dailyGoalPages,
  };

  factory QuranProgress.fromJson(Map<String, dynamic> json) => QuranProgress(
    juz: json['juz'],
    pagesRead: json['pagesRead'] ?? 0,
    totalPages: json['totalPages'] ?? 20,
    lastRead: DateTime.parse(json['lastRead']),
    dailyGoalPages: json['dailyGoalPages'] ?? 5,
  );

  // Helper method to get total pages read across all Juz
  int get totalPagesRead {
    return (juz - 1) * totalPages + pagesRead;
  }

  // Helper method to get total pages in Quran (30 Juz * 20 pages)
  static int get totalQuranPages => 30 * 20;

  // Helper method to get completion percentage
  double get completionPercentage {
    final total = 30 * totalPages;
    final read = (juz - 1) * totalPages + pagesRead;
    return (read / total) * 100;
  }

  // Check if a Juz is completed
  bool isJuzCompleted(int juzNumber) {
    if (juzNumber < juz) return true;
    if (juzNumber > juz) return false;
    return pagesRead >= totalPages;
  }

  // Get current Juz progress as a percentage
  double get currentJuzProgress {
    return (pagesRead / totalPages) * 100;
  }
}