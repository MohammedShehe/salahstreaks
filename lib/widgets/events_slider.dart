import 'dart:async';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:salahstreaks/providers/app_provider.dart';
import 'package:salahstreaks/utils/app_theme.dart';
import 'package:salahstreaks/services/islamic_events_service.dart';
import 'package:smooth_page_indicator/smooth_page_indicator.dart';
import 'package:geolocator/geolocator.dart';

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

  bool get isToday {
    final now = DateTime.now();
    return now.year == date.year &&
        now.month == date.month &&
        now.day == date.day;
  }

  String get daysUntil {
    final today = DateTime.now();
    final start = DateTime(today.year, today.month, today.day);
    final eventDay = DateTime(date.year, date.month, date.day);
    final difference = eventDay.difference(start).inDays;
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
  bool _loading = true;

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

  Future<void> _loadEvents() async {
    final settings = Provider.of<AppProvider>(context, listen: false).settings;

    double? latitude = settings.latitude;
    double? longitude = settings.longitude;

    // Geolocator is not reliable on web — skip live GPS there.
    if (!kIsWeb) {
      try {
        final permission = await Geolocator.checkPermission();
        if (permission == LocationPermission.always ||
            permission == LocationPermission.whileInUse) {
          final position = await Geolocator.getCurrentPosition(
            desiredAccuracy: LocationAccuracy.low,
            timeLimit: const Duration(seconds: 5),
          );
          latitude = position.latitude;
          longitude = position.longitude;
        }
      } catch (_) {}
    }

    try {
      final service = IslamicEventsService();
      final data = await service.loadUpcoming(
        latitude: latitude,
        longitude: longitude,
        calculationMethod: settings.calculationMethod,
      );

      if (!mounted) return;
      setState(() {
        _events = data
            .map((event) => IslamicEvent(
                  name: event.name,
                  date: event.date,
                  description: event.description,
                  icon: event.icon,
                  isMajor: event.isMajor,
                  hijriDate: event.hijriDate,
                ))
            .toList();
        _loading = false;
      });

      if (_events.isNotEmpty) _startAutoSlide();
    } catch (e) {
      debugPrint('EventsSlider load failed: $e');
      if (mounted) setState(() => _loading = false);
    }
  }

  void _startAutoSlide() {
    _autoSlideTimer?.cancel();
    _autoSlideTimer = Timer.periodic(const Duration(seconds: 5), (timer) {
      if (mounted && _events.isNotEmpty && _pageController.hasClients) {
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
    // Always take full width of the parent Column so we never get a
    // pathological 30px-wide constraint from an intermediate flex.
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth.isFinite && constraints.maxWidth > 0
            ? constraints.maxWidth
            : MediaQuery.sizeOf(context).width;

        if (_loading) {
          return _shell(
            width: width,
            height: 120,
            child: const Center(
              child: SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          );
        }

        if (_events.isEmpty) {
          return _shell(
            width: width,
            height: 100,
            child: Center(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.event_busy,
                          color: Colors.grey[500], size: 28),
                      const SizedBox(height: 6),
                      Text(
                        'No upcoming events',
                        style: TextStyle(
                          color: Colors.grey[500],
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        }

        return _shell(
          width: width,
          height: 150,
          gradient: true,
          child: Stack(
            children: [
              PageView.builder(
                controller: _pageController,
                itemCount: _events.length,
                onPageChanged: (index) =>
                    setState(() => _currentPage = index),
                itemBuilder: (context, index) =>
                    _buildEventCard(_events[index], width),
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
      },
    );
  }

  Widget _shell({
    required double width,
    required double height,
    required Widget child,
    bool gradient = false,
  }) {
    return Container(
      width: width,
      height: height,
      margin: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        gradient: gradient
            ? const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF1B5E20), Color(0xFF2E7D32)],
              )
            : null,
        color: gradient ? null : Colors.grey[800]!.withOpacity(0.28),
        borderRadius: BorderRadius.circular(16),
        border: gradient
            ? null
            : Border.all(color: Colors.grey[700]!.withOpacity(0.3)),
        boxShadow: gradient
            ? [
                BoxShadow(
                  color: Colors.black.withOpacity(0.2),
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                ),
              ]
            : null,
      ),
      clipBehavior: Clip.antiAlias,
      child: child,
    );
  }

  Widget _buildEventCard(IslamicEvent event, double parentWidth) {
    final compact = parentWidth < 360;

    return Padding(
      padding: EdgeInsets.fromLTRB(
        compact ? 12 : 16,
        14,
        compact ? 12 : 16,
        28, // room for page indicator
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: compact ? 44 : 55,
            height: compact ? 44 : 55,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Center(
              child: Text(
                event.icon,
                style: TextStyle(fontSize: compact ? 24 : 30),
              ),
            ),
          ),
          SizedBox(width: compact ? 10 : 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        event.name,
                        style: TextStyle(
                          color: AppThemeColors.textPrimary(context),
                          fontSize: compact ? 13 : 15,
                          fontWeight: FontWeight.bold,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
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
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: event.isToday
                                ? Colors.amber
                                : Colors.white70,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  event.description,
                  style: TextStyle(
                    color:
                        AppThemeColors.textPrimary(context).withOpacity(0.8),
                    fontSize: compact ? 11 : 12,
                  ),
                  maxLines: compact ? 1 : 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 3),
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        '📅 ${event.hijriDate}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: AppThemeColors.textPrimary(context)
                              .withOpacity(0.5),
                          fontSize: 10,
                        ),
                      ),
                    ),
                    if (event.isMajor) ...[
                      const SizedBox(width: 4),
                      Text(
                        '⭐',
                        style: TextStyle(
                          color: Colors.amber.withOpacity(0.7),
                          fontSize: 12,
                        ),
                      ),
                    ],
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
