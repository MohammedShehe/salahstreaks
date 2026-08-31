import 'package:flutter/material.dart';
import 'package:salahstreaks/utils/app_theme.dart';
import 'package:provider/provider.dart';
import 'package:salahstreaks/providers/app_provider.dart';
import 'package:salahstreaks/utils/constants.dart';
import 'package:intl/intl.dart';

class AdhkarScreen extends StatefulWidget {
  const AdhkarScreen({super.key});

  @override
  State<AdhkarScreen> createState() => _AdhkarScreenState();
}

class _AdhkarScreenState extends State<AdhkarScreen> {
  String _selectedCategory = 'morning';

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<AppProvider>(context);
    final today = DateTime.now();
    final dateFormat = DateFormat('d MMMM yyyy');
    
    final adhkarList = _selectedCategory == 'morning' 
        ? morningAdhkar 
        : eveningAdhkar;

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
                  '📿 Daily Adhkar',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: AppThemeColors.textPrimary(context),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  dateFormat.format(today),
                  style: TextStyle(
                    fontSize: 14,
                    color: AppThemeColors.textSecondary(context),
                  ),
                ),
                const SizedBox(height: 16),
                
                // Category selector
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: AppThemeColors.panelFill(context, 0.2),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: AppThemeColors.cardBorder(context),
                    ),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: _buildCategoryChip('morning', '🌅 Morning'),
                      ),
                      Expanded(
                        child: _buildCategoryChip('evening', '🌆 Evening'),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                
                Expanded(
                  child: ListView.builder(
                    itemCount: adhkarList.length,
                    itemBuilder: (context, index) {
                      final adhkar = adhkarList[index];
                      final count = provider.getAdhkarCount(adhkar['id'], today);
                      final isCompleted = count >= (adhkar['count'] as int);
                      
                      return Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: isCompleted 
                              ? AppThemeColors.panelFillStrong(context)
                              : Colors.grey[800]!.withOpacity(0.3),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: isCompleted 
                                ? Colors.green[600]!.withOpacity(0.5)
                                : Colors.grey[600]!.withOpacity(0.3),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    adhkar['title'],
                                    style: TextStyle(
                                      color: AppThemeColors.textPrimary(context),
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                if (isCompleted)
                                  const Icon(
                                    Icons.check_circle,
                                    color: Colors.green,
                                    size: 24,
                                  )
                                else
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color: AppThemeColors.panelFillStrong(context),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Text(
                                      '${adhkar['count']}x',
                                      style: TextStyle(
                                        color: Colors.green[300],
                                        fontSize: 12,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              adhkar['arabic'],
                              style: TextStyle(
                                fontSize: 20,
                                color: const Color(0xFFC8E6C9),
                                fontFamily: 'Arabic',
                                height: 1.6,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              adhkar['translation'],
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey[300],
                              ),
                            ),
                            const SizedBox(height: 12),
                            
                            // Counter buttons
                            Row(
                              children: [
                                IconButton(
                                  onPressed: count > 0
                                      ? () => _updateAdhkar(provider, adhkar['id'], count - 1)
                                      : null,
                                  icon: const Icon(Icons.remove, color: Colors.white),
                                  style: IconButton.styleFrom(
                                    backgroundColor: Colors.grey[800],
                                  ),
                                ),
                                Container(
                                  width: 40,
                                  height: 40,
                                  decoration: BoxDecoration(
                                    color: AppThemeColors.panelFillStrong(context),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Center(
                                    child: Text(
                                      '$count/${adhkar['count']}',
                                      style: TextStyle(
                                        color: AppThemeColors.textPrimary(context),
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ),
                                IconButton(
                                  onPressed: () => _updateAdhkar(provider, adhkar['id'], count + 1),
                                  icon: const Icon(Icons.add, color: Colors.white),
                                  style: IconButton.styleFrom(
                                    backgroundColor: Colors.green[800],
                                  ),
                                ),
                                const Spacer(),
                                if (isCompleted)
                                  const Text(
                                    '✅ Completed',
                                    style: TextStyle(
                                      color: Colors.green,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  )
                                else
                                  TextButton(
                                    onPressed: () => _updateAdhkar(provider, adhkar['id'], adhkar['count']),
                                    child: const Text(
                                      'Complete',
                                      style: TextStyle(color: Colors.green),
                                    ),
                                  ),
                              ],
                            ),
                          ],
                        ),
                      );
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

  Widget _buildCategoryChip(String category, String label) {
    final isSelected = _selectedCategory == category;
    return GestureDetector(
      onTap: () => setState(() => _selectedCategory = category),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: isSelected 
              ? Colors.green[800] 
              : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              color: isSelected ? Colors.white : AppThemeColors.textSecondary(context),
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ),
      ),
    );
  }

  void _updateAdhkar(AppProvider provider, String id, int count) {
    provider.logAdhkar(id, count);
    setState(() {});
  }
}