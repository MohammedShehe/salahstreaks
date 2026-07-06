import 'dart:math';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:salahstreaks/providers/app_provider.dart';
import 'package:salahstreaks/models/ibadat_model.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';

class GraphsScreen extends StatefulWidget {
  const GraphsScreen({super.key});

  @override
  State<GraphsScreen> createState() => _GraphsScreenState();
}

class _GraphsScreenState extends State<GraphsScreen> with SingleTickerProviderStateMixin {
  String _selectedPeriod = 'Weekly';
  String _selectedGraphType = 'Bar';
  String _selectedIbadat = 'All';
  int _selectedMonth = DateTime.now().month;
  int _selectedYear = DateTime.now().year;

  late AnimationController _animationController;
  late Animation<double> _animation;

  final List<String> _periods = ['Daily', 'Weekly', 'Monthly', 'Yearly'];
  final List<String> _graphTypes = ['Bar', 'Line', 'Pie', 'Bipolar'];
  final List<String> _ibadatTypes = ['All', 'Salah', 'Sawm', 'Qiyyam', 'Quran', 'Sadaqat'];

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _animation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    );
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF0A0E1A), Color(0xFF1A1F2E)],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                const Text(
                  'Ibadat Analytics',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 16),
                _buildFilterRow(),
                const SizedBox(height: 16),
                Expanded(
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 600),
                    switchInCurve: Curves.easeInOut,
                    switchOutCurve: Curves.easeInOut,
                    child: _buildGraph(),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFilterRow() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.green[900]!.withOpacity(0.2),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.green[700]!.withOpacity(0.2)),
      ),
      child: Column(
        children: [
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildChipFilter('Period:', _selectedPeriod, _periods, (value) {
                  setState(() {
                    _selectedPeriod = value;
                    _animationController.reset();
                    _animationController.forward();
                  });
                }),
                _buildChipFilter('Type:', _selectedGraphType, _graphTypes, (value) {
                  setState(() {
                    _selectedGraphType = value;
                    _animationController.reset();
                    _animationController.forward();
                  });
                }),
                _buildChipFilter('Ibadat:', _selectedIbadat, _ibadatTypes, (value) {
                  setState(() {
                    _selectedIbadat = value;
                    _animationController.reset();
                    _animationController.forward();
                  });
                }),
              ],
            ),
          ),
          const SizedBox(height: 8),
          if (_selectedPeriod == 'Monthly' || _selectedPeriod == 'Yearly')
            Row(
              children: [
                if (_selectedPeriod == 'Monthly')
                  Expanded(
                    child: _buildMonthSelector(),
                  ),
                if (_selectedPeriod == 'Monthly') const SizedBox(width: 8),
                Expanded(
                  child: _buildYearSelector(),
                ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildChipFilter(String label, String selected, List<String> options, Function(String) onSelected) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              color: Colors.grey[400],
              fontSize: 12,
            ),
          ),
          Wrap(
            spacing: 4,
            children: options.map((option) {
              return FilterChip(
                key: ValueKey('filter_$option'),
                label: Text(option, style: TextStyle(
                  fontSize: 12,
                  color: selected == option ? Colors.white : Colors.grey[400],
                )),
                selected: selected == option,
                onSelected: (_) => onSelected(option),
                selectedColor: Colors.green[700],
                backgroundColor: Colors.grey[800]!.withOpacity(0.5),
                padding: const EdgeInsets.symmetric(horizontal: 8),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildMonthSelector() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.grey[800]!.withOpacity(0.3),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.green[700]!.withOpacity(0.2),
        ),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<int>(
          value: _selectedMonth,
          onChanged: (value) => setState(() => _selectedMonth = value!),
          items: List.generate(12, (index) {
            return DropdownMenuItem(
              key: ValueKey('month_${index + 1}'),
              value: index + 1,
              child: Text(
                DateFormat('MMMM').format(DateTime(2024, index + 1)),
                style: const TextStyle(color: Colors.white),
              ),
            );
          }),
          dropdownColor: const Color(0xFF1A1F2E),
          style: const TextStyle(color: Colors.white),
        ),
      ),
    );
  }

  Widget _buildYearSelector() {
    final currentYear = DateTime.now().year;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.grey[800]!.withOpacity(0.3),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.green[700]!.withOpacity(0.2),
        ),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<int>(
          value: _selectedYear,
          onChanged: (value) => setState(() => _selectedYear = value!),
          items: List.generate(10, (index) {
            final year = currentYear - index;
            return DropdownMenuItem(
              key: ValueKey('year_$year'),
              value: year,
              child: Text('$year', style: const TextStyle(color: Colors.white)),
            );
          }),
          dropdownColor: const Color(0xFF1A1F2E),
          style: const TextStyle(color: Colors.white),
        ),
      ),
    );
  }

  Widget _buildGraph() {
    final provider = Provider.of<AppProvider>(context);
    final allLogs = provider.logs;
    
    if (allLogs.isEmpty) {
      return _buildEmptyState();
    }

    List<IbadatLog> filteredLogs = _selectedIbadat != 'All' 
        ? allLogs.where((log) => log.type == _selectedIbadat).toList()
        : allLogs;

    filteredLogs = _filterByPeriod(filteredLogs);

    if (filteredLogs.isEmpty) {
      return Center(
        child: Text(
          'No data for selected filters',
          style: TextStyle(color: Colors.grey[400], fontSize: 16),
        ),
      );
    }

    return FadeTransition(
      opacity: _animation,
      child: _buildSelectedGraph(filteredLogs),
    );
  }

  List<IbadatLog> _filterByPeriod(List<IbadatLog> logs) {
    final now = DateTime.now();
    
    switch (_selectedPeriod) {
      case 'Daily':
        return logs.where((log) =>
          log.date.year == now.year &&
          log.date.month == now.month &&
          log.date.day == now.day
        ).toList();

      case 'Weekly':
        final weekAgo = DateTime(now.year, now.month, now.day - 7);
        return logs.where((log) => 
          log.date.isAfter(weekAgo) || 
          (log.date.year == weekAgo.year && 
           log.date.month == weekAgo.month && 
           log.date.day == weekAgo.day)
        ).toList();

      case 'Monthly':
        return logs.where((log) =>
          log.date.month == _selectedMonth &&
          log.date.year == _selectedYear
        ).toList();

      case 'Yearly':
        return logs.where((log) =>
          log.date.year == _selectedYear
        ).toList();

      default:
        return logs;
    }
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.show_chart, size: 80, color: Colors.grey[600]),
          const SizedBox(height: 16),
          Text(
            'No data available yet',
            style: TextStyle(color: Colors.grey[400], fontSize: 18),
          ),
          const SizedBox(height: 8),
          Text(
            'Start logging your ibadat to see charts!',
            style: TextStyle(color: Colors.grey[600], fontSize: 14),
          ),
        ],
      ),
    );
  }

  Widget _buildSelectedGraph(List<IbadatLog> logs) {
    switch (_selectedGraphType) {
      case 'Bar':
        return _buildBarChart(logs);
      case 'Line':
        return _buildLineChart(logs);
      case 'Pie':
        return _buildPieChart(logs);
      case 'Bipolar':
        return _buildBipolarChart(logs);
      default:
        return _buildBarChart(logs);
    }
  }

  // ============ BAR CHART ============
  Widget _buildBarChart(List<IbadatLog> logs) {
    final data = _getTimeSeriesData(logs);
    final colors = [Colors.green, Colors.blue, Colors.orange, Colors.purple, Colors.red];

    if (data.isEmpty) {
      return const Center(
        child: Text(
          'No data available',
          style: TextStyle(color: Colors.grey),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.green[900]!.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.green[700]!.withOpacity(0.2)),
      ),
      child: BarChart(
        BarChartData(
          alignment: BarChartAlignment.spaceAround,
          maxY: _getMaxValue(data) * 1.2,
          barGroups: data.asMap().entries.map((entry) {
            final index = entry.key;
            final entryData = entry.value;
            return BarChartGroupData(
              x: index,
              barRods: [
                BarChartRodData(
                  toY: (entryData['value'] as num).toDouble(),
                  color: colors[index % colors.length],
                  width: 30,
                  borderRadius: BorderRadius.circular(8),
                ),
              ],
              showingTooltipIndicators: [],
            );
          }).toList(),
          titlesData: FlTitlesData(
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                getTitlesWidget: (value, meta) {
                  if (value.toInt() < data.length) {
                    return Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        data[value.toInt()]['label'],
                        style: const TextStyle(color: Colors.white, fontSize: 10),
                        textAlign: TextAlign.center,
                      ),
                    );
                  }
                  return const Text('');
                },
              ),
            ),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 40,
                getTitlesWidget: (value, meta) {
                  return Text(
                    value.toInt().toString(),
                    style: const TextStyle(color: Colors.white, fontSize: 10),
                  );
                },
              ),
            ),
            topTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            rightTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
          ),
          gridData: FlGridData(
            show: true,
            drawHorizontalLine: true,
            horizontalInterval: _getGridInterval(data),
            getDrawingHorizontalLine: (value) {
              return FlLine(color: Colors.grey[800]!, strokeWidth: 1);
            },
          ),
          borderData: FlBorderData(
            show: false,
          ),
        ),
      ),
    );
  }

  // ============ LINE CHART ============
  Widget _buildLineChart(List<IbadatLog> logs) {
    final data = _getTimeSeriesData(logs);

    if (data.isEmpty) {
      return const Center(
        child: Text(
          'No data available',
          style: TextStyle(color: Colors.grey),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.green[900]!.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.green[700]!.withOpacity(0.2)),
      ),
      child: LineChart(
        LineChartData(
          lineBarsData: [
            LineChartBarData(
              spots: data.asMap().entries.map((entry) {
                return FlSpot(
                  entry.key.toDouble(), 
                  (entry.value['value'] as num).toDouble()
                );
              }).toList(),
              color: Colors.green,
              barWidth: 3,
              isCurved: true,
              dotData: FlDotData(
                show: true,
                getDotPainter: (spot, percent, barData, index) {
                  return FlDotCirclePainter(
                    radius: 6,
                    color: Colors.green[700]!,
                    strokeWidth: 2,
                    strokeColor: Colors.white,
                  );
                },
              ),
              belowBarData: BarAreaData(
                show: true,
                color: Colors.green.withOpacity(0.1),
              ),
            ),
          ],
          titlesData: FlTitlesData(
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                getTitlesWidget: (value, meta) {
                  if (value.toInt() < data.length) {
                    return Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        data[value.toInt()]['label'],
                        style: const TextStyle(color: Colors.white, fontSize: 10),
                        textAlign: TextAlign.center,
                      ),
                    );
                  }
                  return const Text('');
                },
              ),
            ),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 40,
                getTitlesWidget: (value, meta) {
                  return Text(
                    value.toInt().toString(),
                    style: const TextStyle(color: Colors.white, fontSize: 10),
                  );
                },
              ),
            ),
            topTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            rightTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
          ),
          gridData: FlGridData(
            show: true,
            drawHorizontalLine: true,
            horizontalInterval: _getGridInterval(data),
            getDrawingHorizontalLine: (value) {
              return FlLine(color: Colors.grey[800]!, strokeWidth: 1);
            },
          ),
          borderData: FlBorderData(
            show: false,
          ),
          minX: 0,
          maxX: data.length - 1,
          minY: 0,
          maxY: _getMaxValue(data) * 1.2,
        ),
      ),
    );
  }

  // ============ BIPOLAR CHART WITH FILLED AREAS ============
  Widget _buildBipolarChart(List<IbadatLog> logs) {
    final ibadatColors = {
      'Salah': Colors.green,
      'Sawm': Colors.blue,
      'Qiyyam': Colors.orange,
      'Quran': Colors.purple,
      'Sadaqat': Colors.red,
    };
    
    final ibadatIcons = {
      'Salah': '🕌',
      'Sawm': '🌙',
      'Qiyyam': '🌙',
      'Quran': '📖',
      'Sadaqat': '❤️',
    };

    // Group data by ibadat type
    final Map<String, List<Map<String, dynamic>>> typeData = {};
    
    // Get all unique ibadat types from logs
    final allTypes = logs.map((log) => log.type).toSet().toList();
    
    // If only one type or "All" is selected, we need to show all types
    final displayTypes = _selectedIbadat != 'All' 
        ? [_selectedIbadat] 
        : allTypes.isEmpty 
            ? ['Salah', 'Sawm', 'Qiyyam', 'Quran', 'Sadaqat'] 
            : allTypes;

    // Get time series data for each type
    for (final type in displayTypes) {
      final typeLogs = logs.where((log) => log.type == type).toList();
      if (typeLogs.isNotEmpty) {
        typeData[type] = _getTimeSeriesDataForType(typeLogs);
      }
    }

    if (typeData.isEmpty) {
      return Center(
        child: Text(
          'No data available for bipolar chart',
          style: TextStyle(color: Colors.grey[400]),
        ),
      );
    }

    // Find max value for scaling
    double maxValue = 0;
    double minValue = 0;
    int maxDataPoints = 0;
    
    for (final entry in typeData.entries) {
      if (entry.value.length > maxDataPoints) {
        maxDataPoints = entry.value.length;
      }
      for (final dataPoint in entry.value) {
        final val = (dataPoint['value'] as num).toDouble();
        if (val > maxValue) maxValue = val;
        if (val < minValue) minValue = val;
      }
    }
    
    // Calculate scale to fit in bipolar (both positive and negative)
    final maxAbs = max(max(maxValue.abs(), minValue.abs()), 1.0);

    // Create line spots for each type, alternating between positive and negative
    final lineBarsData = <LineChartBarData>[];
    int typeIndex = 0;
    
    for (final entry in typeData.entries) {
      final type = entry.key;
      final dataPoints = entry.value;
      final color = ibadatColors[type] ?? Colors.grey;
      
      // Alternate between positive and negative poles
      // Even index -> positive side, Odd index -> negative side
      final isPositive = typeIndex % 2 == 0;
      final multiplier = isPositive ? 1.0 : -1.0;
      
      final spots = <FlSpot>[];
      for (int i = 0; i < dataPoints.length; i++) {
        final value = (dataPoints[i]['value'] as num).toDouble();
        // Scale the value and apply pole direction
        final scaledValue = (value / maxAbs) * 5.0 * multiplier;
        spots.add(FlSpot(i.toDouble(), scaledValue));
      }
      
      // For positive lines, fill below (towards 0)
      // For negative lines, fill above (towards 0)
      BarAreaData? belowArea;
      BarAreaData? aboveArea;
      
      if (isPositive) {
        // Positive: fill below the line (area between line and 0)
        belowArea = BarAreaData(
          show: true,
          color: color.withOpacity(0.35),
          cutOffY: 0,
          applyCutOffY: true,
        );
        aboveArea = BarAreaData(show: false);
      } else {
        // Negative: fill above the line (area between line and 0)
        aboveArea = BarAreaData(
          show: true,
          color: color.withOpacity(0.35),
          cutOffY: 0,
          applyCutOffY: true,
        );
        belowArea = BarAreaData(show: false);
      }
      
      lineBarsData.add(
        LineChartBarData(
          spots: spots,
          color: color,
          barWidth: 3,
          isCurved: true,
          dotData: FlDotData(
            show: true,
            getDotPainter: (spot, percent, barData, index) {
              return FlDotCirclePainter(
                radius: 5,
                color: color,
                strokeWidth: 2,
                strokeColor: Colors.white,
              );
            },
          ),
          belowBarData: belowArea!,
          aboveBarData: aboveArea!,
          shadow: Shadow(
            color: color.withOpacity(0.4),
            blurRadius: 8,
          ),
        ),
      );
      typeIndex++;
    }

    // Generate x-axis labels
    final firstKey = typeData.keys.first;
    final firstData = typeData[firstKey]!;
    final labels = firstData.map((d) => d['label'] as String).toList();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.green[900]!.withOpacity(0.15),
            Colors.green[800]!.withOpacity(0.05),
            Colors.green[900]!.withOpacity(0.15),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Colors.green[700]!.withOpacity(0.3),
        ),
      ),
      child: Column(
        children: [
          // Header with legend
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.green[900]!.withOpacity(0.3),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.compare_arrows,
                  color: Colors.white,
                  size: 16,
                ),
                const SizedBox(width: 6),
                const Text(
                  'Bipolar Analysis',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(width: 12),
                ...typeData.keys.map((type) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Row(
                      children: [
                        Container(
                          width: 12,
                          height: 12,
                          decoration: BoxDecoration(
                            color: ibadatColors[type],
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '$type ${ibadatIcons[type] ?? ''}',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.8),
                            fontSize: 10,
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ],
            ),
          ),
          const SizedBox(height: 12),
          
          // Bipolar Line Chart with Filled Areas
          Expanded(
            child: LineChart(
              LineChartData(
                lineBarsData: lineBarsData,
                
                minX: 0,
                maxX: maxDataPoints - 1,
                minY: -6.5,
                maxY: 6.5,
                
                titlesData: FlTitlesData(
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      interval: 1,
                      getTitlesWidget: (value, meta) {
                        if (value.toInt() < labels.length) {
                          return Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Text(
                              labels[value.toInt()],
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 9,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          );
                        }
                        return const Text('');
                      },
                    ),
                  ),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 30,
                      getTitlesWidget: (value, meta) {
                        final label = value.toInt();
                        if (label == 0) {
                          return Text(
                            '0',
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.5),
                              fontSize: 9,
                            ),
                          );
                        }
                        return Text(
                          '$label',
                          style: TextStyle(
                            color: label > 0 
                                ? Colors.green[400]! 
                                : Colors.red[400]!,
                            fontSize: 9,
                          ),
                        );
                      },
                    ),
                  ),
                  topTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  rightTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                ),
                
                gridData: FlGridData(
                  show: true,
                  drawHorizontalLine: true,
                  drawVerticalLine: false,
                  horizontalInterval: 1,
                  getDrawingHorizontalLine: (value) {
                    final isZero = value == 0;
                    return FlLine(
                      color: isZero 
                          ? Colors.white.withOpacity(0.4) 
                          : Colors.grey[800]!.withOpacity(0.5),
                      strokeWidth: isZero ? 1.5 : 0.5,
                      dashArray: isZero ? null : [5, 5],
                    );
                  },
                ),
                
                borderData: FlBorderData(
                  show: false,
                ),
                
                lineTouchData: LineTouchData(
                  enabled: true,
                  touchTooltipData: LineTouchTooltipData(
                    tooltipBgColor: const Color(0xFF1A1F2E),
                    tooltipRoundedRadius: 8,
                    tooltipPadding: const EdgeInsets.all(8),
                    getTooltipItems: (List<LineBarSpot> touchedSpots) {
                      return touchedSpots.map((spot) {
                        final value = spot.y;
                        final type = spot.barIndex < displayTypes.length 
                            ? displayTypes[spot.barIndex]
                            : 'Unknown';
                        return LineTooltipItem(
                          '$type: ${value.abs().toStringAsFixed(1)}',
                          const TextStyle(color: Colors.white, fontSize: 12),
                        );
                      }).toList();
                    },
                  ),
                ),
                
                extraLinesData: ExtraLinesData(
                  horizontalLines: [
                    HorizontalLine(
                      y: 0,
                      color: Colors.white.withOpacity(0.5),
                      strokeWidth: 1.5,
                    ),
                  ],
                ),
              ),
            ),
          ),
          
          // Bottom info with legend
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.green[900]!.withOpacity(0.3),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                Row(
                  children: [
                    Container(
                      width: 20,
                      height: 8,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [Colors.green.withOpacity(0.5), Colors.green.withOpacity(0.05)],
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                        ),
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                    const SizedBox(width: 4),
                    const Text(
                      'Positive',
                      style: TextStyle(color: Colors.green, fontSize: 10),
                    ),
                  ],
                ),
                Row(
                  children: [
                    Container(
                      width: 20,
                      height: 8,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [Colors.red.withOpacity(0.5), Colors.red.withOpacity(0.05)],
                          begin: Alignment.bottomCenter,
                          end: Alignment.topCenter,
                        ),
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                    const SizedBox(width: 4),
                    const Text(
                      'Negative',
                      style: TextStyle(color: Colors.red, fontSize: 10),
                    ),
                  ],
                ),
                Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 4),
                    const Text(
                      'Line',
                      style: TextStyle(color: Colors.white38, fontSize: 10),
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

  // Get time-series data for a specific ibadat type
  List<Map<String, dynamic>> _getTimeSeriesDataForType(List<IbadatLog> logs) {
    final now = DateTime.now();
    final result = <Map<String, dynamic>>[];

    switch (_selectedPeriod) {
      case 'Daily':
        for (int hour = 0; hour < 24; hour++) {
          final count = logs.where((log) => log.date.hour == hour).length;
          result.add({
            'label': hour == 0 ? '12 AM' : hour < 12 ? '$hour AM' : hour == 12 ? '12 PM' : '${hour - 12} PM',
            'value': count,
          });
        }
        break;

      case 'Weekly':
        for (int i = 6; i >= 0; i--) {
          final date = DateTime(now.year, now.month, now.day - i);
          final count = logs.where((log) =>
            log.date.year == date.year &&
            log.date.month == date.month &&
            log.date.day == date.day
          ).length;
          result.add({
            'label': DateFormat('E').format(date),
            'value': count,
          });
        }
        break;

      case 'Monthly':
        final daysInMonth = DateTime(_selectedYear, _selectedMonth + 1, 0).day;
        for (int day = 1; day <= daysInMonth; day++) {
          final count = logs.where((log) =>
            log.date.day == day &&
            log.date.month == _selectedMonth &&
            log.date.year == _selectedYear
          ).length;
          result.add({
            'label': '$day',
            'value': count,
          });
        }
        break;

      case 'Yearly':
        for (int month = 1; month <= 12; month++) {
          final count = logs.where((log) =>
            log.date.month == month &&
            log.date.year == _selectedYear
          ).length;
          result.add({
            'label': DateFormat('MMM').format(DateTime(_selectedYear, month)),
            'value': count,
          });
        }
        break;

      default:
        for (int i = 6; i >= 0; i--) {
          final date = DateTime(now.year, now.month, now.day - i);
          final count = logs.where((log) =>
            log.date.year == date.year &&
            log.date.month == date.month &&
            log.date.day == date.day
          ).length;
          result.add({
            'label': DateFormat('E').format(date),
            'value': count,
          });
        }
    }

    return result;
  }

  // ============ PIE CHART ============
  Widget _buildPieChart(List<IbadatLog> logs) {
    final Map<String, int> data = {};
    for (final log in logs) {
      data[log.type] = (data[log.type] ?? 0) + 1;
    }

    if (data.isEmpty) {
      return Center(
        child: Text(
          'No data for this period',
          style: TextStyle(color: Colors.grey[400]),
        ),
      );
    }

    final colors = [Colors.green, Colors.blue, Colors.orange, Colors.purple, Colors.red];
    final total = data.values.fold(0, (sum, value) => sum + value);
    final sections = <PieChartSectionData>[];

    data.entries.toList().asMap().entries.forEach((entry) {
      final index = entry.key;
      final entryData = entry.value;
      final percentage = (entryData.value / total * 100);
      sections.add(
        PieChartSectionData(
          value: entryData.value.toDouble(),
          color: colors[index % colors.length],
          title: '${percentage.toStringAsFixed(1)}%',
          radius: 80,
          titleStyle: const TextStyle(
            color: Colors.white,
            fontSize: 12,
            fontWeight: FontWeight.bold,
          ),
        ),
      );
    });

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.green[900]!.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.green[700]!.withOpacity(0.2)),
      ),
      child: Column(
        children: [
          Expanded(
            child: PieChart(
              PieChartData(
                sections: sections,
                sectionsSpace: 2,
                centerSpaceRadius: 40,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 12,
            children: data.keys.toList().asMap().entries.map((entry) {
              final index = entry.key;
              final type = entry.value;
              return Row(
                key: ValueKey('legend_$type'),
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      color: colors[index % colors.length],
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '$type (${data[type]})',
                    style: TextStyle(color: Colors.grey[300], fontSize: 11),
                  ),
                ],
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  // ============ HELPERS ============
  List<Map<String, dynamic>> _getTimeSeriesData(List<IbadatLog> logs) {
    final now = DateTime.now();
    final result = <Map<String, dynamic>>[];

    switch (_selectedPeriod) {
      case 'Daily':
        for (int hour = 0; hour < 24; hour++) {
          final count = logs.where((log) => log.date.hour == hour).length;
          result.add({
            'label': hour == 0 ? '12 AM' : hour < 12 ? '$hour AM' : hour == 12 ? '12 PM' : '${hour - 12} PM',
            'value': count,
          });
        }
        break;

      case 'Weekly':
        for (int i = 6; i >= 0; i--) {
          final date = DateTime(now.year, now.month, now.day - i);
          final count = logs.where((log) =>
            log.date.year == date.year &&
            log.date.month == date.month &&
            log.date.day == date.day
          ).length;
          result.add({
            'label': DateFormat('E').format(date),
            'value': count,
          });
        }
        break;

      case 'Monthly':
        final daysInMonth = DateTime(_selectedYear, _selectedMonth + 1, 0).day;
        for (int day = 1; day <= daysInMonth; day++) {
          final count = logs.where((log) =>
            log.date.day == day &&
            log.date.month == _selectedMonth &&
            log.date.year == _selectedYear
          ).length;
          result.add({
            'label': '$day',
            'value': count,
          });
        }
        break;

      case 'Yearly':
        for (int month = 1; month <= 12; month++) {
          final count = logs.where((log) =>
            log.date.month == month &&
            log.date.year == _selectedYear
          ).length;
          result.add({
            'label': DateFormat('MMM').format(DateTime(_selectedYear, month)),
            'value': count,
          });
        }
        break;

      default:
        for (int i = 6; i >= 0; i--) {
          final date = DateTime(now.year, now.month, now.day - i);
          final count = logs.where((log) =>
            log.date.year == date.year &&
            log.date.month == date.month &&
            log.date.day == date.day
          ).length;
          result.add({
            'label': DateFormat('E').format(date),
            'value': count,
          });
        }
    }

    return result;
  }

  double _getMaxValue(List<Map<String, dynamic>> data) {
    if (data.isEmpty) return 1;
    final max = data.fold(0.0, (max, item) {
      final value = (item['value'] as num).toDouble();
      return value > max ? value : max;
    });
    return max < 1 ? 1 : max;
  }

  double _getGridInterval(List<Map<String, dynamic>> data) {
    final max = _getMaxValue(data);
    if (max <= 1) return 1;
    if (max <= 5) return 1;
    if (max <= 10) return 2;
    if (max <= 20) return 5;
    return 10;
  }
}