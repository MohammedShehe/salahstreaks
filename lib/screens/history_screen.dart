import 'package:flutter/material.dart';
import 'package:salahstreaks/utils/app_theme.dart';
import 'package:provider/provider.dart';
import 'package:salahstreaks/providers/app_provider.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:intl/intl.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  CalendarFormat _calendarFormat = CalendarFormat.month;
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;
  Map<DateTime, List> _events = {};

  @override
  void initState() {
    super.initState();
    _selectedDay = _focusedDay;
    _loadEvents();
  }

  void _loadEvents() {
    final provider = Provider.of<AppProvider>(context, listen: false);
    final logs = provider.logs;
    
    _events = {};
    for (final log in logs) {
      final date = DateTime(log.date.year, log.date.month, log.date.day);
      if (!_events.containsKey(date)) {
        _events[date] = [];
      }
      _events[date]!.add(log);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: AppThemeColors.pageGradientSimple(context),
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Text(
                  'History',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: AppThemeColors.textPrimary(context),
                  ),
                ),
                const SizedBox(height: 16),
                _buildCalendar(),
                const SizedBox(height: 16),
                Expanded(
                  child: _buildHistoryDetails(),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCalendar() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppThemeColors.panelFill(context, 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: AppThemeColors.cardBorder(context),
        ),
      ),
      child: TableCalendar(
        firstDay: DateTime.utc(2020, 1, 1),
        lastDay: DateTime.utc(2030, 12, 31),
        focusedDay: _focusedDay,
        selectedDayPredicate: (day) {
          return isSameDay(_selectedDay, day);
        },
        onDaySelected: (selectedDay, focusedDay) {
          setState(() {
            _selectedDay = selectedDay;
            _focusedDay = focusedDay;
          });
        },
        onFormatChanged: (format) {
          setState(() {
            _calendarFormat = format;
          });
        },
        calendarStyle: CalendarStyle(
          todayDecoration: BoxDecoration(
            color: AppThemeColors.panelFillStrong(context),
            shape: BoxShape.circle,
          ),
          selectedDecoration: BoxDecoration(
            color: Colors.green[700],
            shape: BoxShape.circle,
          ),
          weekendTextStyle: TextStyle(color: Colors.red),
          defaultTextStyle: TextStyle(color: AppThemeColors.textPrimary(context)),
          outsideTextStyle: TextStyle(color: AppThemeColors.textHint(context)),
          markerDecoration: BoxDecoration(
            color: Colors.green[400],
            shape: BoxShape.circle,
          ),
        ),
        headerStyle: HeaderStyle(
          titleTextStyle: TextStyle(
            color: AppThemeColors.textPrimary(context),
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
          leftChevronIcon: Icon(Icons.chevron_left, color: AppThemeColors.icon(context)),
          rightChevronIcon: Icon(Icons.chevron_right, color: AppThemeColors.icon(context)),
          formatButtonDecoration: BoxDecoration(
            color: AppThemeColors.panelFillStrong(context),
            borderRadius: BorderRadius.circular(8),
          ),
          formatButtonTextStyle: TextStyle(color: AppThemeColors.textPrimary(context)),
          formatButtonShowsNext: false,
        ),
        eventLoader: (day) {
          final date = DateTime(day.year, day.month, day.day);
          return _events[date] ?? [];
        },
      ),
    );
  }

  Widget _buildHistoryDetails() {
    if (_selectedDay == null) {
      return const Center(
        child: Text(
          'Select a date to view details',
          style: TextStyle(
            color: Colors.grey,
            fontSize: 16,
          ),
        ),
      );
    }

    final date = DateTime(
      _selectedDay!.year,
      _selectedDay!.month,
      _selectedDay!.day,
    );
    
    final dayEvents = _events[date] ?? [];
    
    if (dayEvents.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.history,
              size: 60,
              color: Colors.grey[600],
            ),
            const SizedBox(height: 16),
            Text(
              'No ibadat logged on ${DateFormat('dd MMM yyyy').format(date)}',
              style: TextStyle(
                color: AppThemeColors.textSecondary(context),
                fontSize: 16,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppThemeColors.panelFill(context, 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: AppThemeColors.cardBorder(context),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '📅 ${DateFormat('EEEE, d MMMM yyyy').format(date)}',
            style: TextStyle(
              color: AppThemeColors.textPrimary(context),
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: ListView.separated(
              itemCount: dayEvents.length,
              separatorBuilder: (_, __) => const Divider(
                color: Colors.green,
                height: 8,
              ),
              itemBuilder: (context, index) {
                final log = dayEvents[index];
                return _buildHistoryCard(log);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHistoryCard(log) {
    final icons = {
      'Salah': Icons.mosque_rounded,
      'Sawm': Icons.nightlight_round,
      'Qiyyam': Icons.nights_stay_rounded,
      'Quran': Icons.menu_book_rounded,
      'Sadaqat': Icons.favorite_rounded,
    };

    String details = '';
    switch (log.type) {
      case 'Salah':
        details = 'Prayed ${log.salahCount}/5 salah';
        break;
      case 'Sawm':
        details = '${log.sawmType} fasting';
        break;
      case 'Qiyyam':
        details = 'Tahajjud: ${log.rakahCount - (log.rakahCount % 2 == 0 ? 1 : 0)} rakah, Witr: ${log.rakahCount % 2 == 0 ? 1 : 0} rakah';
        break;
      case 'Quran':
        details = 'Recited ${log.versesCount} verses from ${log.surahName}';
        break;
      case 'Sadaqat':
        details = '${log.sadaqatType} sadaqah: ${log.note.isNotEmpty ? log.note : 'No note'}';
        break;
    }

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppThemeColors.panelFill(context, 0.2),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppThemeColors.cardBorder(context),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppThemeColors.panelFillStrong(context),
              shape: BoxShape.circle,
            ),
            child: Icon(
              icons[log.type],
              color: Colors.green[400],
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  log.type,
                  style: TextStyle(
                    color: AppThemeColors.textPrimary(context),
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  details,
                  style: TextStyle(
                    color: AppThemeColors.textSecondary(context),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          Icon(
            Icons.check_circle,
            color: Colors.green[400],
            size: 16,
          ),
        ],
      ),
    );
  }
}