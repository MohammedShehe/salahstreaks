import 'package:flutter/material.dart';
import 'package:salahstreaks/utils/app_theme.dart';
import 'package:provider/provider.dart';
import 'package:salahstreaks/providers/app_provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ProfileWidget extends StatefulWidget {
  const ProfileWidget({super.key});

  @override
  State<ProfileWidget> createState() => _ProfileWidgetState();
}

class _ProfileWidgetState extends State<ProfileWidget> {
  bool _showProfile = false;
  String? _profileImagePath;
  TextEditingController _nameController = TextEditingController();
  String _displayName = 'MO11';

  @override
  void initState() {
    super.initState();
    _loadProfileImage();
    _loadUserName();
  }

  Future<void> _loadProfileImage() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _profileImagePath = prefs.getString('profile_image_path');
    });
  }

  Future<void> _loadUserName() async {
    final prefs = await SharedPreferences.getInstance();
    final name = prefs.getString('user_name') ?? 'MO11';
    setState(() {
      _displayName = name;
      _nameController.text = name;
    });
  }

  Future<void> _saveUserName(String newName) async {
    if (newName.trim().isEmpty) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('user_name', newName.trim());
    setState(() {
      _displayName = newName.trim();
    });
  }

  Future<void> _pickImage() async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 200,
      maxHeight: 200,
      imageQuality: 80,
    );

    if (image != null) {
      final appDir = await getApplicationDocumentsDirectory();
      final ext = p.extension(image.path);
      final savedPath = p.join(
        appDir.path,
        'profile_picture$ext',
      );

      final savedFile = await File(image.path).copy(savedPath);

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('profile_image_path', savedFile.path);

      setState(() {
        _profileImagePath = savedFile.path;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Profile picture updated!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<AppProvider>(context);
    final totalPoints = provider.getTotalPoints();
    final totalStreak = provider.streaks.values.fold(0, (sum, value) => sum + value);

    return Stack(
      children: [
        GestureDetector(
          onTap: () => setState(() => _showProfile = true),
          child: Container(
            padding: const EdgeInsets.all(12),
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
              children: [
                // Profile Image
                Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Colors.green[700]!,
                        Colors.green[900]!,
                      ],
                    ),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: Colors.green[400]!,
                      width: 2,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: AppThemeColors.cardBorder(context),
                        blurRadius: 10,
                      ),
                    ],
                  ),
                  child: _profileImagePath != null && File(_profileImagePath!).existsSync()
                      ? ClipOval(
                          child: Image.file(
                            File(_profileImagePath!),
                            width: 50,
                            height: 50,
                            fit: BoxFit.cover,
                          ),
                        )
                      : ClipOval(
                          child: Image.asset(
                            'assets/images/app_logo.png',
                            width: 50,
                            height: 50,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) {
                              return const Icon(
                                Icons.person,
                                color: Colors.white,
                                size: 30,
                              );
                            },
                          ),
                        ),
                ),
                const SizedBox(width: 12),

                // Name and Points
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _displayName,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: AppThemeColors.textPrimary(context),
                        ),
                      ),
                      // ============ FIXED: points row no longer overflows ============
                      // Previously the Icon + Text here had no shrink protection,
                      // so a long display name (which eats into this Expanded's
                      // width) or a larger point total could push the row a few
                      // pixels past its bounds. Wrapping the Text in Flexible +
                      // ellipsis lets it truncate instead of overflowing.
                      Row(
                        children: [
                          const Icon(
                            Icons.star,
                            color: Colors.amber,
                            size: 14,
                          ),
                          const SizedBox(width: 4),
                          Flexible(
                            child: Text(
                              '${totalPoints.round()} pts',
                              overflow: TextOverflow.ellipsis,
                              maxLines: 1,
                              style: TextStyle(
                                fontSize: 12,
                                color: AppThemeColors.textSecondary(context),
                              ),
                            ),
                          ),
                        ],
                      ),
                      // =================================================================
                    ],
                  ),
                ),

                const SizedBox(width: 8),

                // Streak Badge with proper constraints
                Container(
                  constraints: BoxConstraints(
                    maxWidth: MediaQuery.of(context).size.width * 0.2,
                    minWidth: 30,
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.orange[900]!.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: Colors.orange[700]!.withOpacity(0.3),
                    ),
                  ),
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.local_fire_department,
                          color: Colors.orange,
                          size: 14,
                        ),
                        const SizedBox(width: 3),
                        Text(
                          '$totalStreak',
                          style: TextStyle(
                            color: AppThemeColors.textPrimary(context),
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        if (_showProfile)
          GestureDetector(
            onTap: () => setState(() => _showProfile = false),
            child: Container(
              color: Colors.black.withOpacity(0.7),
              child: Center(
                child: GestureDetector(
                  onTap: () {},
                  child: Container(
                    width: MediaQuery.of(context).size.width * 0.85,
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          const Color(0xFF1A2F1A),
                          const Color(0xFF0A1A0A),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(30),
                      border: Border.all(
                        color: AppThemeColors.cardBorder(context),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.green[900]!.withOpacity(0.5),
                          blurRadius: 30,
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        GestureDetector(
                          onTap: _pickImage,
                          child: Stack(
                            children: [
                              Container(
                                width: 80,
                                height: 80,
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [
                                      Colors.green[600]!,
                                      Colors.green[800]!,
                                    ],
                                  ),
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: Colors.green[400]!,
                                    width: 3,
                                  ),
                                ),
                                child: _profileImagePath != null && File(_profileImagePath!).existsSync()
                                    ? ClipOval(
                                        child: Image.file(
                                          File(_profileImagePath!),
                                          width: 80,
                                          height: 80,
                                          fit: BoxFit.cover,
                                        ),
                                      )
                                    : ClipOval(
                                        child: Image.asset(
                                          'assets/images/app_logo.png',
                                          width: 80,
                                          height: 80,
                                          fit: BoxFit.cover,
                                          errorBuilder: (context, error, stackTrace) {
                                            return const Icon(
                                              Icons.person,
                                              color: Colors.white,
                                              size: 40,
                                            );
                                          },
                                        ),
                                      ),
                              ),
                              Positioned(
                                bottom: 0,
                                right: 0,
                                child: Container(
                                  padding: const EdgeInsets.all(4),
                                  decoration: BoxDecoration(
                                    color: Colors.green[600],
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: Colors.white,
                                      width: 2,
                                    ),
                                  ),
                                  child: const Icon(
                                    Icons.camera_alt,
                                    color: Colors.white,
                                    size: 16,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Tap to change photo',
                          style: TextStyle(
                            color: AppThemeColors.textSecondary(context),
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: _nameController,
                                style: TextStyle(
                                  color: AppThemeColors.textPrimary(context),
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                ),
                                decoration: InputDecoration(
                                  hintText: 'Enter your name',
                                  hintStyle: TextStyle(
                                    color: AppThemeColors.textHint(context),
                                    fontSize: 20,
                                  ),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: BorderSide(
                                      color: Colors.green[700]!,
                                    ),
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: BorderSide(
                                      color: AppThemeColors.cardBorder(context),
                                    ),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: BorderSide(
                                      color: Colors.green[400]!,
                                      width: 2,
                                    ),
                                  ),
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 12,
                                  ),
                                ),
                                onSubmitted: (value) => _saveUserName(value),
                              ),
                            ),
                            const SizedBox(width: 8),
                            IconButton(
                              onPressed: () => _saveUserName(_nameController.text),
                              icon: const Icon(
                                Icons.save_rounded,
                                color: Colors.green,
                                size: 28,
                              ),
                              tooltip: 'Save name',
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: AppThemeColors.panelFillStrong(context),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Column(
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceAround,
                                children: [
                                  _buildStatItem(
                                    '🔥 $totalStreak',
                                    'Total Streaks',
                                  ),
                                  _buildStatItem(
                                    '⭐ ${totalPoints.round()}',
                                    'Points',
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              const Divider(color: Colors.green),
                              const SizedBox(height: 12),
                              Text(
                                '🌙 "The best of you are those who are best to their families."',
                                style: TextStyle(
                                  color: Colors.grey[300],
                                  fontSize: 14,
                                  fontStyle: FontStyle.italic,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: () => setState(() => _showProfile = false),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green[800],
                            padding: const EdgeInsets.symmetric(
                              horizontal: 40,
                              vertical: 12,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: Text(
                            'Close',
                            style: TextStyle(color: AppThemeColors.textPrimary(context)),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildStatItem(String value, String label) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: AppThemeColors.textPrimary(context),
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: AppThemeColors.textSecondary(context),
          ),
        ),
      ],
    );
  }
}