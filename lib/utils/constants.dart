const List<String> ibadatTypes = [
  'Salah',
  'Sawm',
  'Qiyyam',
  'Quran',
  'Sadaqat',
];

const List<Map<String, String>> quranVerses = [
  {
    'verse': 'إِنَّ اللَّهَ مَعَ الصَّابِرِينَ',
    'translation': 'Indeed, Allah is with the patient.',
  },
  {
    'verse': 'فَاذْكُرُونِي أَذْكُرْكُمْ وَاشْكُرُوا لِي وَلَا تَكْفُرُونِ',
    'translation': 'So remember Me; I will remember you. And be grateful to Me and do not deny Me.',
  },
  {
    'verse': 'وَالَّذِينَ جَاهَدُوا فِينَا لَنَهْدِيَنَّهُمْ سُبُلَنَا',
    'translation': 'And those who strive for Us - We will surely guide them to Our ways.',
  },
  {
    'verse': 'وَمَنْ أَعْرَضَ عَن ذِكْرِي فَإِنَّ لَهُ مَعِيشَةً ضَنكًا',
    'translation': 'And whoever turns away from My remembrance - indeed, he will have a depressed life.',
  },
  {
    'verse': 'لِيَبْلُوَكُمْ أَيُّكُمْ أَحْسَنُ عَمَلًا',
    'translation': 'He created death and life to test you as to which of you is best in deed.',
  },
  {
    'verse': 'فَإِنَّ مَعَ الْعُسْرِ يُسْرًا',
    'translation': 'For indeed, with hardship comes ease.',
  },
  {
    'verse': 'إِنَّ اللَّهَ يُحِبُّ التَّوَّابِينَ وَيُحِبُّ الْمُتَطَهِّرِينَ',
    'translation': 'Indeed, Allah loves those who are constantly repentant and loves those who purify themselves.',
  },
  {
    'verse': 'وَقُل رَّبِّ زِدْنِي عِلْمًا',
    'translation': 'And say, "My Lord, increase me in knowledge."',
  },
  {
    'verse': 'فَإِنَّ مَعَ الْعُسْرِ يُسْرًا',
    'translation': 'For indeed, with hardship comes ease.',
  },
  {
    'verse': 'إِنَّ فِي ذَٰلِكَ لَذِكْرَىٰ لِمَن كَانَ لَهُ قَلْبٌ',
    'translation': 'Indeed in that is a reminder for whoever has a heart.',
  },
];

const List<String> quranSurahList = [
  'Al-Fatihah', 'Al-Baqarah', 'Aal-Imran', 'An-Nisa', 'Al-Ma\'idah',
  'Al-An\'am', 'Al-A\'raf', 'Al-Anfal', 'At-Tawbah', 'Yunus',
  'Hud', 'Yusuf', 'Ar-Ra\'d', 'Ibrahim', 'Al-Hijr',
  'An-Nahl', 'Al-Isra', 'Al-Kahf', 'Maryam', 'Taha',
  'Al-Anbiya', 'Al-Hajj', 'Al-Mu\'minun', 'An-Nur', 'Al-Furqan',
  'Ash-Shu\'ara', 'An-Naml', 'Al-Qasas', 'Al-Ankabut', 'Ar-Rum',
  'Luqman', 'As-Sajdah', 'Al-Ahzab', 'Saba', 'Fatir',
  'Yasin', 'As-Saffat', 'Sad', 'Az-Zumar', 'Ghafir',
  'Fussilat', 'Ash-Shura', 'Az-Zukhruf', 'Ad-Dukhan', 'Al-Jathiyah',
  'Al-Ahqaf', 'Muhammad', 'Al-Fath', 'Al-Hujurat', 'Qaf',
  'Adh-Dhariyat', 'At-Tur', 'An-Najm', 'Al-Qamar', 'Ar-Rahman',
  'Al-Waqi\'ah', 'Al-Hadid', 'Al-Mujadilah', 'Al-Hashr', 'Al-Mumtahanah',
  'As-Saff', 'Al-Jumu\'ah', 'Al-Munafiqun', 'At-Taghabun', 'At-Talaq',
  'At-Tahrim', 'Al-Mulk', 'Al-Qalam', 'Al-Haqqah', 'Al-Ma\'arij',
  'Nuh', 'Al-Jinn', 'Al-Muzzammil', 'Al-Muddathir', 'Al-Qiyamah',
  'Al-Insan', 'Al-Mursalat', 'An-Naba', 'An-Nazi\'at', 'Abasa',
  'At-Takwir', 'Al-Infitar', 'Al-Mutaffifin', 'Al-Inshiqaq', 'Al-Buruj',
  'At-Tariq', 'Al-A\'la', 'Al-Ghashiyah', 'Al-Fajr', 'Al-Balad',
  'Ash-Shams', 'Al-Layl', 'Ad-Duha', 'Ash-Sharh', 'At-Tin',
  'Al-Alaq', 'Al-Qadr', 'Al-Bayyinah', 'Az-Zalzalah', 'Al-Adiyat',
  'Al-Qari\'ah', 'At-Takathur', 'Al-Asr', 'Al-Humazah', 'Al-Fil',
  'Quraysh', 'Al-Ma\'un', 'Al-Kawthar', 'Al-Kafirun', 'An-Nasr',
  'Al-Masad', 'Al-Ikhlas', 'Al-Falaq', 'An-Nas',
];

// Adhkar Data
const List<Map<String, dynamic>> morningAdhkar = [
  {
    'id': 'm1',
    'title': 'Morning Dua',
    'arabic': 'أَصْبَحْنَا وَأَصْبَحَ الْمُلْكُ لِلَّهِ وَالْحَمْدُ لِلَّهِ',
    'translation': 'We have entered the morning and the kingdom belongs to Allah, and all praise is due to Allah.',
    'count': 1,
    'category': 'morning',
  },
  {
    'id': 'm2',
    'title': 'Protection from Evil',
    'arabic': 'بِسْمِ اللَّهِ الَّذِي لَا يَضُرُّ مَعَ اسْمِهِ شَيْءٌ فِي الْأَرْضِ وَلَا فِي السَّمَاءِ',
    'translation': 'In the name of Allah, with whose name nothing can cause harm on earth or in heaven.',
    'count': 3,
    'category': 'morning',
  },
  {
    'id': 'm3',
    'title': 'Morning Remembrance',
    'arabic': 'لَا إِلَهَ إِلَّا اللَّهُ وَحْدَهُ لَا شَرِيكَ لَهُ',
    'translation': 'There is no god but Allah alone, He has no partner.',
    'count': 10,
    'category': 'morning',
  },
];

const List<Map<String, dynamic>> eveningAdhkar = [
  {
    'id': 'e1',
    'title': 'Evening Dua',
    'arabic': 'أَمْسَيْنَا وَأَمْسَى الْمُلْكُ لِلَّهِ وَالْحَمْدُ لِلَّهِ',
    'translation': 'We have entered the evening and the kingdom belongs to Allah, and all praise is due to Allah.',
    'count': 1,
    'category': 'evening',
  },
  {
    'id': 'e2',
    'title': 'Protection from Evil',
    'arabic': 'بِسْمِ اللَّهِ الَّذِي لَا يَضُرُّ مَعَ اسْمِهِ شَيْءٌ فِي الْأَرْضِ وَلَا فِي السَّمَاءِ',
    'translation': 'In the name of Allah, with whose name nothing can cause harm on earth or in heaven.',
    'count': 3,
    'category': 'evening',
  },
  {
    'id': 'e3',
    'title': 'Evening Remembrance',
    'arabic': 'أَعُوذُ بِكَلِمَاتِ اللَّهِ التَّامَّاتِ مِنْ شَرِّ مَا خَلَقَ',
    'translation': 'I seek refuge in the perfect words of Allah from the evil of what He has created.',
    'count': 3,
    'category': 'evening',
  },
];

// Achievement Data
const List<Map<String, dynamic>> achievements = [
  {
    'id': 'salah_7',
    'title': 'Salah Streak 7',
    'description': 'Prayed all 5 Salah for 7 consecutive days',
    'icon': '🕌',
    'category': 'Salah',
    'requirement': 7,
  },
  {
    'id': 'salah_30',
    'title': 'Salah Streak 30',
    'description': 'Prayed all 5 Salah for 30 consecutive days',
    'icon': '🕌',
    'category': 'Salah',
    'requirement': 30,
  },
  {
    'id': 'quran_1',
    'title': 'Quran Beginner',
    'description': 'Read 1 Juz of Quran',
    'icon': '📖',
    'category': 'Quran',
    'requirement': 20,
  },
  {
    'id': 'quran_5',
    'title': 'Quran Enthusiast',
    'description': 'Read 5 Juz of Quran',
    'icon': '📖',
    'category': 'Quran',
    'requirement': 100,
  },
  {
    'id': 'fast_1',
    'title': 'First Fast',
    'description': 'Completed your first fast',
    'icon': '🌙',
    'category': 'Sawm',
    'requirement': 1,
  },
  {
    'id': 'fast_10',
    'title': 'Fasting Champion',
    'description': 'Completed 10 fasts',
    'icon': '🌙',
    'category': 'Sawm',
    'requirement': 10,
  },
  {
    'id': 'sadaqat_1',
    'title': 'Generous Soul',
    'description': 'Gave Sadaqah for the first time',
    'icon': '❤️',
    'category': 'Sadaqat',
    'requirement': 1,
  },
  {
    'id': 'qiyyam_1',
    'title': 'Night Guardian',
    'description': 'Prayed Qiyyam for the first time',
    'icon': '🌙',
    'category': 'Qiyyam',
    'requirement': 1,
  },
];

// Hijri Months
const List<String> hijriMonths = [
  'Muharram', 'Safar', 'Rabi al-Awwal', 'Rabi al-Thani',
  'Jumada al-Awwal', 'Jumada al-Thani', 'Rajab', 'Sha\'ban',
  'Ramadan', 'Shawwal', 'Dhul Qa\'dah', 'Dhul Hijjah',
];

// Calculation Methods for Prayer Times
const Map<int, String> calculationMethods = {
  0: 'Muslim World League',
  1: 'Islamic Society of North America',
  2: 'Egyptian General Authority',
  3: 'Umm al-Qura University, Makkah',
  4: 'University of Islamic Sciences, Karachi',
  5: 'Institute of Geophysics, University of Tehran',
};