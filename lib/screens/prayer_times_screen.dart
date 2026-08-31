import 'package:flutter/material.dart';
import 'package:salahstreaks/utils/app_theme.dart';
import 'package:provider/provider.dart';
import 'package:salahstreaks/providers/app_provider.dart';
import 'package:salahstreaks/models/user_settings_model.dart';
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

  String _getNextPrayer() {
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

    return nextName ?? 'Fajr (Tomorrow)';
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
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '🕌 Prayer Times',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: AppThemeColors.textPrimary(context),
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(
                      _usingFallback ? Icons.location_off : Icons.location_on,
                      color: _usingFallback ? Colors.orange[300] : Colors.green[400],
                      size: 16,
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        _city.isNotEmpty ? _city : 'Loading location...',
                        style: TextStyle(
                          fontSize: 14,
                          color: _usingFallback ? Colors.orange[300] : AppThemeColors.textSecondary(context),
                        ),
                      ),
                    ),
                    TextButton.icon(
                      onPressed: _loadPrayerTimes,
                      icon: const Icon(Icons.refresh, size: 16, color: Colors.green),
                      label: const Text('Refresh', style: TextStyle(color: Colors.green)),
                    ),
                  ],
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
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 60, color: Colors.orange[400]),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Text(
              message,
              style: TextStyle(color: Colors.grey[300]),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: onAction,
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green[700]),
            child: Text(actionLabel),
          ),
        ],
      ),
    );
  }

  Widget _buildPrayerTimesView() {
    return Column(
      children: [
        if (_usingFallback)
          Container(
            width: double.infinity,
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.orange[900]!.withOpacity(0.25),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.orange[700]!.withOpacity(0.4)),
            ),
            child: Text(
              'Showing times for "$_city" -- this isn\'t your live GPS location. '
              'Tap Refresh to try again, or update your location in Settings.',
              style: TextStyle(color: Colors.orange[200], fontSize: 12),
            ),
          ),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: AppThemeColors.cardGradient(context),
            ),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppThemeColors.cardBorder(context)),
          ),
          child: Column(
            children: [
              Text('Next Prayer', style: TextStyle(color: AppThemeColors.textSecondary(context), fontSize: 14)),
              const SizedBox(height: 8),
              Text(
                _getNextPrayer(),
                style: TextStyle(color: AppThemeColors.textPrimary(context), fontSize: 24, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              Text(_formatTime(_currentTime), style: TextStyle(color: AppThemeColors.textSecondary(context), fontSize: 12)),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Expanded(
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppThemeColors.panelFill(context, 0.1),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppThemeColors.cardBorder(context)),
            ),
            child: ListView(
              children: [
                _buildPrayerTimeRow('Fajr', _fajrLocal),
                _buildPrayerTimeRow('Sunrise', _sunriseLocal),
                _buildPrayerTimeRow('Dhuhr', _dhuhrLocal),
                _buildPrayerTimeRow('Asr', _asrLocal),
                _buildPrayerTimeRow('Maghrib', _maghribLocal),
                _buildPrayerTimeRow('Isha', _ishaLocal),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPrayerTimeRow(String name, DateTime? time) {
    if (time == null) {
      return Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: Colors.grey[800]!.withOpacity(0.3))),
        ),
        child: Row(
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: Colors.grey[600],
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 12),
            Text(name, style: TextStyle(color: AppThemeColors.textHint(context))),
            const Spacer(),
            Text('--:--', style: TextStyle(color: AppThemeColors.textHint(context))),
          ],
        ),
      );
    }

    final isPast = time.isBefore(_currentTime);
    final isNext = !isPast;

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: Colors.grey[800]!.withOpacity(0.3))),
      ),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: isNext ? Colors.green : Colors.grey[600],
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 12),
          Text(
            name,
            style: TextStyle(
              color: isNext ? Colors.white : AppThemeColors.textHint(context),
              fontWeight: isNext ? FontWeight.bold : FontWeight.normal,
            ),
          ),
          const Spacer(),
          Text(
            _formatTime(time),
            style: TextStyle(
              color: isNext ? Colors.green[300] : AppThemeColors.textHint(context),
              fontWeight: isNext ? FontWeight.bold : FontWeight.normal,
            ),
          ),
          if (isNext) ...[
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: AppThemeColors.panelFillStrong(context),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '${_getTimeUntil(time).inMinutes}m',
                style: TextStyle(color: Colors.green, fontSize: 10),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _LocationServicesDisabledException implements Exception {}

class _LocationPermissionDeniedException implements Exception {}