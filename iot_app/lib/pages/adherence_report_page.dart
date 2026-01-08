import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import '../services/firestore_service.dart';
import '../models/dose_record.dart'; // This is MedicineRecord

class AdherenceReportPage extends StatefulWidget {
  @override
  _AdherenceReportPageState createState() => _AdherenceReportPageState();
}

class _AdherenceReportPageState extends State<AdherenceReportPage> {
  final FirestoreService _firestoreService = FirestoreService();
  
  DateTime _selectedStartDate = DateTime.now().subtract(Duration(days: 7));
  DateTime _selectedEndDate = DateTime.now();
  
  String _selectedPeriod = 'Last 7 Days';
  
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text('Adherence Report'),
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildPeriodSelector(),
            SizedBox(height: 20),
            _buildOverallStats(),
            SizedBox(height: 20),
            _buildAdherenceChart(),
            SizedBox(height: 20),
            _buildDoseHistory(),
          ],
        ),
      ),
    );
  }

  Widget _buildPeriodSelector() {
    return Card(
      elevation: 2,
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Select Period',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 12),
            Wrap(
              spacing: 8,
              children: [
                ChoiceChip(
                  label: Text('Last 7 Days'),
                  selected: _selectedPeriod == 'Last 7 Days',
                  onSelected: (selected) {
                    if (selected) {
                      setState(() {
                        _selectedPeriod = 'Last 7 Days';
                        _selectedStartDate = DateTime.now().subtract(Duration(days: 7));
                        _selectedEndDate = DateTime.now();
                      });
                    }
                  },
                ),
                ChoiceChip(
                  label: Text('Last 30 Days'),
                  selected: _selectedPeriod == 'Last 30 Days',
                  onSelected: (selected) {
                    if (selected) {
                      setState(() {
                        _selectedPeriod = 'Last 30 Days';
                        _selectedStartDate = DateTime.now().subtract(Duration(days: 30));
                        _selectedEndDate = DateTime.now();
                      });
                    }
                  },
                ),
                ChoiceChip(
                  label: Text('This Month'),
                  selected: _selectedPeriod == 'This Month',
                  onSelected: (selected) {
                    if (selected) {
                      final now = DateTime.now();
                      setState(() {
                        _selectedPeriod = 'This Month';
                        _selectedStartDate = DateTime(now.year, now.month, 1);
                        _selectedEndDate = now;
                      });
                    }
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOverallStats() {
    return StreamBuilder<List<MedicineRecord>>(
      stream: _firestoreService.getRecordsInRange(_selectedStartDate, _selectedEndDate),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Card(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Text('Error loading stats: ${snapshot.error}'),
            ),
          );
        }

        final records = snapshot.data ?? [];
        final now = DateTime.now();
        
        // Filter out future records
        final pastRecords = records.where((record) => 
          record.scheduledTime.isBefore(now) || 
          record.scheduledTime.day == now.day
        ).toList();
        
        final total = pastRecords.length;
        final taken = pastRecords.where((r) => r.status == 'completed').length;
        final missed = pastRecords.where((r) => r.status == 'missed').length;
        final skipped = pastRecords.where((r) => r.status == 'overdue').length;
        final adherenceRate = total > 0 ? (taken / total) * 100 : 0.0;

        return Card(
          elevation: 4,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: Padding(
            padding: EdgeInsets.all(16),
            child: Column(
              children: [
                Text(
                  'Overall Adherence',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                SizedBox(height: 20),
                SizedBox(
                  height: 150,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      PieChart(
                        PieChartData(
                          sectionsSpace: 2,
                          centerSpaceRadius: 50,
                          sections: [
                            PieChartSectionData(
                              value: taken.toDouble(),
                              color: Color(0xFF66BB6A),
                              title: taken.toString(),
                              radius: 40,
                              titleStyle: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                            PieChartSectionData(
                              value: missed.toDouble(),
                              color: Color(0xFFE53935),
                              title: missed.toString(),
                              radius: 40,
                              titleStyle: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                            PieChartSectionData(
                              value: skipped.toDouble(),
                              color: Color(0xFFFF9800),
                              title: skipped.toString(),
                              radius: 40,
                              titleStyle: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            '${adherenceRate.toStringAsFixed(1)}%',
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF1976D2),
                            ),
                          ),
                          Text(
                            'Adherence',
                            style: TextStyle(fontSize: 12, color: Colors.grey),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildStatColumn('Total', total, Color(0xFF1976D2)),
                    _buildStatColumn('Taken', taken, Color(0xFF66BB6A)),
                    _buildStatColumn('Missed', missed, Color(0xFFE53935)),
                    _buildStatColumn('Skipped', skipped, Color(0xFFFF9800)),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildStatColumn(String label, int value, Color color) {
    return Column(
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        SizedBox(height: 4),
        Text(
          value.toString(),
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text(
          label,
          style: TextStyle(fontSize: 12, color: Colors.grey[600]),
        ),
      ],
    );
  }

  Widget _buildAdherenceChart() {
    return Card(
      elevation: 2,
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Daily Adherence Trend',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 20),
            StreamBuilder<List<MedicineRecord>>(
              stream: _firestoreService.getRecordsInRange(_selectedStartDate, _selectedEndDate),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return Center(child: CircularProgressIndicator());
                }

                final records = snapshot.data!;
                final dailyData = _calculateDailyAdherence(records);

                return SizedBox(
                  height: 200,
                  child: LineChart(
                    LineChartData(
                      gridData: FlGridData(show: true),
                      titlesData: FlTitlesData(
                        leftTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            reservedSize: 40,
                            getTitlesWidget: (value, meta) {
                              return Text('${value.toInt()}%');
                            },
                          ),
                        ),
                        bottomTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            getTitlesWidget: (value, meta) {
                              if (value.toInt() >= 0 && value.toInt() < dailyData.length) {
                                final date = dailyData[value.toInt()]['date'] as DateTime;
                                return Text(DateFormat('MM/dd').format(date));
                              }
                              return Text('');
                            },
                          ),
                        ),
                        rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                        topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      ),
                      borderData: FlBorderData(show: true),
                      minY: 0,
                      maxY: 100,
                      lineBarsData: [
                        LineChartBarData(
                          spots: dailyData
                              .asMap()
                              .entries
                              .map((entry) => FlSpot(
                                    entry.key.toDouble(),
                                    entry.value['rate'] as double,
                                  ))
                              .toList(),
                          isCurved: true,
                          color: Colors.deepOrange,
                          barWidth: 3,
                          dotData: FlDotData(show: true),
                          belowBarData: BarAreaData(
                            show: true,
                            color: Colors.deepOrange.withOpacity(0.3),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  List<Map<String, dynamic>> _calculateDailyAdherence(List<MedicineRecord> records) {
    final Map<String, List<MedicineRecord>> dailyRecords = {};
    final now = DateTime.now();
    
    for (var record in records) {
      // Only include past or today's records
      if (record.scheduledTime.isBefore(now) || 
          record.scheduledTime.day == now.day) {
        final dateKey = DateFormat('yyyy-MM-dd').format(record.scheduledTime);
        dailyRecords.putIfAbsent(dateKey, () => []).add(record);
      }
    }

    final result = <Map<String, dynamic>>[];
    for (var entry in dailyRecords.entries) {
      final date = DateTime.parse(entry.key);
      final recordsForDay = entry.value;
      final taken = recordsForDay.where((r) => r.status == 'completed').length;
      final total = recordsForDay.length;
      final rate = total > 0 ? (taken / total) * 100 : 0.0;

      result.add({
        'date': date,
        'rate': rate,
        'taken': taken,
        'total': total,
      });
    }

    result.sort((a, b) => (a['date'] as DateTime).compareTo(b['date'] as DateTime));
    return result;
  }

  Widget _buildDoseHistory() {
    return Card(
      elevation: 2,
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Recent History',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 12),
            StreamBuilder<List<MedicineRecord>>(
              stream: _firestoreService.getRecordsInRange(_selectedStartDate, _selectedEndDate),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return Center(child: CircularProgressIndicator());
                }

                // Filter and take first 10 inside the builder to ensure reactivity
                final allRecords = snapshot.data!;
                final records = allRecords.length > 10 ? allRecords.sublist(0, 10) : allRecords;

                if (records.isEmpty) {
                  return Padding(
                    padding: EdgeInsets.all(16),
                    child: Text('No records found'),
                  );
                }

                return ListView.separated(
                  shrinkWrap: true,
                  physics: NeverScrollableScrollPhysics(),
                  itemCount: records.length,
                  separatorBuilder: (context, index) => Divider(),
                  itemBuilder: (context, index) {
                    final record = records[index];
                    final dateFormat = DateFormat('MMM dd, hh:mm a');

                    // Determine icon and color based on status
                    IconData icon;
                    Color color;
                    String statusText;
                    
                    switch (record.status) {
                      case 'completed':
                        icon = Icons.check_circle;
                        color = Color(0xFF66BB6A);
                        statusText = 'Taken';
                        break;
                      case 'missed':
                        icon = Icons.cancel;
                        color = Color(0xFFE53935);
                        statusText = 'Missed';
                        break;
                      case 'overdue':
                        icon = Icons.error;
                        color = Color(0xFFFF9800);
                        statusText = 'Overdue';
                        break;
                      case 'upcoming':
                      default:
                        icon = Icons.schedule;
                        color = Color(0xFF1976D2);
                        statusText = 'Upcoming';
                        break;
                    }

                    return ListTile(
                      leading: Icon(icon, color: color),
                      title: Text('${record.medicineName} (Box ${record.boxNumber})'),
                      subtitle: Text(
                        '${record.medicineType} • ${dateFormat.format(record.scheduledTime)}',
                      ),
                      trailing: Text(
                        statusText,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: color,
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
