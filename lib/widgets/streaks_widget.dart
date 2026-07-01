import 'package:flutter/material.dart';
import 'package:salahstreaks/utils/constants.dart';
import 'package:fl_chart/fl_chart.dart';

class StreaksWidget extends StatelessWidget {
  final Map<String, int> streaks;
  final Map<String, double> percentages;

  const StreaksWidget({
    super.key,
    required this.streaks,
    required this.percentages,
  });

  @override
  Widget build(BuildContext context) {
    final icons = {
      'Salah': Icons.mosque_rounded,
      'Sawm': Icons.nightlight_round,
      'Qiyyam': Icons.nights_stay_rounded,
      'Quran': Icons.menu_book_rounded,
      'Sadaqat': Icons.favorite_rounded,
    };

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            const Color(0xFF1B2A1B),
            const Color(0xFF0A1A0A),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Colors.green[700]!.withOpacity(0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.trending_up, color: Colors.green, size: 20),
              SizedBox(width: 8),
              Text(
                'Your Streaks',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ...ibadatTypes.map((type) {
            final streak = streaks[type] ?? 0;
            final percentage = percentages[type]?.clamp(0.0, 100.0) ?? 0.0;
            
            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.green[900]!.withOpacity(0.3),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: Colors.green[700]!.withOpacity(0.2),
                ),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      Icon(
                        icons[type],
                        color: Colors.green[400],
                        size: 24,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              type,
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
                              ),
                            ),
                            Text(
                              '🔥 $streak days',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.orange[300],
                              ),
                            ),
                          ],
                        ),
                      ),
                      Text(
                        '${percentage.toStringAsFixed(1)}%',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: percentage >= 80 ? Colors.green[400] : Colors.orange[400],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: LinearProgressIndicator(
                      value: percentage / 100,
                      minHeight: 6,
                      backgroundColor: Colors.grey[800],
                      valueColor: AlwaysStoppedAnimation<Color>(
                        percentage >= 80 ? Colors.green : Colors.orange,
                      ),
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
        ],
      ),
    );
  }
}