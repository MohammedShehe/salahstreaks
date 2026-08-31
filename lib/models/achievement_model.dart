class Achievement {
  final String id;
  final String title;
  final String description;
  final String icon;
  final String category;
  final int requirement;
  final bool isUnlocked;
  final DateTime? unlockedAt;

  Achievement({
    required this.id,
    required this.title,
    required this.description,
    required this.icon,
    required this.category,
    required this.requirement,
    this.isUnlocked = false,
    this.unlockedAt,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'description': description,
    'icon': icon,
    'category': category,
    'requirement': requirement,
    'isUnlocked': isUnlocked,
    'unlockedAt': unlockedAt?.toIso8601String(),
  };

  factory Achievement.fromJson(Map<String, dynamic> json) => Achievement(
    id: json['id'],
    title: json['title'],
    description: json['description'],
    icon: json['icon'],
    category: json['category'],
    requirement: json['requirement'],
    isUnlocked: json['isUnlocked'] ?? false,
    unlockedAt: json['unlockedAt'] != null 
        ? DateTime.parse(json['unlockedAt']) 
        : null,
  );
}

class UserAchievement {
  String achievementId;
  int currentProgress;
  bool isUnlocked;
  DateTime? unlockedAt;

  UserAchievement({
    required this.achievementId,
    this.currentProgress = 0,
    this.isUnlocked = false,
    this.unlockedAt,
  });

  Map<String, dynamic> toJson() => {
    'achievementId': achievementId,
    'currentProgress': currentProgress,
    'isUnlocked': isUnlocked,
    'unlockedAt': unlockedAt?.toIso8601String(),
  };

  factory UserAchievement.fromJson(Map<String, dynamic> json) => UserAchievement(
    achievementId: json['achievementId'],
    currentProgress: json['currentProgress'] ?? 0,
    isUnlocked: json['isUnlocked'] ?? false,
    unlockedAt: json['unlockedAt'] != null 
        ? DateTime.parse(json['unlockedAt']) 
        : null,
  );
}