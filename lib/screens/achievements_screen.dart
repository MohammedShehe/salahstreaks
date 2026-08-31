import 'package:flutter/material.dart';
import 'package:salahstreaks/utils/app_theme.dart';
import 'package:provider/provider.dart';
import 'package:salahstreaks/providers/app_provider.dart';
import 'package:salahstreaks/models/achievement_model.dart';

class AchievementsScreen extends StatefulWidget {
  const AchievementsScreen({super.key});

  @override
  State<AchievementsScreen> createState() => _AchievementsScreenState();
}

class _AchievementsScreenState extends State<AchievementsScreen> {
  String _selectedCategory = 'All';
  
  final List<String> categories = ['All', 'Salah', 'Quran', 'Sawm', 'Qiyyam', 'Sadaqat'];

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<AppProvider>(context);
    final achievements = provider.getAllAchievements();
    final unlockedCount = provider.getUnlockedAchievementCount();
    
    final filteredAchievements = _selectedCategory == 'All'
        ? achievements
        : achievements.where((a) => a.category == _selectedCategory).toList();

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
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '🏆 Achievements',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: AppThemeColors.textPrimary(context),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: AppThemeColors.panelFillStrong(context),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: AppThemeColors.cardBorder(context),
                        ),
                      ),
                      child: Text(
                        '$unlockedCount/${achievements.length}',
                        style: TextStyle(
                          color: AppThemeColors.textPrimary(context),
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                
                // Category filter
                SizedBox(
                  height: 40,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: categories.length,
                    itemBuilder: (context, index) {
                      final category = categories[index];
                      final isSelected = _selectedCategory == category;
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: GestureDetector(
                          onTap: () => setState(() => _selectedCategory = category),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: isSelected 
                                  ? Colors.green[800] 
                                  : Colors.grey[800]!.withOpacity(0.3),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: isSelected 
                                    ? Colors.green[600]! 
                                    : Colors.grey[600]!.withOpacity(0.3),
                              ),
                            ),
                            child: Text(
                              category,
                              style: TextStyle(
                                color: isSelected ? Colors.white : AppThemeColors.textSecondary(context),
                                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 16),
                
                Expanded(
                  child: filteredAchievements.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.emoji_events,
                                size: 80,
                                color: Colors.grey[600],
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'No achievements yet',
                                style: TextStyle(
                                  color: AppThemeColors.textSecondary(context),
                                  fontSize: 18,
                                ),
                              ),
                              Text(
                                'Start logging your ibadat to unlock!',
                                style: TextStyle(
                                  color: Colors.grey[600],
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                        )
                      : GridView.builder(
                          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            childAspectRatio: 0.9,
                            crossAxisSpacing: 12,
                            mainAxisSpacing: 12,
                          ),
                          itemCount: filteredAchievements.length,
                          itemBuilder: (context, index) {
                            final achievement = filteredAchievements[index];
                            return _buildAchievementCard(achievement);
                          },
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAchievementCard(Achievement achievement) {
    final isUnlocked = achievement.isUnlocked;
    
    return Container(
      decoration: BoxDecoration(
        gradient: isUnlocked
            ? LinearGradient(
                colors: AppThemeColors.cardGradient(context),
              )
            : LinearGradient(
                colors: [
                  Colors.grey[900]!.withOpacity(0.3),
                  Colors.grey[800]!.withOpacity(0.1),
                ],
              ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isUnlocked
              ? Colors.green[600]!.withOpacity(0.5)
              : Colors.grey[600]!.withOpacity(0.3),
        ),
      ),
      child: Stack(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Opacity(
                  opacity: isUnlocked ? 1.0 : 0.3,
                  child: Text(
                    achievement.icon,
                    style: TextStyle(
                      fontSize: 40,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  achievement.title,
                  style: TextStyle(
                    color: isUnlocked ? Colors.white : AppThemeColors.textHint(context),
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 4),
                Text(
                  achievement.description,
                  style: TextStyle(
                    color: isUnlocked ? Colors.grey[300] : Colors.grey[600],
                    fontSize: 11,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                if (isUnlocked)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: AppThemeColors.panelFillStrong(context),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Text(
                      '✅ Unlocked',
                      style: TextStyle(
                        color: Colors.green,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  )
                else
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.grey[800]!.withOpacity(0.3),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '🔒 Locked',
                      style: TextStyle(
                        color: AppThemeColors.textHint(context),
                        fontSize: 11,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          if (isUnlocked && achievement.unlockedAt != null)
            Positioned(
              top: 8,
              right: 8,
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: const BoxDecoration(
                  color: Colors.green,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.star,
                  color: AppThemeColors.textPrimary(context),
                  size: 14,
                ),
              ),
            ),
        ],
      ),
    );
  }
}