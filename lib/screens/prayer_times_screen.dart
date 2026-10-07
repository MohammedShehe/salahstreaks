import 'package:flutter/material.dart';
import 'package:salahstreaks/utils/app_theme.dart';
import 'package:provider/provider.dart';
import 'package:salahstreaks/providers/app_provider.dart';
import 'package:salahstreaks/models/user_settings_model.dart';
import 'package:salahstreaks/services/reminder_service.dart';
import 'package:adhan_dart/adhan_dart.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart' as geocoding;
import 'package:intl/intl.dart';

enum _LoadStatus { loading, success, servicesDisabled, permissionDenied, error }

class PrayerTimesScreen extends StatefulWidget {
  const PrayerTimesScreen({super.key});

  @override
  State<PrayerTimesScreen> createState() => _PrayerTimesScreenState();
}

class _PrayerTimesScreenState extends State<PrayerTimesScreen> {
  PrayerTimes? _prayerTimes;
  // adhan_dart returns UTC instants — we keep device-local copies for UI.
  DateTime? _fajrLocal;
  DateTime? _sunriseLocal;
  DateTime? _dhuhrLocal;
  DateTime? _asrLocal;
  DateTime? _maghribLocal;
  DateTime? _ishaLocal;
  _LoadStatus _status = _LoadStatus.loading;
  String _error = '';
  DateTime _currentTime = DateTime.now();
  Coordinates? _coordinates;
  String _city = '';
  bool _usingFallback = false;

  @override
  void initState() {
    super.initState();
    _loadPrayerTimes();
    _startTimer();
  }

  void _startTimer() {
    Future.doWhile(() async {
      await Future.delayed(const Duration(seconds: 1));
      if (mounted) setState(() => _currentTime = DateTime.now());
      return mounted;
    });
  }

  // ============ CALCULATION PARAMETERS FROM SETTINGS ============
  // Previously this screen hardcoded CalculationMethodParameters.egyptian()
  // no matter what the user picked in Settings. Now it actually maps
  // settings.calculationMethod / settings.madhab onto adhan_dart's params.
  //
  // NOTE: method-name spelling here follows adhan_dart's existing
  // convention seen elsewhere in this codebase (`.egyptian()`), which
  // mirrors the naming used by the other language ports of this library.
  // If your installed adhan_dart version uses different names, your IDE
  // will red-underline the exact line to fix -- the mapping/index logic
  // around it is what matters and won't need to change.
  CalculationParameters _calculationParamsFromSettings(UserSettings settings) {
    // adhan_dart >= 2.0: CalculationMethod is an enum. The static factory
    // methods that return CalculationParameters live on
    // CalculationMethodParameters (e.g. .egyptian(), .karachi(), ...).
    late final CalculationParameters params;
    try {
      switch (settings.calculationMethod) {
        case 0:
          params = CalculationMethodParameters.muslimWorldLeague();
          break;
        case 1:
          params = CalculationMethodParameters.northAmerica();
          break;
        case 2:
          params = CalculationMethodParameters.egyptian();
          break;
        case 3:
          params = CalculationMethodParameters.ummAlQura();
          break;
        case 4:
          params = CalculationMethodParameters.karachi();
          break;
        case 5:
          params = CalculationMethodParameters.tehran();
          break;
        default:
          params = CalculationMethodParameters.muslimWorldLeague();
      }
    } catch (_) {
      // Safe fallback if a method name above doesn't match the installed
      // package version, so the screen still renders something correct
      // for the coordinates instead of crashing.
      params = CalculationMethodParameters.egyptian();
    }

    try {
      params.madhab = settings.madhab == 1 ? Madhab.hanafi : Madhab.shafi;
    } catch (_) {
      // Ignore if the Madhab API differs; Asr uses the package default.
    }

    return params;
  }

  // ============ LOCATION RESOLUTION ============

  Future<void> _loadPrayerTimes() async {
    setState(() {
      _status = _LoadStatus.loading;
      _error = '';
      _usingFallback = false;
    });

    final provider = Provider.of<AppProvider>(context, listen: false);
    final settings = provider.settings;

    Coordinates? coords;
    String cityName = '';

    // 1) Try live GPS first.
    try {
      coords = await _resolveFromGps();
      if (coords != null) {
        try {
          final placemarks = await geocoding.placemarkFromCoordinates(
            coords.latitude,
            coords.longitude,
          );
          if (placemarks.isNotEmpty) {
            cityName = placemarks.first.locality ??
                placemarks.first.administrativeArea ??
                placemarks.first.country ??
                'Your Location';
          }
        } catch (_) {
          cityName = 'Your Location';
        }

        // Persist so the app has a good fallback next time GPS/permission
        // isn't available, and so other screens could reuse it later.
        settings.latitude = coords.latitude;
        settings.longitude = coords.longitude;
        settings.city = cityName;
        await provider.updateSettings(settings);
        // Rebuild prayer-reminder schedules with the newly saved coordinates.
        await ReminderService().applySettings(settings, requestPermission: false);
      }
    } on _LocationServicesDisabledException {
      setState(() => _status = _LoadStatus.servicesDisabled);
      return;
    } on _LocationPermissionDeniedException {
      setState(() => _status = _LoadStatus.permissionDenied);
      return;
    } catch (e) {
      // GPS failed for some other reason (timeout, hardware, etc.) -- fall
      // through to the saved-settings fallback below instead of stopping.
      coords = null;
    }

    // 2) Fall back to a previously saved / manually-set location.
    if (coords == null &&
        settings.latitude != null &&
        settings.longitude != null) {
      coords = Coordinates(settings.latitude!, settings.longitude!);
      cityName = settings.city ?? 'Saved Location';
      _usingFallback = true;
    }

    // 3) Fall back to geocoding a manually typed city name (Settings ->
    // City), which the old version accepted but silently never used.
    if (coords == null && (settings.city ?? '').trim().isNotEmpty) {
      try {
        final locations =
            await geocoding.locationFromAddress(settings.city!.trim());
        if (locations.isNotEmpty) {
          coords = Coordinates(locations.first.latitude, locations.first.longitude);
          cityName = settings.city!.trim();
          _usingFallback = true;

          settings.latitude = coords.latitude;
          settings.longitude = coords.longitude;
          await provider.updateSettings(settings);
          // Rebuild prayer-reminder schedules with the newly saved coordinates.
          await ReminderService().applySettings(settings, requestPermission: false);
        }
      } catch (_) {
        // Couldn't geocode the typed city -- fall through to Makkah below,
        // but we'll make it obvious in the UI that this is a placeholder.
      }
    }

    // 4) Last resort -- Makkah, but clearly labelled as a placeholder so
    // it's never mistaken for a real reading again.
    if (coords == null) {
      coords = const Coordinates(21.4225, 39.8262);
      cityName = 'Makkah (no location set)';
      _usingFallback = true;
    }

    try {
      final params = _calculationParamsFromSettings(settings);
      // Use the device's local calendar day so solar calculations match
      // "today" for the user, not a shifted UTC date near midnight.
      final nowLocal = DateTime.now();
      final dateForCalc = DateTime(nowLocal.year, nowLocal.month, nowLocal.day);

      final times = PrayerTimes(
        coordinates: coords,
        date: dateForCalc,
        calculationParameters: params,
      );

      // adhan_dart builds times via DateTime.utc(...). Convert to the
      // device's local timezone so displayed hours match the phone clock
      // and "next prayer" comparisons against DateTime.now() are correct.
      DateTime? toLocal(DateTime? t) {
        if (t == null) return null;
        return t.isUtc ? t.toLocal() : t;
      }

      setState(() {
        _coordinates = coords;
        _city = cityName;
        _prayerTimes = times;
        _fajrLocal = toLocal(times.fajr);
        _sunriseLocal = toLocal(times.sunrise);
        _dhuhrLocal = toLocal(times.dhuhr);
        _asrLocal = toLocal(times.asr);
        _maghribLocal = toLocal(times.maghrib);
        _ishaLocal = toLocal(times.isha);
        _currentTime = DateTime.now();
        _status = _LoadStatus.success;
      });
    } catch (e) {
      setState(() {
        _error = 'Could not calculate prayer times: $e';
        _status = _LoadStatus.error;
      });
    }
  }

  Future<Coordinates?> _resolveFromGps() async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      throw _LocationServicesDisabledException();
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      throw _LocationPermissionDeniedException();
    }

    final position = await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high,
      timeLimit: const Duration(seconds: 12),
    );

    return Coordinates(position.latitude, position.longitude);
  }

  String _formatTime(DateTime? time) {
    if (time == null) return '--:--';
    // Always format in local wall-clock time.
    final local = time.isUtc ? time.toLocal() : time;
    return DateFormat('h:mm a').format(local);
  }

  Duration _getTimeUntil(DateTime time) {
    final local = time.isUtc ? time.toLocal() : time;
    return local.difference(DateTime.now());
  }

  /// Returns the next upcoming prayer (name + time). When all of today's
  /// prayers have passed, falls back to tomorrow's Fajr.
  ({String name, DateTime time, bool isTomorrow}) _getNextPrayerInfo() {
    final times = <String, DateTime?>{
      'Fajr': _fajrLocal,
      'Sunrise': _sunriseLocal,
      'Dhuhr': _dhuhrLocal,
      'Asr': _asrLocal,
      'Maghrib': _maghribLocal,
      'Isha': _ishaLocal,
    };

    final now = DateTime.now();
    String? nextName;
    DateTime? nextTime;

    for (final entry in times.entries) {
      final value = entry.value;
      if (value == null) continue;
      if (value.isAfter(now)) {
        if (nextTime == null || value.isBefore(nextTime)) {
          nextTime = value;
          nextName = entry.key;
        }
      }
    }

    if (nextName != null && nextTime != null) {
      return (name: nextName, time: nextTime, isTomorrow: false);
    }

    // All of today's prayers have passed — next is Fajr tomorrow.
    final fajr = _fajrLocal ?? now.add(const Duration(hours: 8));
    final tomorrowFajr = DateTime(
      now.year,
      now.month,
      now.day,
      fajr.hour,
      fajr.minute,
    ).add(const Duration(days: 1));
    return (name: 'Fajr', time: tomorrowFajr, isTomorrow: true);
  }

  String _formatCountdown(Duration d) {
    if (d.isNegative) return '0m';
    final hours = d.inHours;
    final minutes = d.inMinutes.remainder(60);
    final seconds = d.inSeconds.remainder(60);
    if (hours > 0) {
      return '${hours}h ${minutes.toString().padLeft(2, '0')}m';
    }
    if (minutes > 0) {
      return '${minutes}m ${seconds.toString().padLeft(2, '0')}s';
    }
    return '${seconds}s';
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
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    IconButton(
                      onPressed: () => Navigator.of(context).maybePop(),
                      icon: Icon(
                        Icons.arrow_back_ios_new_rounded,
                        size: 18,
                        color: AppThemeColors.icon(context),
                      ),
                      tooltip: 'Back',
                    ),
                    Expanded(
                      child: Text(
                        'Prayer Times',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                          color: AppThemeColors.textPrimary(context),
                          letterSpacing: 0.2,
                        ),
                      ),
                    ),
                    Material(
                      color: AppThemeColors.panelFill(context, 0.25),
                      borderRadius: BorderRadius.circular(12),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(12),
                        onTap: _loadPrayerTimes,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.refresh_rounded,
                                size: 16,
                                color: Colors.green[400],
                              ),
                              const SizedBox(width: 6),
                              Text(
                                'Refresh',
                                style: TextStyle(
                                  color: Colors.green[400],
                                  fontWeight: FontWeight.w600,
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Row(
                    children: [
                      Icon(
                        _usingFallback
                            ? Icons.location_off_rounded
                            : Icons.location_on_rounded,
                        color: _usingFallback
                            ? Colors.orange[300]
                            : Colors.green[400],
                        size: 16,
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          _city.isNotEmpty ? _city : 'Loading location...',
                          style: TextStyle(
                            fontSize: 13,
                            color: _usingFallback
                                ? Colors.orange[300]
                                : AppThemeColors.textSecondary(context),
                          ),
                        ),
                      ),
                      Text(
                        DateFormat('EEE, d MMM').format(_currentTime),
                        style: TextStyle(
                          fontSize: 12,
                          color: AppThemeColors.textHint(context),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Expanded(child: _buildBody()),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBody() {
    switch (_status) {
      case _LoadStatus.loading:
        return const Center(child: CircularProgressIndicator());

      case _LoadStatus.servicesDisabled:
        return _buildIssueState(
          icon: Icons.location_disabled,
          message: 'Location services are turned off on your device.',
          actionLabel: 'Open Location Settings',
          onAction: () async {
            await Geolocator.openLocationSettings();
            _loadPrayerTimes();
          },
        );

      case _LoadStatus.permissionDenied:
        return _buildIssueState(
          icon: Icons.location_disabled,
          message:
              'SalahStreaks needs location permission to show accurate prayer '
              'times for where you are. You can grant it in app settings, or '
              'set a city manually in the app\'s Settings screen.',
          actionLabel: 'Open App Settings',
          onAction: () async {
            await Geolocator.openAppSettings();
            _loadPrayerTimes();
          },
        );

      case _LoadStatus.error:
        return _buildIssueState(
          icon: Icons.error_outline,
          message: _error,
          actionLabel: 'Retry',
          onAction: _loadPrayerTimes,
        );

      case _LoadStatus.success:
        return _buildPrayerTimesView();
    }
  }

  Widget _buildIssueState({
    required IconData icon,
    required String message,
    required String actionLabel,
    required VoidCallback onAction,
  }) {
    return Center(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 12),
        padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
        decoration: BoxDecoration(
          color: AppThemeColors.surface(context),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppThemeColors.cardBorder(context)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.18),
              blurRadius: 18,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: Colors.orange.withOpacity(0.15),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 32, color: Colors.orange[400]),
            ),
            const SizedBox(height: 18),
            Text(
              message,
              style: TextStyle(
                color: AppThemeColors.textSecondary(context),
                fontSize: 14,
                height: 1.45,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 22),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: onAction,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green[700],
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 0,
                ),
                child: Text(
                  actionLabel,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPrayerTimesView() {
    final next = _getNextPrayerInfo();
    final countdown = _getTimeUntil(next.time);

    return Column(
      children: [
        if (_usingFallback)
          Container(
            width: double.infinity,
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.orange.withOpacity(0.12),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.orange.withOpacity(0.35)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.info_outline_rounded,
                    size: 18, color: Colors.orange[300]),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Showing times for "$_city" — not live GPS. '
                    'Tap Refresh to retry, or set a city in Settings.',
                    style: TextStyle(
                      color: Colors.orange[200],
                      fontSize: 12,
                      height: 1.35,
                    ),
                  ),
                ),
              ],
            ),
          ),

        // ============ NEXT PRAYER HERO CARD ============
        // Layout is deliberately explicit so users never confuse
        // "current clock time" with "prayer start time".
        Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: AppThemeColors.isDark(context)
                  ? [
                      const Color(0xFF1B5E20).withOpacity(0.55),
                      const Color(0xFF0D3B1E).withOpacity(0.35),
                    ]
                  : [
                      Colors.green[100]!,
                      Colors.green[50]!,
                    ],
            ),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: Colors.green.withOpacity(
                AppThemeColors.isDark(context) ? 0.35 : 0.55,
              ),
              width: 1.2,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.green.withOpacity(0.15),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Status chip
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.green.withOpacity(0.22),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: Colors.green.withOpacity(0.4),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 7,
                          height: 7,
                          decoration: const BoxDecoration(
                            color: Color(0xFF66BB6A),
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          next.isTomorrow ? 'UP NEXT · TOMORROW' : 'UP NEXT',
                          style: TextStyle(
                            color: Colors.green[300],
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.8,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Spacer(),
                  Text(
                    'Now ${_formatTime(_currentTime)}',
                    style: TextStyle(
                      color: AppThemeColors.textHint(context),
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Prayer name — large and clear
              Text(
                next.name,
                style: TextStyle(
                  color: AppThemeColors.textPrimary(context),
                  fontSize: 32,
                  fontWeight: FontWeight.w800,
                  height: 1.1,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 6),

              // Explicit label so "at 5:42 PM" cannot be read as current time
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    'starts at',
                    style: TextStyle(
                      color: AppThemeColors.textSecondary(context),
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    _formatTime(next.time),
                    style: TextStyle(
                      color: Colors.green[300],
                      fontSize: 26,
                      fontWeight: FontWeight.w700,
                      height: 1.1,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Countdown bar
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: AppThemeColors.isDark(context)
                      ? Colors.black.withOpacity(0.28)
                      : Colors.white.withOpacity(0.65),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.timer_outlined,
                      size: 18,
                      color: Colors.green[400],
                    ),
                    const SizedBox(width: 10),
                    Text(
                      'Time remaining',
                      style: TextStyle(
                        color: AppThemeColors.textSecondary(context),
                        fontSize: 13,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      _formatCountdown(countdown),
                      style: TextStyle(
                        color: AppThemeColors.textPrimary(context),
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 16),

        // ============ FULL DAY LIST ============
        Expanded(
          child: Container(
            padding: const EdgeInsets.fromLTRB(12, 14, 12, 8),
            decoration: BoxDecoration(
              color: AppThemeColors.surface(context).withOpacity(
                AppThemeColors.isDark(context) ? 0.55 : 0.9,
              ),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppThemeColors.cardBorder(context)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(8, 0, 8, 10),
                  child: Text(
                    'Today\'s schedule',
                    style: TextStyle(
                      color: AppThemeColors.textSecondary(context),
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.4,
                    ),
                  ),
                ),
                Expanded(
                  child: ListView(
                    physics: const BouncingScrollPhysics(),
                    children: [
                      _buildPrayerTimeRow('Fajr', _fajrLocal, next.name),
                      _buildPrayerTimeRow('Sunrise', _sunriseLocal, next.name),
                      _buildPrayerTimeRow('Dhuhr', _dhuhrLocal, next.name),
                      _buildPrayerTimeRow('Asr', _asrLocal, next.name),
                      _buildPrayerTimeRow('Maghrib', _maghribLocal, next.name),
                      _buildPrayerTimeRow('Isha', _ishaLocal, next.name),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPrayerTimeRow(
    String name,
    DateTime? time,
    String nextPrayerName,
  ) {
    if (time == null) {
      return _prayerRowShell(
        isHighlighted: false,
        isPast: false,
        child: Row(
          children: [
            _statusDot(Colors.grey[600]!),
            const SizedBox(width: 12),
            Text(
              name,
              style: TextStyle(color: AppThemeColors.textHint(context)),
            ),
            const Spacer(),
            Text(
              '--:--',
              style: TextStyle(color: AppThemeColors.textHint(context)),
            ),
          ],
        ),
      );
    }

    final isPast = !time.isAfter(_currentTime);
    final isNext = name == nextPrayerName && !isPast;

    return _prayerRowShell(
      isHighlighted: isNext,
      isPast: isPast,
      child: Row(
        children: [
          _statusDot(
            isNext
                ? const Color(0xFF66BB6A)
                : isPast
                    ? Colors.grey[600]!
                    : Colors.green[700]!,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      name,
                      style: TextStyle(
                        color: isNext
                            ? AppThemeColors.textPrimary(context)
                            : isPast
                                ? AppThemeColors.textHint(context)
                                : AppThemeColors.textPrimary(context),
                        fontWeight:
                            isNext ? FontWeight.w700 : FontWeight.w500,
                        fontSize: 15,
                      ),
                    ),
                    if (isNext) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 7,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.green.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          'NEXT',
                          style: TextStyle(
                            color: Colors.green[300],
                            fontSize: 9,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.6,
                          ),
                        ),
                      ),
                    ],
                    if (isPast) ...[
                      const SizedBox(width: 8),
                      Text(
                        'passed',
                        style: TextStyle(
                          color: AppThemeColors.textHint(context),
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
          Text(
            _formatTime(time),
            style: TextStyle(
              color: isNext
                  ? Colors.green[300]
                  : isPast
                      ? AppThemeColors.textHint(context)
                      : AppThemeColors.textPrimary(context),
              fontWeight: isNext ? FontWeight.w700 : FontWeight.w500,
              fontSize: 15,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
          if (isNext) ...[
            const SizedBox(width: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.green.withOpacity(0.18),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                _formatCountdown(_getTimeUntil(time)),
                style: TextStyle(
                  color: Colors.green[300],
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _prayerRowShell({
    required bool isHighlighted,
    required bool isPast,
    required Widget child,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
      decoration: BoxDecoration(
        color: isHighlighted
            ? Colors.green.withOpacity(
                AppThemeColors.isDark(context) ? 0.14 : 0.12,
              )
            : Colors.transparent,
        borderRadius: BorderRadius.circular(14),
        border: isHighlighted
            ? Border.all(color: Colors.green.withOpacity(0.35))
            : null,
      ),
      child: Opacity(
        opacity: isPast && !isHighlighted ? 0.55 : 1,
        child: child,
      ),
    );
  }

  Widget _statusDot(Color color) {
    return Container(
      width: 9,
      height: 9,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.45),
            blurRadius: 4,
          ),
        ],
      ),
    );
  }
}

class _LocationServicesDisabledException implements Exception {}

class _LocationPermissionDeniedException implements Exception {}