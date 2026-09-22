class UserSettings {
  bool darkMode;
  bool notificationsEnabled;
  bool prayerReminders;
  bool quranReminders;
  bool adhkarReminders;
  String? city;
  double? latitude;
  double? longitude;
  int calculationMethod;
  int madhab;
  bool notificationsSound;
  bool notificationsVibrate;
  String language;
  bool backupAuto;

  /// AI Bot (serverless): user-owned free API key — never shipped in the app binary.
  bool aiBotEnabled;
  String aiProvider; // groq | gemini | xai | openai_compatible
  String aiApiKey;
  String aiBaseUrl; // for openai_compatible
  String aiModel; // optional override

  UserSettings({
    this.darkMode = true,
    this.notificationsEnabled = true,
    this.prayerReminders = true,
    this.quranReminders = true,
    this.adhkarReminders = true,
    this.city,
    this.latitude,
    this.longitude,
    this.calculationMethod = 2,
    this.madhab = 1,
    this.notificationsSound = true,
    this.notificationsVibrate = true,
    this.language = 'en',
    this.backupAuto = false,
    this.aiBotEnabled = false,
    this.aiProvider = 'groq',
    this.aiApiKey = '',
    this.aiBaseUrl = '',
    this.aiModel = '',
  });

  Map<String, dynamic> toJson() => {
        'darkMode': darkMode,
        'notificationsEnabled': notificationsEnabled,
        'prayerReminders': prayerReminders,
        'quranReminders': quranReminders,
        'adhkarReminders': adhkarReminders,
        'city': city,
        'latitude': latitude,
        'longitude': longitude,
        'calculationMethod': calculationMethod,
        'madhab': madhab,
        'notificationsSound': notificationsSound,
        'notificationsVibrate': notificationsVibrate,
        'language': language,
        'backupAuto': backupAuto,
        'aiBotEnabled': aiBotEnabled,
        'aiProvider': aiProvider,
        'aiApiKey': aiApiKey,
        'aiBaseUrl': aiBaseUrl,
        'aiModel': aiModel,
      };

  factory UserSettings.fromJson(Map<String, dynamic> json) => UserSettings(
        darkMode: json['darkMode'] ?? true,
        notificationsEnabled: json['notificationsEnabled'] ?? true,
        prayerReminders: json['prayerReminders'] ?? true,
        quranReminders: json['quranReminders'] ?? true,
        adhkarReminders: json['adhkarReminders'] ?? true,
        city: json['city'],
        latitude: json['latitude'],
        longitude: json['longitude'],
        calculationMethod: json['calculationMethod'] ?? 2,
        madhab: json['madhab'] ?? 1,
        notificationsSound: json['notificationsSound'] ?? true,
        notificationsVibrate: json['notificationsVibrate'] ?? true,
        language: json['language'] ?? 'en',
        backupAuto: json['backupAuto'] ?? false,
        aiBotEnabled: json['aiBotEnabled'] ?? false,
        aiProvider: json['aiProvider'] ?? 'groq',
        aiApiKey: json['aiApiKey'] ?? '',
        aiBaseUrl: json['aiBaseUrl'] ?? '',
        aiModel: json['aiModel'] ?? '',
      );
}
