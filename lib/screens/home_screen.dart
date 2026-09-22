import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart' as flutter;
import 'package:salahstreaks/utils/app_theme.dart';
import 'package:provider/provider.dart';
import 'package:salahstreaks/providers/app_provider.dart';
import 'package:salahstreaks/widgets/profile_widget.dart';
import 'package:salahstreaks/widgets/streaks_widget.dart';
import 'package:salahstreaks/widgets/logging_widgets.dart';
import 'package:salahstreaks/widgets/events_slider.dart';
import 'package:salahstreaks/utils/constants.dart';
import 'package:intl/intl.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter/services.dart';
import 'package:salahstreaks/screens/adhkar_screen.dart';
import 'package:salahstreaks/screens/achievements_screen.dart';
import 'package:salahstreaks/screens/prayer_times_screen.dart';
import 'package:salahstreaks/screens/settings_screen.dart';
import 'package:salahstreaks/screens/ai_bot_screen.dart';
import 'package:salahstreaks/services/daily_verse_service.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  String _currentVerse = '';
  String _currentTranslation = '';
  String _currentTafsir = '';
  String _currentVerseReference = '';
  String _currentVerseSource = '';
  String? _currentAiReflection;
  bool _isVerseLoading = true;
  bool _copied = false;

  @override
  void initState() {
    super.initState();
    _loadDailyVerse();
    _startTimer();
  }

  void _startTimer() {
    Future.doWhile(() async {
      await Future.delayed(const Duration(seconds: 1));
      if (mounted) {
        setState(() {});
      }
      return mounted;
    });
  }

  Future<void> _loadDailyVerse() async {
    try {
      final provider = Provider.of<AppProvider>(context, listen: false);
      final verse = await DailyVerseService().loadForToday(
        settings: provider.settings,
      );
      if (!mounted) return;
      setState(() {
        _currentVerse = verse.arabic;
        _currentTranslation = verse.translation;
        _currentTafsir = verse.tafsir;
        _currentVerseReference = verse.reference;
        _currentVerseSource = verse.source;
        _currentAiReflection = verse.aiReflection;
        _isVerseLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _isVerseLoading = false);
    }
  }

  void _copyVerse() {
    final text = '$_currentVerse\n\n$_currentTranslation';
    Clipboard.setData(ClipboardData(text: text));
    setState(() {
      _copied = true;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('📋 Verse copied to clipboard!'),
        backgroundColor: Colors.green,
        duration: Duration(seconds: 2),
      ),
    );
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) {
        setState(() {
          _copied = false;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<AppProvider>(context);
    final now = DateTime.now();
    final dateFormat = DateFormat('EEEE, d MMMM yyyy');
    final timeFormat = DateFormat('hh:mm:ss a');
    final salahCount = provider.getTodaySalahCount();

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: AppThemeColors.pageGradient(context),
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Profile and Quick Actions Row
                Row(
                  children: [
                    Expanded(
                      child: ProfileWidget()
                          .animate()
                          .fadeIn(duration: 600.ms)
                          .slideX(begin: -0.3),
                    ),
                    Row(
                      children: [
                        IconButton(
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => const AiBotScreen(),
                              ),
                            );
                          },
                          icon: const Icon(Icons.smart_toy_outlined, color: Colors.tealAccent),
                          tooltip: 'AI Bot',
                        ),
                        IconButton(
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => const AdhkarScreen(),
                              ),
                            );
                          },
                          icon: const Icon(Icons.menu_book_rounded, color: Colors.green),
                          tooltip: 'Adhkar',
                        ),
                        IconButton(
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => const AchievementsScreen(),
                              ),
                            );
                          },
                          icon: const Icon(Icons.emoji_events, color: Colors.amber),
                          tooltip: 'Achievements',
                        ),
                        IconButton(
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => const PrayerTimesScreen(),
                              ),
                            );
                          },
                          icon: Icon(Icons.mosque, color: AppThemeColors.icon(context)),
                          tooltip: 'Prayer Times',
                        ),
                        IconButton(
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => const SettingsScreen(),
                              ),
                            );
                          },
                          icon: const Icon(Icons.settings, color: Colors.grey),
                          tooltip: 'Settings',
                        ),
                      ],
                    ),
                  ],
                ),
                
                const SizedBox(height: 20),
                
                // Date and Time
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: AppThemeColors.cardGradient(context),
                    ),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: AppThemeColors.cardBorder(context),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            dateFormat.format(now),
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: AppThemeColors.textPrimary(context),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            timeFormat.format(now),
                            style: TextStyle(
                              fontSize: 14,
                              color: AppThemeColors.textSecondary(context),
                            ),
                          ),
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: AppThemeColors.panelFillStrong(context),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.calendar_today,
                          color: Colors.green,
                          size: 20,
                        ),
                      ),
                    ],
                  ),
                ).animate().fadeIn(delay: 200.ms),
                
                const SizedBox(height: 20),
                
                // Salah Progress Bar 
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: AppThemeColors.cardGradient(context),
                    ),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: AppThemeColors.cardBorder(context),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            '🕌 Today\'s Salah',
                            style: TextStyle(
                              color: AppThemeColors.textPrimary(context),
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            '${provider.getTodayPrayedSalah().length}/5',
                            style: TextStyle(
                              color: Colors.green[300],
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: LinearProgressIndicator(
                          value: provider.getTodayPrayedSalah().length / 5,
                          minHeight: 8,
                          backgroundColor: Colors.grey[800],
                          valueColor: AlwaysStoppedAnimation<Color>(
                            provider.getTodayPrayedSalah().length >= 5 ? Colors.green : Colors.amber,
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          _buildPrayerStatus('Fajr', provider.isSalahLogged('Fajr')),
                          _buildPrayerStatus('Dhuhr', provider.isSalahLogged('Dhuhr')),
                          _buildPrayerStatus('Asr', provider.isSalahLogged('Asr')),
                          _buildPrayerStatus('Maghrib', provider.isSalahLogged('Maghrib')),
                          _buildPrayerStatus('Isha', provider.isSalahLogged('Isha')),
                        ],
                      ),
                    ],
                  ),
                ).animate().fadeIn(delay: 300.ms),
                
                const SizedBox(height: 20),
                
                // Quran Verse
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        const Color(0xFF1B3A2B),
                        const Color(0xFF0D1B2A),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: AppThemeColors.cardBorder(context),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: AppThemeColors.panelFill(context, 0.2),
                        blurRadius: 20,
                        offset: const Offset(0, 5),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Row(
                        children: [
                          const Text(
                            '📖 Daily Verse',
                            style: TextStyle(
                              color: Color(0xFFC8E6C9),
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const Spacer(),
                          if (_currentVerseReference.isNotEmpty)
                            Text(
                              _currentVerseReference,
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.55),
                                fontSize: 11,
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      if (_isVerseLoading)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 24),
                          child: Center(
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        )
                      else ...[
                        SelectableText(
                          _currentVerse,
                          style: const TextStyle(
                            fontSize: 20,
                            color: Color(0xFFC8E6C9),
                            fontFamily: 'Arabic',
                            height: 1.8,
                          ),
                          textAlign: TextAlign.right,
                        ),
                        const Divider(color: Colors.green, height: 20),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            _currentTranslation,
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey[300],
                              height: 1.5,
                            ),
                          ),
                        ),
                        const SizedBox(height: 14),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: Colors.black.withOpacity(0.14),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: Colors.green.withOpacity(0.25),
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Tafsir • Tafsir al-Muyassar',
                                  style: TextStyle(
                                    color: Color(0xFFA5D6A7),
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 7),
                                Text(
                                  _currentTafsir,
                                  style: TextStyle(
                                    color: Colors.grey[300],
                                    fontSize: 13,
                                    height: 1.5,
                                  ),
                                  textDirection: flutter.TextDirection.rtl,
                                ),
                                if ((_currentAiReflection ?? '').trim().isNotEmpty) ...[
                                  const SizedBox(height: 12),
                                  const Divider(height: 1),
                                  const SizedBox(height: 10),
                                  const Text(
                                    'AI Reflection',
                                    style: TextStyle(
                                      color: Colors.amber,
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 5),
                                  Text(
                                    _currentAiReflection!,
                                    style: TextStyle(
                                      color: Colors.grey[300],
                                      fontSize: 13,
                                      height: 1.5,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),
                        if (_currentVerseSource.isNotEmpty) ...[
                          const SizedBox(height: 7),
                          Align(
                            alignment: Alignment.centerLeft,
                            child: Text(
                              'Source: $_currentVerseSource',
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.38),
                                fontSize: 9,
                              ),
                            ),
                          ),
                        ],
                      ],
                      const SizedBox(height: 10),
                      InkWell(
                        onTap: _copyVerse,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: _copied 
                                ? Colors.green[600]!.withOpacity(0.5)
                                : AppThemeColors.panelFillStrong(context),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                _copied ? Icons.check : Icons.copy,
                                color: _copied ? Colors.green[300] : Colors.green[400],
                                size: 16,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                _copied ? 'Copied!' : 'Copy',
                                style: TextStyle(
                                  color: _copied ? Colors.green[300] : Colors.green[400],
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ).animate().fadeIn(delay: 400.ms),
                
                const SizedBox(height: 20),
                
                // 📅 Islamic Events Slider
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: EdgeInsets.only(bottom: 8),
                      child: Text(
                        '📅 Upcoming Islamic Events',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: AppThemeColors.textPrimary(context),
                        ),
                      ),
                    ),
                    EventsSlider(),
                  ],
                ).animate().fadeIn(delay: 500.ms),
                
                const SizedBox(height: 12),
                
                // Streaks
                StreaksWidget(
                  streaks: provider.streaks,
                  percentages: provider.getStreakPercentages(),
                ).animate().fadeIn(delay: 600.ms),
                
                const SizedBox(height: 20),
                
                // Logging Section
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        const Color(0xFF1A2F1A),
                        const Color(0xFF0A1A0A),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: AppThemeColors.cardBorder(context),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Log Your Ibadat',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: AppThemeColors.textPrimary(context),
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Track your daily worship and earn rewards',
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        children: ibadatTypes.map((type) {
                          final icons = {
                            'Salah': Icons.mosque_rounded,
                            'Sawm': Icons.nightlight_round,
                            'Qiyyam': Icons.nights_stay_rounded,
                            'Quran': Icons.menu_book_rounded,
                            'Sadaqat': Icons.favorite_rounded,
                          };
                          bool isLogged = false;
                          if (type == 'Salah') {
                            isLogged = provider.getTodaySalahCount() >= 5;
                          } else {
                            isLogged = provider.isLoggedToday(type);
                          }
                          
                          return ElevatedButton.icon(
                            onPressed: () => _showLoggingDialog(context, type),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: isLogged 
                                  ? Colors.grey[700] 
                                  : Colors.green[800],
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 12,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            icon: Icon(
                              icons[type], 
                              color: isLogged ? AppThemeColors.textSecondary(context) : Colors.white,
                            ),
                            label: Text(
                              isLogged 
                                  ? (type == 'Salah' ? '✅ All Prayers' : '✅ $type')
                                  : type,
                              style: TextStyle(
                                color: isLogged ? AppThemeColors.textSecondary(context) : Colors.white,
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ],
                  ),
                ).animate().fadeIn(delay: 800.ms),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPrayerStatus(String name, bool isDone) {
    return Column(
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: isDone ? Colors.green[700] : Colors.grey[800],
            shape: BoxShape.circle,
            border: Border.all(
              color: isDone ? Colors.green.shade400 : Colors.grey.shade600,
              width: 1.5,
            ),
          ),
          child: Center(
            child: Icon(
              isDone ? Icons.check : Icons.access_time,
              color: isDone ? Colors.white : AppThemeColors.textHint(context),
              size: 14,
            ),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          name,
          style: TextStyle(
            color: isDone
                ? Colors.green[700]
                : AppThemeColors.textHint(context),
            fontSize: 10,
            fontWeight: isDone ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ],
    );
  }

  void _showLoggingDialog(BuildContext context, String type) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.85,
        decoration: BoxDecoration(
          color: AppThemeColors.surface(context),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.5),
              blurRadius: 20,
              offset: const Offset(0, -5),
            ),
          ],
        ),
        child: LoggingWidget(type: type),
      ),
    );
  }
}