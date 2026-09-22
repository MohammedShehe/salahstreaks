import 'package:flutter/material.dart';
import 'package:salahstreaks/utils/app_theme.dart';
import 'package:provider/provider.dart';
import 'package:salahstreaks/providers/app_provider.dart';
import 'package:salahstreaks/screens/splash_screen.dart';
import 'package:salahstreaks/screens/home_screen.dart';
import 'package:salahstreaks/screens/graphs_screen.dart';
import 'package:salahstreaks/screens/history_screen.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:salahstreaks/services/reminder_service.dart';
import 'package:salahstreaks/services/storage_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // NOTE: no manual sqflite factory setup needed here — on Android/iOS
  // sqflite initializes itself lazily on first openDatabase() call inside
  // StorageService. If you ever need to run this on web/desktop, you'd
  // initialize sqflite_common_ffi (or _ffi_web) here instead.

  // Local device notifications only — no backend/Firebase is required.
  // Load the saved switches before scheduling so disabled reminders never get
  // recreated during app startup.
  final reminderService = ReminderService();
  await reminderService.initialize();
  final savedSettings = await StorageService().loadSettings();
  try {
    await reminderService.ensureInitialPermissionsAndSchedule(savedSettings);
  } catch (e) {
    debugPrint('Could not schedule local reminders: $e');
  }

  runApp(
    ChangeNotifierProvider(
      create: (_) => AppProvider(),
      child: SalahStreaksApp(reminderService: reminderService),
    ),
  );
}

class SalahStreaksApp extends StatelessWidget {
  final ReminderService reminderService;

  const SalahStreaksApp({super.key, required this.reminderService});

  // ============ THEMES ============
  // Previously there was only ever one ThemeData (dark), applied
  // unconditionally, so the Dark Mode switch in Settings saved a value
  // that nothing read. Now we define both and pick between them below
  // based on settings.darkMode.

  static final ThemeData _darkTheme = ThemeData(
    brightness: Brightness.dark,
    primaryColor: const Color(0xFF2E7D32),
    colorScheme: ColorScheme.fromSeed(
      seedColor: const Color(0xFF2E7D32),
      brightness: Brightness.dark,
    ),
    useMaterial3: true,
    fontFamily: GoogleFonts.poppins().fontFamily,
    scaffoldBackgroundColor: const Color(0xFF0A0E1A),
    appBarTheme: const AppBarTheme(
      backgroundColor: Color(0xFF0A0E1A),
      elevation: 0,
      centerTitle: true,
    ),
    cardColor: const Color(0xFF1A1F2E),
    dialogTheme: const DialogThemeData(
      backgroundColor: Color(0xFF1A1F2E),
    ),
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: Color(0xFF1A1F2E),
    ),
    dividerColor: const Color(0xFF2A3040),
  );

  static final ThemeData _lightTheme = ThemeData(
    brightness: Brightness.light,
    primaryColor: const Color(0xFF2E7D32),
    colorScheme: ColorScheme.fromSeed(
      seedColor: const Color(0xFF2E7D32),
      brightness: Brightness.light,
    ),
    useMaterial3: true,
    fontFamily: GoogleFonts.poppins().fontFamily,
    scaffoldBackgroundColor: const Color(0xFFF3F6F3),
    appBarTheme: const AppBarTheme(
      backgroundColor: Color(0xFFF3F6F3),
      elevation: 0,
      centerTitle: true,
      foregroundColor: Colors.black87,
    ),
    cardColor: Colors.white,
    dialogTheme: const DialogThemeData(
      backgroundColor: Colors.white,
    ),
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: Colors.white,
    ),
    dividerColor: const Color(0xFFD0D8D0),
  );

  @override
  Widget build(BuildContext context) {
    // Consumer so that flipping the Dark Mode switch anywhere in the app
    // (Settings screen) rebuilds MaterialApp with the new themeMode
    // immediately, without needing a hot restart.
    return Consumer<AppProvider>(
      builder: (context, provider, _) {
        return MaterialApp(
          title: 'SalahStreaks',
          debugShowCheckedModeBanner: false,
          theme: _lightTheme,
          darkTheme: _darkTheme,
          themeMode:
              provider.settings.darkMode ? ThemeMode.dark : ThemeMode.light,
          // Flutter splash (logo animation). Native launch window uses the
          // same background color so there is no separate OS splash flash.
          initialRoute: '/splash',
          routes: {
            '/splash': (context) => const SplashScreen(),
            '/main': (context) => MainScreen(reminderService: reminderService),
          },
        );
      },
    );
  }
}

class MainScreen extends StatefulWidget {
  final ReminderService reminderService;

  const MainScreen({super.key, required this.reminderService});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> with WidgetsBindingObserver {
  int _selectedIndex = 0;
  late final PageController _pageController;

  final List<Widget> _screens = const [
    HomeScreen(),
    GraphsScreen(),
    HistoryScreen(),
  ];

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: 0);
    WidgetsBinding.instance.addObserver(this);

    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) _checkReminders();
    });

    Future.doWhile(() async {
      await Future.delayed(const Duration(minutes: 1));
      if (mounted) {
        _checkReminders();
      }
      return mounted;
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _pageController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _checkReminders();
    }
  }

  void _checkReminders() {
    if (!mounted) return;

    try {
      final dueReminders = widget.reminderService.checkDueReminders();
      for (final reminder in dueReminders) {
        if (mounted) {
          widget.reminderService.markReminderShown(reminder['key']!);
          widget.reminderService.showInAppReminder(
            context,
            reminder['title']!,
            reminder['body']!,
          );
        }
      }
    } catch (e) {
      // Silent fail
    }
  }

  void _onPageChanged(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  void _onBottomNavTap(int index) {
    _pageController.animateToPage(
      index,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: PageView(
        controller: _pageController,
        onPageChanged: _onPageChanged,
        physics: const BouncingScrollPhysics(),
        children: _screens,
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: AppThemeColors.bottomNavGradient(context),
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(
                Theme.of(context).brightness == Brightness.dark ? 0.3 : 0.08,
              ),
              blurRadius: 10,
              offset: const Offset(0, -5),
            ),
          ],
        ),
        child: BottomNavigationBar(
          currentIndex: _selectedIndex,
          onTap: _onBottomNavTap,
          backgroundColor: Colors.transparent,
          elevation: 0,
          selectedItemColor: AppThemeColors.bottomNavSelected(context),
          unselectedItemColor: AppThemeColors.bottomNavUnselected(context),
          selectedLabelStyle: TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 12,
          ),
          unselectedLabelStyle: TextStyle(
            fontSize: 11,
          ),
          type: BottomNavigationBarType.fixed,
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.home_rounded),
              activeIcon: Icon(Icons.home_filled),
              label: 'Home',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.bar_chart_rounded),
              activeIcon: Icon(Icons.bar_chart_outlined),
              label: 'Graphs',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.history_rounded),
              activeIcon: Icon(Icons.history_outlined),
              label: 'History',
            ),
          ],
        ),
      ),
    );
  }
}