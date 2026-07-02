import 'dart:async';
import 'package:flutter/material.dart';
import 'package:smooth_page_indicator/smooth_page_indicator.dart';

class IslamicEvent {
  final String name;
  final DateTime date;
  final String description;
  final String icon;
  final bool isMajor;
  final String hijriDate;

  IslamicEvent({
    required this.name,
    required this.date,
    required this.description,
    required this.icon,
    this.isMajor = false,
    this.hijriDate = '',
  });

  bool get hasPassed => DateTime.now().isAfter(date);
  bool get isToday {
    final now = DateTime.now();
    return now.year == date.year && 
           now.month == date.month && 
           now.day == date.day;
  }

  String get daysUntil {
    final now = DateTime.now();
    final difference = date.difference(now).inDays;
    if (difference == 0) return 'Today';
    if (difference == 1) return 'Tomorrow';
    if (difference < 0) return 'Passed';
    return '$difference days';
  }
}

class EventsSlider extends StatefulWidget {
  const EventsSlider({super.key});

  @override
  State<EventsSlider> createState() => _EventsSliderState();
}

class _EventsSliderState extends State<EventsSlider> {
  final PageController _pageController = PageController();
  List<IslamicEvent> _events = [];
  int _currentPage = 0;
  Timer? _autoSlideTimer;

  @override
  void initState() {
    super.initState();
    _loadEvents();
  }

  @override
  void dispose() {
    _pageController.dispose();
    _autoSlideTimer?.cancel();
    super.dispose();
  }

  void _loadEvents() {
    _events = _getUpcomingEvents();
    if (_events.isNotEmpty) {
      _startAutoSlide();
    }
  }

  List<IslamicEvent> _getUpcomingEvents() {
    // All dates are for 2026
    final events = [
      IslamicEvent(
        name: 'Isra & Mi\'raj',
        date: DateTime(2026, 1, 16),
        description: 'Night journey of the Prophet ﷺ',
        icon: '🕌',
        isMajor: true,
        hijriDate: '27 Rajab 1447',
      ),
      IslamicEvent(
        name: 'Shab-e-Barat',
        date: DateTime(2026, 2, 3),
        description: 'Night of forgiveness',
        icon: '🌙',
        isMajor: true,
        hijriDate: '15 Sha\'ban 1447',
      ),
      IslamicEvent(
        name: 'Ramadan Start',
        date: DateTime(2026, 2, 18),
        description: 'First day of fasting',
        icon: '🌙',
        isMajor: true,
        hijriDate: '1 Ramadan 1447',
      ),
      IslamicEvent(
        name: 'Laylat al-Qadr',
        date: DateTime(2026, 3, 16),
        description: 'Night of Power - Better than 1000 months',
        icon: '✨',
        isMajor: true,
        hijriDate: '27 Ramadan 1447',
      ),
      IslamicEvent(
        name: 'Eid al-Fitr',
        date: DateTime(2026, 3, 20),
        description: 'Festival of Breaking the Fast',
        icon: '🎉',
        isMajor: true,
        hijriDate: '1 Shawwal 1447',
      ),
      IslamicEvent(
        name: 'Day of Arafah',
        date: DateTime(2026, 5, 26),
        description: 'Fasting recommended - expiates two years of sins',
        icon: '🤲',
        isMajor: true,
        hijriDate: '9 Dhul Hijjah 1447',
      ),
      IslamicEvent(
        name: 'Eid al-Adha',
        date: DateTime(2026, 5, 27),
        description: 'Festival of Sacrifice (3 days)',
        icon: '🐑',
        isMajor: true,
        hijriDate: '10 Dhul Hijjah 1447',
      ),
      IslamicEvent(
        name: 'Islamic New Year',
        date: DateTime(2026, 6, 16),
        description: 'Start of Hijri year 1448',
        icon: '🌙',
        isMajor: true,
        hijriDate: '1 Muharram 1448',
      ),
      IslamicEvent(
        name: 'Ashura',
        date: DateTime(2026, 6, 25),
        description: 'Fasting highly recommended',
        icon: '🤲',
        isMajor: true,
        hijriDate: '10 Muharram 1448',
      ),
      IslamicEvent(
        name: 'Mawlid al-Nabi',
        date: DateTime(2026, 8, 25),
        description: 'Birth of Prophet Muhammad ﷺ',
        icon: '🕌',
        isMajor: true,
        hijriDate: '12 Rabi al-Awwal 1448',
      ),
    ];

    // Return only upcoming events (not passed), sorted by date
    final upcomingEvents = events.where((event) => !event.hasPassed).toList();
    upcomingEvents.sort((a, b) => a.date.compareTo(b.date));
    return upcomingEvents;
  }

  void _startAutoSlide() {
    _autoSlideTimer?.cancel();
    _autoSlideTimer = Timer.periodic(const Duration(seconds: 5), (timer) {
      if (mounted && _events.isNotEmpty) {
        final nextPage = (_currentPage + 1) % _events.length;
        _pageController.animateToPage(
          nextPage,
          duration: const Duration(milliseconds: 500),
          curve: Curves.easeInOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_events.isEmpty) {
      return Container(
        height: 100,
        margin: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: Colors.grey[800]!.withOpacity(0.3),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: Colors.grey[700]!.withOpacity(0.3),
          ),
        ),
        child: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.event_busy,
                color: Colors.grey,
                size: 32,
              ),
              SizedBox(height: 8),
              Text(
                'No upcoming events',
                style: TextStyle(
                  color: Colors.grey,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Container(
      height: 150,
      margin: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF1B5E20), Color(0xFF2E7D32)],
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            spreadRadius: 2,
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Stack(
        children: [
          PageView.builder(
            controller: _pageController,
            itemCount: _events.length,
            onPageChanged: (index) {
              setState(() {
                _currentPage = index;
              });
            },
            itemBuilder: (context, index) {
              final event = _events[index];
              return _buildEventCard(event);
            },
          ),
          Positioned(
            bottom: 8,
            left: 0,
            right: 0,
            child: Center(
              child: SmoothPageIndicator(
                controller: _pageController,
                count: _events.length,
                effect: ExpandingDotsEffect(
                  dotHeight: 6,
                  dotWidth: 6,
                  spacing: 6,
                  expansionFactor: 2.5,
                  dotColor: Colors.white.withOpacity(0.4),
                  activeDotColor: Colors.white,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEventCard(IslamicEvent event) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Container(
            width: 55,
            height: 55,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Center(
              child: Text(
                event.icon,
                style: const TextStyle(fontSize: 30),
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        event.name,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: event.isToday
                            ? Colors.amber.withOpacity(0.3)
                            : Colors.white.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: event.isToday
                              ? Colors.amber
                              : Colors.white.withOpacity(0.2),
                        ),
                      ),
                      child: Text(
                        event.isToday ? '🌟 TODAY' : event.daysUntil,
                        style: TextStyle(
                          color: event.isToday ? Colors.amber : Colors.white70,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  event.description,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.8),
                    fontSize: 12,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 3),
                Row(
                  children: [
                    Text(
                      '📅 ${event.hijriDate}',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.5),
                        fontSize: 10,
                      ),
                    ),
                    const SizedBox(width: 8),
                    if (event.isMajor)
                      Text(
                        '⭐',
                        style: TextStyle(
                          color: Colors.amber.withOpacity(0.7),
                          fontSize: 12,
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}