import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:googleapis/calendar/v3.dart' as calendar;

class RequestScreen extends StatelessWidget {
  final DateTime selectedDate;
  final List<calendar.Event> events;

  RequestScreen({
    super.key,
    required this.selectedDate,
    required this.events,
  });

  // 指定日付のイベントを取得
  List<calendar.Event> _getEventsForDay(DateTime day) {
    return events.where((event) {
      final start = event.start?.date ?? event.start?.dateTime?.toLocal();
      return start != null &&
          start.year == day.year &&
          start.month == day.month &&
          start.day == day.day;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    int? startHour;
    int? startMinute;
    int? endHour;
    int? endMinute;

    final formattedDate = DateFormat('yyyy年MM月dd日（E）', 'ja').format(selectedDate);

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: const Text(
          '候補日時を追加',
          style: TextStyle(
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
        backgroundColor: const Color(0xFF6366F1),
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
      ),
      body: StatefulBuilder(
        builder: (context, setState) {
          return SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 選択した日付カード
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF6366F1).withOpacity(0.3),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          '選択した日付',
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          formattedDate,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        flex: 1,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'その日の予定',
                              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 10),
                            ..._getEventsForDay(selectedDate).map((e) {
                              final dateTime = e.start?.dateTime?.toLocal();
                              final isAllDay = e.start?.date != null && e.start?.dateTime == null;
                              final summary = e.summary ?? 'タイトルなし';
                              final location = e.location;

                              return Container(
                                margin: const EdgeInsets.only(bottom: 8),
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF667eea).withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: const Color(0xFF667eea).withOpacity(0.3),
                                    width: 1,
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Container(
                                      width: 4,
                                      height: 40,
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF667eea),
                                        borderRadius: BorderRadius.circular(2),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            summary,
                                            style: const TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.w600,
                                              color: Color(0xFF2c3e50),
                                            ),
                                          ),
                                          if (dateTime != null || isAllDay)
                                            Text(
                                              dateTime != null
                                                  ? DateFormat('HH:mm').format(dateTime)
                                                  : '終日',
                                              style: TextStyle(
                                                fontSize: 14,
                                                color: Colors.grey[600],
                                              ),
                                            ),
                                          if (location != null && location.isNotEmpty)
                                            Row(
                                              children: [
                                                Icon(Icons.place,
                                                    size: 16, color: Colors.grey[700]),
                                                const SizedBox(width: 4),
                                                Expanded(
                                                  child: Text(
                                                    location,
                                                    style: TextStyle(
                                                      fontSize: 14,
                                                      color: Colors.grey[700],
                                                    ),
                                                    overflow: TextOverflow.ellipsis,
                                                  ),
                                                ),
                                              ],
                                            ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }).toList(),
                          ],
                        ),
                      ),

                      const SizedBox(width: 16),

                      // 右側カラム（開始・終了時刻）
                      Expanded(
                        flex: 1,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              '時刻を選択してください',
                              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 10),
                            _buildTimeSection(
                              context,
                              '開始時刻',
                              Icons.schedule,
                              startHour,
                              startMinute,
                              (hour) => setState(() => startHour = hour),
                              (minute) => setState(() => startMinute = minute),
                            ),
                            const SizedBox(height: 24),
                            _buildTimeSection(
                              context,
                              '終了時刻',
                              Icons.schedule_outlined,
                              endHour,
                              endMinute,
                              (hour) => setState(() => endHour = hour),
                              (minute) => setState(() => endMinute = minute),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 40),

                  // 追加ボタン
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton(
                      onPressed: () {
                        if (startHour != null &&
                            startMinute != null &&
                            endHour != null &&
                            endMinute != null) {
                          final startDateTime = DateTime(
                            selectedDate.year,
                            selectedDate.month,
                            selectedDate.day,
                            startHour!,
                            startMinute!,
                          );
                          final endDateTime = DateTime(
                            selectedDate.year,
                            selectedDate.month,
                            selectedDate.day,
                            endHour!,
                            endMinute!,
                          );
                          if (endDateTime.isAfter(startDateTime)) {
                            Navigator.pop(context, {
                              'start': startDateTime,
                              'end': endDateTime,
                            });
                          } else {
                            _showSnackBar(context, '終了時刻は開始時刻より後にしてください', Colors.red);
                          }
                        } else {
                          _showSnackBar(context, '開始・終了時刻をすべて選択してください', Colors.orange);
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF667eea),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.add_circle_outline),
                          SizedBox(width: 8),
                          Text(
                            '候補日として追加',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildTimeSection(
    BuildContext context,
    String title,
    IconData icon,
    int? selectedHour,
    int? selectedMinute,
    void Function(int?) onHourChanged,
    void Function(int?) onMinuteChanged,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, color: const Color(0xFF6366F1), size: 20),
            const SizedBox(width: 8),
            Text(title,
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildDropdownField(
                context,
                '時間',
                selectedHour,
                List.generate(13, (i) {
                  final hour = 9 + i;
                  return DropdownMenuItem(value: hour, child: Text('$hour'));
                }),
                onHourChanged,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _buildDropdownField(
                context,
                '分',
                selectedMinute,
                const [
                  DropdownMenuItem(value: 0, child: Text('00')),
                  DropdownMenuItem(value: 15, child: Text('15')),
                  DropdownMenuItem(value: 30, child: Text('30')),
                  DropdownMenuItem(value: 45, child: Text('45')),
                ],
                onMinuteChanged,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildDropdownField<T>(
    BuildContext context,
    String label,
    T? value,
    List<DropdownMenuItem<T>> items,
    void Function(T?) onChanged,
  ) {
    return DropdownButtonFormField<T>(
      value: value,
      items: items,
      onChanged: onChanged,
      decoration: InputDecoration(
        labelText: label,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      ),
    );
  }

  void _showSnackBar(BuildContext context, String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(color == Colors.red ? Icons.error : Icons.warning, color: Colors.white),
            const SizedBox(width: 8),
            Text(message),
          ],
        ),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }
}
