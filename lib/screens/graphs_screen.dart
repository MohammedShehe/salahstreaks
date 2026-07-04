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

class _GraphsScreenState extends State<GraphsScreen> {
  String _selectedPeriod = 'Weekly';
  String _selectedGraphType = 'Bar';
  String _selectedIbadat = 'All';
  int _selectedMonth = DateTime.now().month;
  int _selectedYear = DateTime.now().year;

  final List<String> _periods = ['Daily', 'Weekly', 'Monthly', 'Yearly'];
  final List<String> _graphTypes = ['Bar', 'Line', 'Pie', 'Donut'];
  final List<String> _ibadatTypes = ['All', 'Salah', 'Sawm', 'Qiyyam', 'Quran', 'Sadaqat'];

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
                  child: _buildGraph(),
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
                  setState(() => _selectedPeriod = value);
                }),
                _buildChipFilter('Type:', _selectedGraphType, _graphTypes, (value) {
                  setState(() => _selectedGraphType = value);
                }),
                _buildChipFilter('Ibadat:', _selectedIbadat, _ibadatTypes, (value) {
                  setState(() => _selectedIbadat = value);
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

    // 1. Filter by Ibadat type
    List<IbadatLog> filteredLogs = _selectedIbadat != 'All' 
        ? allLogs.where((log) => log.type == _selectedIbadat).toList()
        : allLogs;

    // 2. Filter by time period
    filteredLogs = _filterByPeriod(filteredLogs);

    if (filteredLogs.isEmpty) {
      return Center(
        child: Text(
          'No data for selected filters',
          style: TextStyle(color: Colors.grey[400], fontSize: 16),
        ),
      );
    }

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 500),
      child: _buildSelectedGraph(filteredLogs, key: ValueKey('${_selectedGraphType}_${_selectedPeriod}_${_selectedIbadat}')),
    );
  }

  List<IbadatLog> _filterByPeriod(List<IbadatLog> logs) {
    final now = DateTime.now();
    
    switch (_selectedPeriod) {
      case 'Daily':
        // Today only
        return logs.where((log) =>
          log.date.year == now.year &&
          log.date.month == now.month &&
          log.date.day == now.day
        ).toList();

      case 'Weekly':
        // Last 7 days (including today)
        final weekAgo = DateTime(now.year, now.month, now.day - 7);
        return logs.where((log) => 
          log.date.isAfter(weekAgo) || 
          (log.date.year == weekAgo.year && 
           log.date.month == weekAgo.month && 
           log.date.day == weekAgo.day)
        ).toList();

      case 'Monthly':
        // Selected month only
        return logs.where((log) =>
          log.date.month == _selectedMonth &&
          log.date.year == _selectedYear
        ).toList();

      case 'Yearly':
        // Selected year only
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

  Widget _buildSelectedGraph(List<IbadatLog> logs, {Key? key}) {
    switch (_selectedGraphType) {
      case 'Bar':
        return _buildBarChart(logs, key: key);
      case 'Line':
        return _buildLineChart(logs, key: key);
      case 'Pie':
        return _buildPieChart(logs, key: key);
      case 'Donut':
        return _buildDonutChart(logs, key: key);
      default:
        return _buildBarChart(logs, key: key);
    }
  }

  // ============ UPDATED CHARTS WITH TIME-AWARE DATA ============

  Widget _buildBarChart(List<IbadatLog> logs, {Key? key}) {
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
      key: key,
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

  Widget _buildLineChart(List<IbadatLog> logs, {Key? key}) {
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
      key: key,
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

  // ============ HELPER: Get time-series data based on selected period ============
  List<Map<String, dynamic>> _getTimeSeriesData(List<IbadatLog> logs) {
    final now = DateTime.now();
    final result = <Map<String, dynamic>>[];

    switch (_selectedPeriod) {
      case 'Daily':
        // Show hourly breakdown for today
        for (int hour = 0; hour < 24; hour++) {
          final count = logs.where((log) => log.date.hour == hour).length;
          result.add({
            'label': hour == 0 ? '12 AM' : hour < 12 ? '$hour AM' : hour == 12 ? '12 PM' : '${hour - 12} PM',
            'value': count,
          });
        }
        break;

      case 'Weekly':
        // Show daily breakdown for last 7 days
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
        // Show daily breakdown for the selected month
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
        // Show monthly breakdown for the selected year
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
        // Default: show by day of week
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

  // ============ PIE CHART ============
  Widget _buildPieChart(List<IbadatLog> logs, {Key? key}) {
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
      key: key,
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
          // Legend
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

  Widget _buildDonutChart(List<IbadatLog> logs, {Key? key}) {
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
          radius: 60,
          titleStyle: const TextStyle(
            color: Colors.white,
            fontSize: 12,
            fontWeight: FontWeight.bold,
          ),
        ),
      );
    });

    return Container(
      key: key,
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
                centerSpaceRadius: 50,
                centerSpaceColor: const Color(0xFF1A1F2E),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Total: $total entries',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }
}