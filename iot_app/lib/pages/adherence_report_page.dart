import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import '../services/mongodb_service.dart';
import '../models/dose_record.dart'; // This is MedicineRecord

class AdherenceReportPage extends StatefulWidget {
  @override
  _AdherenceReportPageState createState() => _AdherenceReportPageState();
}

class _AdherenceReportPageState extends State<AdherenceReportPage> {
  final MongoDBService _mongoDBService = MongoDBService();

  DateTime _selectedStartDate = DateTime.now().subtract(Duration(days: 7));
  DateTime _selectedEndDate = DateTime.now();

  String _selectedPeriod = 'Last 7 Days';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: Text('Adherence Report')),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildPeriodSelector(),
            SizedBox(height: 20),
            _buildOverallStats(),
            SizedBox(height: 20),
            _buildDoseHistory(),
          ],
        ),
      ),
    );
  }

  Widget _buildPeriodSelector() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? Colors.grey[900] : Colors.grey[200];
    final borderColor = isDark ? Colors.grey[700] : Colors.grey[400];

    return Container(
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: borderColor!, width: 1),
      ),
      padding: EdgeInsets.all(4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Expanded(
            child: _buildPeriodButton(
              'Week',
              'Last 7 Days',
              _selectedPeriod == 'Last 7 Days',
            ),
          ),
          SizedBox(width: 4),
          Expanded(
            child: _buildPeriodButton(
              'Last 30 Days',
              'Last 30 Days',
              _selectedPeriod == 'Last 30 Days',
            ),
          ),
          SizedBox(width: 4),
          Expanded(
            child: _buildPeriodButton(
              'This Month',
              'This Month',
              _selectedPeriod == 'This Month',
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPeriodButton(String label, String period, bool isSelected) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final selectedBgColor = isDark ? Colors.grey[700] : Colors.grey[400];
    final selectedBorderColor = isDark ? Colors.grey[500] : Colors.grey[600];
    final unselectedTextColor = isDark ? Colors.grey[400] : Colors.grey[600];

    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedPeriod = period;
          if (period == 'Last 7 Days') {
            _selectedStartDate = DateTime.now().subtract(Duration(days: 7));
            _selectedEndDate = DateTime.now();
          } else if (period == 'Last 30 Days') {
            _selectedStartDate = DateTime.now().subtract(Duration(days: 30));
            _selectedEndDate = DateTime.now();
          } else if (period == 'This Month') {
            final now = DateTime.now();
            _selectedStartDate = DateTime(now.year, now.month, 1);
            _selectedEndDate = now;
          }
        });
      },
      child: Container(
        padding: EdgeInsets.symmetric(vertical: 12, horizontal: 12),
        decoration: BoxDecoration(
          color: isSelected ? selectedBgColor : Colors.transparent,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: isSelected ? selectedBorderColor! : Colors.transparent,
            width: 1,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: isSelected
                ? (isDark ? Colors.white : Colors.black87)
                : unselectedTextColor,
          ),
        ),
      ),
    );
  }

  Widget _buildOverallStats() {
    return StreamBuilder<List<MedicineRecord>>(
      stream: _mongoDBService.getRecordsInRangeStream(
        _selectedStartDate,
        _selectedEndDate,
      ),
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
        final pastRecords = records
            .where(
              (record) =>
                  record.scheduledTime.isBefore(now) ||
                  record.scheduledTime.day == now.day,
            )
            .toList();

        final total = pastRecords.length;
        final taken = pastRecords.where((r) => r.status == 'completed').length;
        final missed = pastRecords.where((r) => r.status == 'missed').length;
        final skipped = pastRecords.where((r) => r.status == 'overdue').length;
        final adherenceRate = total > 0 ? (taken / total) * 100 : 0.0;

        return Card(
          elevation: 4,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
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
                              color: Theme.of(context).primaryColor,
                            ),
                          ),
                          Text(
                            'Adherence',
                            style: TextStyle(
                              fontSize: 12,
                              color:
                                  Theme.of(context).brightness ==
                                      Brightness.dark
                                  ? Colors.grey[400]
                                  : Colors.grey[600],
                            ),
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
                    _buildStatColumn('Total', total, Color(0xFF1976D2), null),
                    _buildStatColumn(
                      'Taken',
                      taken,
                      Color(0xFF66BB6A),
                      Icons.check_circle,
                    ),
                    _buildStatColumn(
                      'Missed',
                      missed,
                      Color(0xFFE53935),
                      Icons.cancel,
                    ),
                    _buildStatColumn(
                      'Overdue',
                      skipped,
                      Color(0xFFFF9800),
                      Icons.warning,
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildStatColumn(
    String label,
    int value,
    Color color,
    IconData? icon,
  ) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Column(
      children: [
        if (icon != null)
          Icon(icon, color: color, size: 20)
        else
          Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
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
          style: TextStyle(
            fontSize: 12,
            color: isDark ? Colors.grey[400] : Colors.grey[600],
          ),
        ),
      ],
    );
  }

  Widget _buildDoseHistory() {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Recent History',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 16),
            StreamBuilder<List<MedicineRecord>>(
              stream: _mongoDBService.getRecordsInRangeStream(
                _selectedStartDate,
                _selectedEndDate,
              ),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return Center(child: CircularProgressIndicator());
                }

                // Get all records in range and sort by date descending
                final records = List<MedicineRecord>.from(snapshot.data!);
                records.sort(
                  (a, b) => b.scheduledTime.compareTo(a.scheduledTime),
                );

                if (records.isEmpty) {
                  return Padding(
                    padding: EdgeInsets.all(16),
                    child: Text('No records found'),
                  );
                }

                // Group records by date (yyyy-MM-dd)
                final Map<String, List<MedicineRecord>> grouped = {};
                for (final r in records) {
                  final key = DateFormat('yyyy-MM-dd').format(r.scheduledTime);
                  grouped.putIfAbsent(key, () => []).add(r);
                }

                // Sort date keys descending
                final sortedKeys = grouped.keys.toList()
                  ..sort(
                    (a, b) => DateTime.parse(b).compareTo(DateTime.parse(a)),
                  );

                return ListView.builder(
                  shrinkWrap: true,
                  physics: NeverScrollableScrollPhysics(),
                  itemCount: sortedKeys.length,
                  itemBuilder: (context, index) {
                    final key = sortedKeys[index];
                    final date = DateTime.parse(key);
                    final dayRecords = grouped[key]!;

                    // Calculate counts for this date
                    final takenCount = dayRecords
                        .where((r) => r.status == 'completed')
                        .length;
                    final missedCount = dayRecords
                        .where((r) => r.status == 'missed')
                        .length;
                    final overdueCount = dayRecords
                        .where((r) => r.status == 'overdue')
                        .length;
                    final upcomingCount = dayRecords
                        .where((r) => r.status == 'upcoming')
                        .length;

                    return Padding(
                      padding: EdgeInsets.only(bottom: 12),
                      child: Card(
                        elevation: 2,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Theme(
                          data: ThemeData(dividerColor: Colors.transparent),
                          child: ExpansionTile(
                            tilePadding: EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 4,
                            ),
                            childrenPadding: EdgeInsets.only(
                              left: 16,
                              right: 16,
                              bottom: 8,
                            ),
                            leading: Container(
                              width: 75,
                              height: 75,
                              decoration: BoxDecoration(
                                color: Theme.of(context).primaryColor,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    DateFormat('dd').format(date),
                                    style: TextStyle(
                                      fontSize: 22,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                      height: 1,
                                    ),
                                  ),
                                  Text(
                                    DateFormat('EEE').format(date),
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: Colors.white70,
                                      height: 1,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            title: Text(
                              DateFormat('MMMM d, y').format(date),
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                SizedBox(height: 2),
                                Wrap(
                                  spacing: 3,
                                  runSpacing: 1,
                                  children: [
                                    if (takenCount > 0)
                                      _buildStatusBadge(
                                        Icons.check_circle,
                                        takenCount,
                                        Color(0xFF4CAF50),
                                      ),
                                    if (overdueCount > 0)
                                      _buildStatusBadge(
                                        Icons.warning,
                                        overdueCount,
                                        Color(0xFFFF9800),
                                      ),
                                    if (upcomingCount > 0)
                                      _buildStatusBadge(
                                        Icons.access_time,
                                        upcomingCount,
                                        Color(0xFF2196F3),
                                      ),
                                    if (missedCount > 0)
                                      _buildStatusBadge(
                                        Icons.cancel,
                                        missedCount,
                                        Color(0xFFF44336),
                                      ),
                                  ],
                                ),
                                SizedBox(height: 1),
                                Text(
                                  '(${dayRecords.length} total)',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color:
                                        Theme.of(context).brightness ==
                                            Brightness.dark
                                        ? Colors.grey[400]
                                        : Colors.grey[600],
                                  ),
                                ),
                              ],
                            ),
                            children: dayRecords.map((record) {
                              final timeFormat = DateFormat('hh:mm a');

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
                                  icon = Icons.warning;
                                  color = Color(0xFFFF9800);
                                  statusText = 'Overdue';
                                  break;
                                case 'upcoming':
                                default:
                                  icon = Icons.access_time;
                                  color = Color(0xFF1976D2);
                                  statusText = 'Upcoming';
                                  break;
                              }

                              return Padding(
                                padding: EdgeInsets.symmetric(vertical: 8),
                                child: Row(
                                  children: [
                                    Icon(icon, color: color, size: 20),
                                    SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            '${record.medicineName} (Box ${record.boxNumber})',
                                            style: TextStyle(
                                              fontWeight: FontWeight.w600,
                                              fontSize: 14,
                                              color:
                                                  Theme.of(
                                                        context,
                                                      ).brightness ==
                                                      Brightness.dark
                                                  ? Colors.white
                                                  : Colors.black,
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                          SizedBox(height: 3),
                                          Text(
                                            '${record.medicineType} • ${timeFormat.format(record.scheduledTime)}',
                                            style: TextStyle(
                                              color:
                                                  Theme.of(
                                                        context,
                                                      ).brightness ==
                                                      Brightness.dark
                                                  ? Colors.grey[400]
                                                  : Colors.grey[600],
                                              fontSize: 12,
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ],
                                      ),
                                    ),
                                    Text(
                                      statusText,
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: color,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }).toList(),
                          ),
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

  Widget _buildStatusBadge(IconData icon, int count, Color color) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.2),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color, width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
          SizedBox(width: 4),
          Text(
            count.toString(),
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

