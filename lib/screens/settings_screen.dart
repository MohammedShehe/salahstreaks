import 'package:flutter/material.dart';
import 'package:salahstreaks/utils/app_theme.dart';
import 'package:provider/provider.dart';
import 'package:salahstreaks/providers/app_provider.dart';
import 'package:salahstreaks/models/user_settings_model.dart';
import 'package:salahstreaks/utils/constants.dart';
import 'package:salahstreaks/services/ai_bot_service.dart';
import 'package:salahstreaks/services/reminder_service.dart';
import 'package:file_picker/file_picker.dart';
import 'package:share_plus/share_plus.dart';
import 'package:geocoding/geocoding.dart' as geocoding;
import 'dart:io';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late UserSettings _settings;
  bool _isLoading = false;
  bool _isGeocodingCity = false;
  late TextEditingController _cityController;
  late TextEditingController _aiKeyController;
  late TextEditingController _aiBaseUrlController;
  late TextEditingController _aiModelController;
  bool _showAiKey = false;

  @override
  void initState() {
    super.initState();
    _settings = Provider.of<AppProvider>(context, listen: false).settings;
    _cityController = TextEditingController(text: _settings.city ?? '');
    _aiKeyController = TextEditingController(text: _settings.aiApiKey);
    _aiBaseUrlController = TextEditingController(text: _settings.aiBaseUrl);
    _aiModelController = TextEditingController(text: _settings.aiModel);
  }

  @override
  void dispose() {
    _cityController.dispose();
    _aiKeyController.dispose();
    _aiBaseUrlController.dispose();
    _aiModelController.dispose();
    super.dispose();
  }

  // ============ CITY GEOCODING ============
  // Previously typing a city here only saved the text — nothing ever
  // converted it to coordinates until (and unless) the Prayer Times screen
  // happened to fall through to its "geocode saved city" fallback branch.
  // Now submitting or tapping the locate button resolves it right away and
  // saves latitude/longitude along with the city name, so Prayer Times can
  // use it immediately on its very first load.
  Future<void> _geocodeCity(String cityInput) async {
    final trimmed = cityInput.trim();
    if (trimmed.isEmpty) return;

    setState(() => _isGeocodingCity = true);

    try {
      final locations = await geocoding.locationFromAddress(trimmed);

      if (locations.isNotEmpty) {
        _settings.city = trimmed;
        _settings.latitude = locations.first.latitude;
        _settings.longitude = locations.first.longitude;
        await _saveSettings();

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('📍 Location set for "$trimmed"'),
              backgroundColor: Colors.green,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                '⚠️ Couldn\'t find "$trimmed" — try adding a country, e.g. "Lahore, Pakistan"',
              ),
              backgroundColor: Colors.orange,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Could not look up that city: $e'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }

    if (mounted) setState(() => _isGeocodingCity = false);
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<AppProvider>(context);

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
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Settings',
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: AppThemeColors.textPrimary(context),
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Appearance
                      _buildSection(
                        title: 'Appearance',
                        children: [
                          _buildSwitchTile(
                            title: 'Dark Mode',
                            subtitle: 'Switch off for a light theme',
                            value: _settings.darkMode,
                            onChanged: (value) {
                              setState(() {
                                _settings.darkMode = value;
                                _saveSettings();
                              });
                            },
                          ),
                        ],
                      ),

                      const SizedBox(height: 16),

                      // Notifications
                      _buildSection(
                        title: 'Notifications',
                        children: [
                          _buildSwitchTile(
                            title: 'Enable Notifications',
                            value: _settings.notificationsEnabled,
                            onChanged: (value) {
                              setState(() {
                                _settings.notificationsEnabled = value;
                                _saveSettings();
                              });
                            },
                          ),
                          _buildSwitchTile(
                            title: 'Prayer Reminders',
                            value: _settings.prayerReminders,
                            onChanged: (value) {
                              setState(() {
                                _settings.prayerReminders = value;
                                _saveSettings();
                              });
                            },
                          ),
                          _buildSwitchTile(
                            title: 'Quran Verse Reminders',
                            value: _settings.quranReminders,
                            onChanged: (value) {
                              setState(() {
                                _settings.quranReminders = value;
                                _saveSettings();
                              });
                            },
                          ),
                          _buildSwitchTile(
                            title: 'Adhkar Reminders',
                            value: _settings.adhkarReminders,
                            onChanged: (value) {
                              setState(() {
                                _settings.adhkarReminders = value;
                                _saveSettings();
                              });
                            },
                          ),
                          _buildSwitchTile(
                            title: 'Sound',
                            value: _settings.notificationsSound,
                            onChanged: (value) {
                              setState(() {
                                _settings.notificationsSound = value;
                                _saveSettings();
                              });
                            },
                          ),
                          _buildSwitchTile(
                            title: 'Vibrate',
                            value: _settings.notificationsVibrate,
                            onChanged: (value) {
                              setState(() {
                                _settings.notificationsVibrate = value;
                                _saveSettings();
                              });
                            },
                          ),
                        ],
                      ),

                      const SizedBox(height: 16),

                      // Prayer Times
                      _buildSection(
                        title: 'Prayer Times',
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: TextField(
                                  controller: _cityController,
                                  style: TextStyle(color: AppThemeColors.textPrimary(context)),
                                  decoration: InputDecoration(
                                    labelText: 'City',
                                    labelStyle: TextStyle(color: AppThemeColors.textPrimary(context)),
                                    hintText: 'Enter your city',
                                    hintStyle: TextStyle(color: AppThemeColors.textHint(context)),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(8),
                                      borderSide: BorderSide(color: Colors.green[700]!),
                                    ),
                                    enabledBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(8),
                                      borderSide: BorderSide(
                                          color: AppThemeColors.cardBorder(context)),
                                    ),
                                    focusedBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(8),
                                      borderSide: BorderSide(color: Colors.green[400]!),
                                    ),
                                    contentPadding: const EdgeInsets.symmetric(
                                        horizontal: 12, vertical: 8),
                                  ),
                                  textInputAction: TextInputAction.done,
                                  onSubmitted: _geocodeCity,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Padding(
                                padding: const EdgeInsets.only(top: 4),
                                child: IconButton(
                                  onPressed: _isGeocodingCity
                                      ? null
                                      : () => _geocodeCity(_cityController.text),
                                  icon: _isGeocodingCity
                                      ? const SizedBox(
                                          width: 18,
                                          height: 18,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            color: Colors.green,
                                          ),
                                        )
                                      : const Icon(Icons.my_location, color: Colors.green),
                                  tooltip: 'Find coordinates for this city',
                                  style: IconButton.styleFrom(
                                    backgroundColor: AppThemeColors.panelFillStrong(context),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          if (_settings.latitude != null && _settings.longitude != null)
                            Padding(
                              padding: const EdgeInsets.only(top: 6, left: 4),
                              child: Text(
                                '📍 ${_settings.latitude!.toStringAsFixed(4)}, '
                                '${_settings.longitude!.toStringAsFixed(4)}',
                                style: TextStyle(color: AppThemeColors.textHint(context), fontSize: 11),
                              ),
                            ),
                          const SizedBox(height: 8),
                          _buildDropdown(
                            title: 'Calculation Method',
                            value: _settings.calculationMethod,
                            items: calculationMethods.entries.map((entry) {
                              return DropdownMenuItem(
                                value: entry.key,
                                child: Text(
                                  entry.value,
                                  style: TextStyle(color: AppThemeColors.textPrimary(context)),
                                ),
                              );
                            }).toList(),
                            onChanged: (value) {
                              if (value != null) {
                                setState(() {
                                  _settings.calculationMethod = value;
                                  _saveSettings();
                                });
                              }
                            },
                          ),
                          const SizedBox(height: 8),
                          _buildDropdown(
                            title: 'Madhab',
                            value: _settings.madhab,
                            items: [
                              DropdownMenuItem(value: 1, child: Text('Hanafi', style: TextStyle(color: AppThemeColors.textPrimary(context)))),
                              DropdownMenuItem(value: 2, child: Text('Shafi\'i', style: TextStyle(color: AppThemeColors.textPrimary(context)))),
                            ],
                            onChanged: (value) {
                              if (value != null) {
                                setState(() {
                                  _settings.madhab = value;
                                  _saveSettings();
                                });
                              }
                            },
                          ),
                        ],
                      ),

                      const SizedBox(height: 16),

                      // AI Bot — serverless, user-owned free API key
                      _buildSection(
                        title: 'AI Bot (serverless)',
                        children: [
                          Text(
                            'Uses your free API key only. Calls go from this device to the provider — no SalahStreaks server. Never share your key.',
                            style: TextStyle(
                              color: AppThemeColors.textHint(context),
                              fontSize: 12,
                            ),
                          ),
                          const SizedBox(height: 8),
                          _buildSwitchTile(
                            title: 'Enable AI Bot',
                            subtitle: 'Allow live answers when a key is saved',
                            value: _settings.aiBotEnabled,
                            onChanged: (value) {
                              setState(() {
                                _settings.aiBotEnabled = value;
                                _saveSettings();
                              });
                            },
                          ),
                          const SizedBox(height: 8),
                          DropdownButtonFormField<String>(
                            value: _settings.aiProvider,
                            dropdownColor: AppThemeColors.surface(context),
                            style: TextStyle(
                              color: AppThemeColors.textPrimary(context),
                            ),
                            decoration: InputDecoration(
                              labelText: 'Provider',
                              labelStyle: TextStyle(
                                color: AppThemeColors.textPrimary(context),
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 8,
                              ),
                            ),
                            items: AiProvider.values
                                .map(
                                  (p) => DropdownMenuItem(
                                    value: p.id,
                                    child: Text(
                                      p.label,
                                      style: TextStyle(
                                        color: AppThemeColors.textPrimary(context),
                                      ),
                                    ),
                                  ),
                                )
                                .toList(),
                            onChanged: (value) {
                              if (value == null) return;
                              setState(() {
                                _settings.aiProvider = value;
                                _saveSettings();
                              });
                            },
                          ),
                          const SizedBox(height: 12),
                          TextField(
                            controller: _aiKeyController,
                            obscureText: !_showAiKey,
                            style: TextStyle(
                              color: AppThemeColors.textPrimary(context),
                            ),
                            decoration: InputDecoration(
                              labelText: 'API key (stored on device only)',
                              labelStyle: TextStyle(
                                color: AppThemeColors.textPrimary(context),
                              ),
                              hintText: 'Paste free-tier key here',
                              hintStyle: TextStyle(
                                color: AppThemeColors.textHint(context),
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                              suffixIcon: IconButton(
                                icon: Icon(
                                  _showAiKey
                                      ? Icons.visibility_off
                                      : Icons.visibility,
                                  color: AppThemeColors.iconMuted(context),
                                ),
                                onPressed: () =>
                                    setState(() => _showAiKey = !_showAiKey),
                              ),
                            ),
                            onChanged: (v) {
                              _settings.aiApiKey = v;
                            },
                            onEditingComplete: () {
                              _settings.aiApiKey = _aiKeyController.text.trim();
                              _saveSettings();
                              FocusScope.of(context).unfocus();
                            },
                          ),
                          const SizedBox(height: 8),
                          if (_settings.aiProvider == 'openai_compatible') ...[
                            TextField(
                              controller: _aiBaseUrlController,
                              style: TextStyle(
                                color: AppThemeColors.textPrimary(context),
                              ),
                              decoration: InputDecoration(
                                labelText: 'Base URL (OpenAI-compatible)',
                                labelStyle: TextStyle(
                                  color: AppThemeColors.textPrimary(context),
                                ),
                                hintText: 'https://api.example.com/v1',
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                              onChanged: (v) => _settings.aiBaseUrl = v,
                              onEditingComplete: () {
                                _settings.aiBaseUrl =
                                    _aiBaseUrlController.text.trim();
                                _saveSettings();
                              },
                            ),
                            const SizedBox(height: 8),
                          ],
                          TextField(
                            controller: _aiModelController,
                            style: TextStyle(
                              color: AppThemeColors.textPrimary(context),
                            ),
                            decoration: InputDecoration(
                              labelText: 'Model (optional override)',
                              labelStyle: TextStyle(
                                color: AppThemeColors.textPrimary(context),
                              ),
                              hintText: 'Leave empty for provider default',
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            onChanged: (v) => _settings.aiModel = v,
                            onEditingComplete: () {
                              _settings.aiModel = _aiModelController.text.trim();
                              _saveSettings();
                            },
                          ),
                          const SizedBox(height: 8),
                          Align(
                            alignment: Alignment.centerRight,
                            child: TextButton.icon(
                              onPressed: () {
                                _settings.aiApiKey =
                                    _aiKeyController.text.trim();
                                _settings.aiBaseUrl =
                                    _aiBaseUrlController.text.trim();
                                _settings.aiModel =
                                    _aiModelController.text.trim();
                                _saveSettings();
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('✅ AI Bot settings saved on device'),
                                    backgroundColor: Colors.green,
                                    behavior: SnackBarBehavior.floating,
                                  ),
                                );
                              },
                              icon: const Icon(Icons.save, color: Colors.green),
                              label: const Text(
                                'Save AI settings',
                                style: TextStyle(color: Colors.green),
                              ),
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 16),

                      // Data Management
                      _buildSection(
                        title: 'Data Management',
                        children: [
                          _buildSwitchTile(
                            title: 'Auto Backup',
                            subtitle: 'Saves a local backup automatically once a day',
                            value: _settings.backupAuto,
                            onChanged: (value) {
                              setState(() {
                                _settings.backupAuto = value;
                                _saveSettings();
                              });
                              if (value) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('✅ Auto backup enabled — first backup runs shortly'),
                                    backgroundColor: Colors.green,
                                    behavior: SnackBarBehavior.floating,
                                  ),
                                );
                              }
                            },
                          ),
                          _buildActionTile(
                            title: 'Export Backup',
                            icon: Icons.backup,
                            onTap: _exportBackup,
                          ),
                          _buildActionTile(
                            title: 'Import Backup',
                            icon: Icons.restore,
                            onTap: _importBackup,
                          ),
                          _buildActionTile(
                            title: 'Clear All Data',
                            icon: Icons.delete_forever,
                            color: Colors.red,
                            onTap: _confirmClearData,
                          ),
                        ],
                      ),

                      const SizedBox(height: 16),

                      // About
                      _buildSection(
                        title: 'About',
                        children: [
                          ListTile(
                            leading: const Icon(Icons.info, color: Colors.green),
                            title: Text(
                              'Version 1.0.2',
                              style: TextStyle(color: AppThemeColors.textPrimary(context)),
                            ),
                            subtitle: Text(
                              'SalahStreaks - Track your Ibadat',
                              style: TextStyle(color: AppThemeColors.textSecondary(context)),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
        ),
      ),
    );
  }

  Widget _buildSection({required String title, required List<Widget> children}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppThemeColors.panelFill(context, 0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppThemeColors.cardBorder(context)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              color: AppThemeColors.textPrimary(context),
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          ...children,
        ],
      ),
    );
  }

  Widget _buildSwitchTile({
    required String title,
    required bool value,
    required Function(bool) onChanged,
    String? subtitle,
  }) {
    return SwitchListTile(
      title: Text(title, style: TextStyle(color: AppThemeColors.textPrimary(context))),
      subtitle: subtitle != null
          ? Text(subtitle, style: TextStyle(color: AppThemeColors.textHint(context), fontSize: 12))
          : null,
      value: value,
      onChanged: onChanged,
      activeColor: Colors.green,
      contentPadding: EdgeInsets.zero,
      dense: true,
    );
  }

  Widget _buildDropdown<T>({
    required String title,
    required T value,
    required List<DropdownMenuItem<T>> items,
    required Function(T?) onChanged,
  }) {
    return DropdownButtonFormField<T>(
      value: value,
      items: items,
      onChanged: onChanged,
      dropdownColor: AppThemeColors.surface(context),
      style: TextStyle(color: AppThemeColors.textPrimary(context)),
      decoration: InputDecoration(
        labelText: title,
        labelStyle: TextStyle(color: AppThemeColors.textPrimary(context)),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: Colors.green[700]!),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: AppThemeColors.cardBorder(context)),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      ),
    );
  }

  Widget _buildActionTile({
    required String title,
    required IconData icon,
    required VoidCallback onTap,
    Color? color,
  }) {
    return ListTile(
      leading: Icon(icon, color: color ?? Colors.green),
      title: Text(
        title,
        style: TextStyle(color: color ?? AppThemeColors.textPrimary(context)),
      ),
      trailing: Icon(Icons.chevron_right, color: AppThemeColors.iconMuted(context)),
      onTap: onTap,
      contentPadding: EdgeInsets.zero,
      dense: true,
    );
  }

  Future<void> _saveSettings() async {
    final provider = Provider.of<AppProvider>(context, listen: false);
    await provider.updateSettings(_settings);

    // Keep OS-level schedules in sync immediately whenever any notification
    // switch, sound, or vibration preference changes.
    final granted = await ReminderService().applySettings(_settings);
    if (!granted && mounted && _settings.notificationsEnabled) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Notifications are blocked by the device. Enable permission in system settings to receive reminders.',
          ),
          backgroundColor: Colors.orange,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _exportBackup() async {
    setState(() => _isLoading = true);
    try {
      final provider = Provider.of<AppProvider>(context, listen: false);
      final backup = await provider.exportBackup();

      final path = await FilePicker.platform.getDirectoryPath();
      if (path != null) {
        final file = File('$path/salahstreaks_backup_${DateTime.now().toIso8601String().split('T').first}.json');
        await file.writeAsString(backup);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('✅ Backup saved successfully!'),
              backgroundColor: Colors.green,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Error: $e'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
    setState(() => _isLoading = false);
  }

  Future<void> _importBackup() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['json'],
      );

      if (result != null && result.files.single.path != null) {
        setState(() => _isLoading = true);
        final file = File(result.files.single.path!);
        final content = await file.readAsString();

        final provider = Provider.of<AppProvider>(context, listen: false);
        await provider.importBackup(content);

        // Local UI state (city text field, etc.) needs to catch up with
        // whatever settings the import just restored.
        _settings = provider.settings;
        _cityController.text = _settings.city ?? '';

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('✅ Backup restored successfully!'),
              backgroundColor: Colors.green,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Error: $e'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
    setState(() => _isLoading = false);
  }

  void _confirmClearData() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppThemeColors.surface(context),
        title: Text(
          'Clear All Data?',
          style: TextStyle(color: AppThemeColors.textPrimary(context)),
        ),
        content: const Text(
          'This will permanently delete all your logs, streaks, and achievements. This action cannot be undone.',
          style: TextStyle(color: Colors.grey),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              setState(() => _isLoading = true);
              try {
                final provider = Provider.of<AppProvider>(context, listen: false);
                await provider.clearAllData();
                _settings = provider.settings;
                _cityController.text = _settings.city ?? '';
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('🗑️ All data cleared'),
                      backgroundColor: Colors.orange,
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('❌ Error: $e'),
                      backgroundColor: Colors.red,
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                }
              }
              setState(() => _isLoading = false);
            },
            child: const Text('Clear', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}