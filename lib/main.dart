import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:salahstreaks/providers/app_provider.dart';
import 'package:salahstreaks/screens/home_screen.dart';
import 'package:salahstreaks/screens/graphs_screen.dart';
import 'package:salahstreaks/screens/history_screen.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:salahstreaks/services/reminder_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize reminder service
  final reminderService = ReminderService();
  await reminderService.initialize();
  // Try to schedule native reminders, but don't fail if not available
  try {
    await reminderService.scheduleAllReminders();
  } catch (e) {
    print('Native reminders not available, using in-app only');
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

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SalahStreaks',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
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
      ),
      home: MainScreen(reminderService: reminderService),
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
    
    // Check reminders after 2 seconds
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) _checkReminders();
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
    final dueReminders = widget.reminderService.checkDueReminders();
    for (final reminder in dueReminders) {
      widget.reminderService.markReminderShown(reminder['key']!);
      widget.reminderService.showInAppReminder(
        context,
        reminder['title']!,
        reminder['body']!,
      );
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
            colors: [
              const Color(0xFF1A1F2E),
              const Color(0xFF0A0E1A),
            ],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.3),
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
          selectedItemColor: const Color(0xFF4CAF50),
          unselectedItemColor: Colors.grey[600],
          selectedLabelStyle: const TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 12,
          ),
          unselectedLabelStyle: const TextStyle(
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