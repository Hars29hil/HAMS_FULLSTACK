import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../services/api_client.dart';

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  Map<String, dynamic>? _stats;
  bool _isLoading = true;
  String _errorMessage = 'Failed to load stats';

  @override
  void initState() {
    super.initState();
    _fetchStats();
  }

  Future<void> _fetchStats() async {
    try {
      final response = await ApiClient().dio.get('/admin/dashboard');
      if (response.data['success']) {
        setState(() {
          _stats = response.data['data'];
          _isLoading = false;
        });
      } else {
        setState(() {
          _isLoading = false;
          _errorMessage = response.data['message'] ?? 'Unknown error';
        });
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = e.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    
    if (_stats == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Text(
            'Error: $_errorMessage',
            style: const TextStyle(color: Colors.red),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Here\'s what\'s happening in your hostel today',
            style: TextStyle(fontSize: 15, color: Colors.grey),
          ),
          const SizedBox(height: 24),
          GridView.extent(
            maxCrossAxisExtent: 280,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 16,
            crossAxisSpacing: 16,
            childAspectRatio: 1.4, // Decreased to give more vertical space
            children: [
              _buildStatCard('Total Students', _stats!['total_students'], Icons.people_alt, Colors.blue),
              _buildStatCard('Present Today', _stats!['present_today'], Icons.check_circle_outline, Colors.green),
              _buildStatCard('Late', _stats!['late_today'], Icons.access_time, Colors.orange),
              _buildStatCard('Absent', _stats!['absent_today'], Icons.cancel_outlined, Colors.red),
            ],
          ),
          const SizedBox(height: 24),
          LayoutBuilder(
            builder: (context, constraints) {
              if (constraints.maxWidth > 800) {
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(flex: 2, child: _buildAttendanceOverview()),
                    const SizedBox(width: 24),
                    Expanded(flex: 1, child: _buildLiveFloorStatus()),
                  ],
                );
              } else {
                return Column(
                  children: [
                    _buildAttendanceOverview(),
                    const SizedBox(height: 24),
                    _buildLiveFloorStatus(),
                  ],
                );
              }
            }
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(String title, int count, IconData iconData, MaterialColor color) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Row(
              children: [
                Icon(iconData, size: 20, color: color.shade700),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.grey.shade600),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              count.toString(),
              style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAttendanceOverview() {
    final weeklyStats = _stats!['weekly_stats'] as List<dynamic>? ?? [];
    
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: Container(
        height: 400,
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Attendance Overview (Last 7 Days)', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
            const SizedBox(height: 24),
            Expanded(
              child: weeklyStats.isEmpty 
                  ? const Center(child: Text('No data available', style: TextStyle(color: Colors.grey)))
                  : BarChart(
                      BarChartData(
                        alignment: BarChartAlignment.spaceAround,
                        maxY: _stats!['total_students'].toDouble() * 1.1,
                        barTouchData: BarTouchData(enabled: true),
                        titlesData: FlTitlesData(
                          show: true,
                          bottomTitles: AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: true,
                              getTitlesWidget: (double value, TitleMeta meta) {
                                if (value >= 0 && value < weeklyStats.length) {
                                  final dateStr = weeklyStats[value.toInt()]['date'] as String;
                                  final day = DateTime.parse(dateStr).day.toString();
                                  final month = DateTime.parse(dateStr).month.toString();
                                  return Padding(
                                    padding: const EdgeInsets.only(top: 8.0),
                                    child: Text('$day/$month', style: const TextStyle(fontSize: 12)),
                                  );
                                }
                                return const Text('');
                              },
                            ),
                          ),
                          leftTitles: const AxisTitles(
                            sideTitles: SideTitles(showTitles: true, reservedSize: 40),
                          ),
                          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                        ),
                        gridData: const FlGridData(show: false),
                        borderData: FlBorderData(show: false),
                        barGroups: weeklyStats.asMap().entries.map((entry) {
                          final idx = entry.key;
                          final stat = entry.value;
                          return BarChartGroupData(
                            x: idx,
                            barRods: [
                              BarChartRodData(toY: double.parse(stat['present'].toString()), color: Colors.green, width: 16),
                              BarChartRodData(toY: double.parse(stat['late'].toString()), color: Colors.orange, width: 16),
                            ],
                          );
                        }).toList(),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLiveFloorStatus() {
    final floorStatus = _stats!['floor_status'] as List<dynamic>? ?? [];

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: Container(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Live Floor Status', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
            const SizedBox(height: 16),
            if (floorStatus.isEmpty)
              const Text('No floor data available', style: TextStyle(color: Colors.grey))
            else
              ...floorStatus.map((floor) {
                return Column(
                  children: [
                    _buildFloorRow(
                      floor['floor_name'],
                      floor['session_status'] == 'Active' ? 'Online' : 'Offline',
                      floor['session_status'],
                      '${floor['present_students']} / ${floor['total_students']} students',
                    ),
                    const Divider(height: 32),
                  ],
                );
              }),
          ],
        ),
      ),
    );
  }

  Widget _buildFloorRow(String floorName, String status, String attStatus, String stats) {
    return Row(
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(floorName, style: const TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 4),
            Text('Attendance $attStatus', style: const TextStyle(fontSize: 12, color: Colors.grey)),
            const SizedBox(height: 4),
            Text(stats, style: const TextStyle(fontSize: 12, color: Colors.grey)),
          ],
        ),
        const Spacer(),
        Row(
          children: [
            Icon(Icons.circle, size: 10, color: status == 'Online' ? Colors.green : Colors.red),
            const SizedBox(width: 4),
            Text(status, style: const TextStyle(fontSize: 12)),
          ],
        ),
      ],
    );
  }
}
