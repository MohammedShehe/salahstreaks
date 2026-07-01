import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:salahstreaks/providers/app_provider.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'dart:math';

class GraphsScreen extends StatefulWidget {
  const GraphsScreen({super.key});

  @override
  State<GraphsScreen> createState() => _GraphsScreenState();
}

class _GraphsScreenState extends State<GraphsScreen> {
  String _selectedPeriod = 'Daily';
  String _selectedGraphType = 'Bar';
  String _selectedIbadat = 'All';
  int _selectedMonth = DateTime.now().month;
  int _selectedYear = DateTime.now().year;

  final List<String> _periods = ['Daily', 'Weekly', 'Monthly', 'Yearly'];
  final List<String> _graphTypes = ['Bar', 'Line', 'Pie', 'Donut', 'Dotted'];
  final List<String> _ibadatTypes = ['All', 'Salah', 'Sawm', 'Qiyyam', 'Quran', 'Sadaqat'];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF0A0E1A),
              Color(0xFF1A1F2E),
            ],
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
        border: Border.all(
          color: Colors.green[700]!.withOpacity(0.2),
        ),
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
          Row(
            children: [
              Expanded(
                child: _buildMonthSelector(),
              ),
              const SizedBox(width: 8),
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
    final logs = provider.logs;
    
    if (logs.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.show_chart, size: 80, color: Colors.grey[600]),
            const SizedBox(height: 16),
            Text(
              'No data available yet',
              style: TextStyle(
                color: Colors.grey[400],
                fontSize: 18,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Start logging your ibadat to see charts!',
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 14,
              ),
            ),
          ],
        ),
      );
    }

    final filteredLogs = _selectedIbadat != 'All' 
        ? logs.where((log) => log.type == _selectedIbadat).toList()
        : logs;

    if (filteredLogs.isEmpty) {
      return Center(
        child: Text(
          'No data for selected Ibadat',
          style: TextStyle(
            color: Colors.grey[400],
            fontSize: 16,
          ),
        ),
      );
    }

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 500),
      child: _buildSelectedGraph(filteredLogs),
    );
  }

  Widget _buildSelectedGraph(List logs) {
    switch (_selectedGraphType) {
      case 'Bar':
        return _buildBarChart(logs);
      case 'Line':
        return _buildLineChart(logs);
      case 'Pie':
        return _buildPieChart(logs);
      case 'Donut':
        return _buildDonutChart(logs);
      case 'Dotted':
        return _buildDottedChart(logs);
      default:
        return _buildBarChart(logs);
    }
  }

  Widget _buildBarChart(List logs) {
    final Map<String, int> data = {};
    for (final log in logs) {
      data[log.type] = (data[log.type] ?? 0) + 1;
    }

    final colors = [Colors.green, Colors.blue, Colors.orange, Colors.purple, Colors.red];
    
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.green[900]!.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Colors.green[700]!.withOpacity(0.2),
        ),
      ),
      child: BarChart(
        BarChartData(
          alignment: BarChartAlignment.spaceAround,
          barGroups: data.entries.toList().asMap().entries.map((entry) {
            final index = entry.key;
            final entryData = entry.value;
            return BarChartGroupData(
              x: index,
              barRods: [
                BarChartRodData(
                  toY: entryData.value.toDouble(),
                  color: colors[index % colors.length],
                  width: 40,
                  borderRadius: BorderRadius.circular(8),
                ),
              ],
            );
          }).toList(),
          titlesData: FlTitlesData(
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                getTitlesWidget: (value, meta) {
                  return Text(
                    data.keys.toList()[value.toInt()],
                    style: const TextStyle(color: Colors.white, fontSize: 12),
                  );
                },
              ),
            ),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 40,
                getTitlesWidget: (value, meta) {
                  return Text(
                    '${value.toInt()}',
                    style: const TextStyle(color: Colors.white, fontSize: 10),
                  );
                },
              ),
            ),
          ),
          gridData: FlGridData(
            show: true,
            drawHorizontalLine: true,
            horizontalInterval: 1,
            getDrawingHorizontalLine: (value) {
              return FlLine(
                color: Colors.grey[800]!,
                strokeWidth: 1,
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildLineChart(List logs) {
    final Map<String, int> data = {};
    for (final log in logs) {
      data[log.type] = (data[log.type] ?? 0) + 1;
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.green[900]!.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Colors.green[700]!.withOpacity(0.2),
        ),
      ),
      child: LineChart(
        LineChartData(
          lineBarsData: [
            LineChartBarData(
              spots: data.entries.toList().asMap().entries.map((entry) {
                return FlSpot(entry.key.toDouble(), entry.value.value.toDouble());
              }).toList(),
              color: Colors.green,
              barWidth: 3,
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
            ),
          ],
          titlesData: FlTitlesData(
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                getTitlesWidget: (value, meta) {
                  return Text(
                    data.keys.toList()[value.toInt()],
                    style: const TextStyle(color: Colors.white, fontSize: 12),
                  );
                },
              ),
            ),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 40,
                getTitlesWidget: (value, meta) {
                  return Text(
                    '${value.toInt()}',
                    style: const TextStyle(color: Colors.white, fontSize: 10),
                  );
                },
              ),
            ),
          ),
          gridData: FlGridData(
            show: true,
            drawHorizontalLine: true,
            horizontalInterval: 1,
            getDrawingHorizontalLine: (value) {
              return FlLine(
                color: Colors.grey[800]!,
                strokeWidth: 1,
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildPieChart(List logs) {
    final Map<String, int> data = {};
    for (final log in logs) {
      data[log.type] = (data[log.type] ?? 0) + 1;
    }

    final colors = [Colors.green, Colors.blue, Colors.orange, Colors.purple, Colors.red];
    final total = data.values.fold(0, (sum, value) => sum + value);
    final List<PieChartSectionData> sections = [];

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
        border: Border.all(
          color: Colors.green[700]!.withOpacity(0.2),
        ),
      ),
      child: PieChart(
        PieChartData(
          sections: sections,
          sectionsSpace: 2,
          centerSpaceRadius: 40,
        ),
      ),
    );
  }

  Widget _buildDonutChart(List logs) {
    final Map<String, int> data = {};
    for (final log in logs) {
      data[log.type] = (data[log.type] ?? 0) + 1;
    }

    final colors = [Colors.green, Colors.blue, Colors.orange, Colors.purple, Colors.red];
    final total = data.values.fold(0, (sum, value) => sum + value);
    final List<PieChartSectionData> sections = [];

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
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.green[900]!.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Colors.green[700]!.withOpacity(0.2),
        ),
      ),
      child: PieChart(
        PieChartData(
          sections: sections,
          sectionsSpace: 2,
          centerSpaceRadius: 50,
        ),
      ),
    );
  }

  Widget _buildDottedChart(List logs) {
    final Map<String, int> data = {};
    for (final log in logs) {
      data[log.type] = (data[log.type] ?? 0) + 1;
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.green[900]!.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Colors.green[700]!.withOpacity(0.2),
        ),
      ),
      child: LineChart(
        LineChartData(
          lineBarsData: [
            LineChartBarData(
              spots: data.entries.toList().asMap().entries.map((entry) {
                return FlSpot(entry.key.toDouble(), entry.value.value.toDouble());
              }).toList(),
              color: Colors.green,
              barWidth: 2,
              dotData: const FlDotData(show: false),
              dashArray: const [5, 5],
            ),
          ],
          titlesData: FlTitlesData(
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                getTitlesWidget: (value, meta) {
                  return Text(
                    data.keys.toList()[value.toInt()],
                    style: const TextStyle(color: Colors.white, fontSize: 12),
                  );
                },
              ),
            ),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 40,
                getTitlesWidget: (value, meta) {
                  return Text(
                    '${value.toInt()}',
                    style: const TextStyle(color: Colors.white, fontSize: 10),
                  );
                },
              ),
            ),
          ),
          gridData: FlGridData(
            show: true,
            drawHorizontalLine: true,
            horizontalInterval: 1,
            getDrawingHorizontalLine: (value) {
              return FlLine(
                color: Colors.grey[800]!,
                strokeWidth: 1,
              );
            },
          ),
        ),
      ),
    );
  }
}