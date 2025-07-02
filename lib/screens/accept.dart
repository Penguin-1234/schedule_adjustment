import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart';
import 'package:intl/intl.dart';
import 'package:googleapis/calendar/v3.dart' as calendar;
import 'home_screen.dart';

class AcceptScreen extends StatefulWidget {
  final List<DateTimeRange> busyRanges;
  final List<calendar.Event> allEvents; // 追加：全イベント情報
  final String? initialText;

  const AcceptScreen({
    super.key,
    required this.busyRanges,
    this.allEvents = const [], // 追加
    this.initialText,
  });

  @override
  State<AcceptScreen> createState() => _AcceptScreenState();
}

class _AcceptScreenState extends State<AcceptScreen>
    with AutomaticKeepAliveClientMixin {
  late final TextEditingController _textController;
  List<DateTimeRange> _availableDates = [];
  Set<DateTimeRange> _selectedDates = {};

  // 追加: 分割単位
  Duration _slotDuration = const Duration(hours: 1);

  @override
  void initState() {
    super.initState();
    _textController = TextEditingController(text: widget.initialText ?? '');
  }

  /// 候補日テキストを解析（例: 10月8日(火)16:00~17:00）
  List<DateTimeRange> parseCandidateText(String text) {
    final regex = RegExp(
      r'(\d{1,2})月(\d{1,2})日（.\）(\d{1,2}):(\d{2})~(\d{1,2}):(\d{2})',
    );
    final now = DateTime.now();
    final year = now.year;

    final matches = regex.allMatches(text);
    return matches.map((m) {
      final month = int.parse(m.group(1)!);
      final day = int.parse(m.group(2)!);
      final startHour = int.parse(m.group(3)!);
      final startMinute = int.parse(m.group(4)!);
      final endHour = int.parse(m.group(5)!);
      final endMinute = int.parse(m.group(6)!);

      final start = DateTime(year, month, day, startHour, startMinute);
      final end = DateTime(year, month, day, endHour, endMinute);

      return DateTimeRange(start: start, end: end);
    }).toList();
  }

  /// 任意の分割単位でスロットを生成
  List<DateTimeRange> _generateSlots(
    DateTimeRange range,
    Duration slotDuration,
  ) {
    List<DateTimeRange> slots = [];
    DateTime current = range.start;
    while (current.add(slotDuration).isBefore(range.end) ||
        current.add(slotDuration).isAtSameMomentAs(range.end)) {
      final slotEnd = current.add(slotDuration);
      slots.add(DateTimeRange(start: current, end: slotEnd));
      current = slotEnd;
    }
    return slots;
  }

  /// 空いている候補日を分割単位ごとに抽出
  void _parseAndFilter() {
    final text = _textController.text;
    final candidates = parseCandidateText(text);

    List<DateTimeRange> available = [];
    for (final candidate in candidates) {
      final slots = _generateSlots(candidate, _slotDuration);
      for (final slot in slots) {
        final freeRanges = subtractBusyRanges(slot, widget.busyRanges);
        available.addAll(freeRanges);
      }
    }

    setState(() {
      _availableDates = available;
      _selectedDates.clear();
    });
  }

  /// 曜日ラベル
  String _weekdayLabel(int weekday) {
    const labels = ['月', '火', '水', '木', '金', '土', '日'];
    return labels[(weekday - 1) % 7];
  }

  /// 指定日の予定を取得
  List<calendar.Event> _getEventsForDay(DateTime day) {
    return widget.allEvents.where((event) {
      final eventStart = event.start?.dateTime?.toLocal() ?? event.start?.date;
      if (eventStart == null) return false;

      return eventStart.year == day.year &&
          eventStart.month == day.month &&
          eventStart.day == day.day;
    }).toList();
  }

  /// 候補日時間帯と重なる予定を取得
  List<calendar.Event> _getConflictingEvents(DateTimeRange range) {
    return widget.allEvents.where((event) {
      final eventStart = event.start?.dateTime?.toLocal();
      final eventEnd = event.end?.dateTime?.toLocal();

      if (eventStart == null || eventEnd == null) return false;

      // 時間帯の重複チェック
      return range.start.isBefore(eventEnd) && eventStart.isBefore(range.end);
    }).toList();
  }

  /// 改良版予定確認ダイアログ
  void _showScheduleDialog(DateTimeRange range) {
    final dayEvents = _getEventsForDay(range.start);
    final conflictingEvents = _getConflictingEvents(range);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          '${range.start.month}月${range.start.day}日（${_weekdayLabel(range.start.weekday)}）の予定確認',
        ),
        content: SizedBox(
          width: 400,
          height: 500,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 候補時間帯の表示
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.blue.shade200),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '候補時間帯',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${DateFormat('HH:mm').format(range.start)} ～ ${DateFormat('HH:mm').format(range.end)}',
                      style: const TextStyle(fontSize: 18, color: Colors.blue),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // 重複する予定があるかの表示
              if (conflictingEvents.isNotEmpty) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.red.shade200),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.warning, color: Colors.red, size: 20),
                          SizedBox(width: 4),
                          Text(
                            '時間が重複する予定',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.red,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      ...conflictingEvents.map((event) {
                        final start = event.start?.dateTime?.toLocal();
                        final end = event.end?.dateTime?.toLocal();
                        final timeStr = start != null && end != null
                            ? '${DateFormat('HH:mm').format(start)}-${DateFormat('HH:mm').format(end)}'
                            : '終日';
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 4),
                          child: Text(
                            '• $timeStr ${event.summary ?? 'タイトルなし'}',
                            style: const TextStyle(
                              color: Colors.red,
                              fontSize: 12,
                            ),
                          ),
                        );
                      }),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ] else ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.green.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.green.shade200),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.check_circle, color: Colors.green, size: 20),
                      SizedBox(width: 4),
                      Text(
                        'この時間帯は空いています',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.green,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],

              // その日の全予定表示
              const Text(
                'この日の全予定',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: dayEvents.isEmpty
                    ? const Text(
                        '予定はありません',
                        style: TextStyle(color: Colors.grey),
                      )
                    : ListView.builder(
                        itemCount: dayEvents.length,
                        itemBuilder: (context, index) {
                          final event = dayEvents[index];
                          final start = event.start?.dateTime?.toLocal();
                          final end = event.end?.dateTime?.toLocal();
                          final isAllDay =
                              event.start?.date != null &&
                              event.start?.dateTime == null;

                          String timeStr;
                          if (isAllDay) {
                            timeStr = '終日';
                          } else if (start != null && end != null) {
                            timeStr =
                                '${DateFormat('HH:mm').format(start)}-${DateFormat('HH:mm').format(end)}';
                          } else {
                            timeStr = '時刻不明';
                          }

                          // 重複チェック
                          final isConflicting = conflictingEvents.contains(
                            event,
                          );

                          return Container(
                            margin: const EdgeInsets.only(bottom: 4),
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: isConflicting
                                  ? Colors.red.shade100
                                  : Colors.grey.shade100,
                              borderRadius: BorderRadius.circular(4),
                              border: isConflicting
                                  ? Border.all(color: Colors.red.shade300)
                                  : null,
                            ),
                            child: Row(
                              children: [
                                if (isConflicting)
                                  const Icon(
                                    Icons.warning,
                                    color: Colors.red,
                                    size: 16,
                                  ),
                                if (isConflicting) const SizedBox(width: 4),
                                Expanded(
                                  child: Text(
                                    '$timeStr ${event.summary ?? 'タイトルなし'}',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: isConflicting
                                          ? Colors.red.shade700
                                          : Colors.black87,
                                    ),
                                  ),
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
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('閉じる'),
          ),
          if (conflictingEvents.isEmpty)
            ElevatedButton(
              onPressed: () {
                setState(() {
                  _selectedDates.add(range);
                });
                Navigator.pop(context);
                ScaffoldMessenger.of(
                  context,
                ).showSnackBar(const SnackBar(content: Text('候補日として選択しました')));
              },
              child: const Text('この時間で確定'),
            ),
        ],
      ),
    );
  }

  /// ビジータイムと重ならない空き時間を計算
  List<DateTimeRange> subtractBusyRanges(
    DateTimeRange candidate,
    List<DateTimeRange> busyRanges,
  ) {
    final overlaps = busyRanges
        .where(
          (busy) =>
              candidate.start.isBefore(busy.end) &&
              busy.start.isBefore(candidate.end),
        )
        .toList();

    if (overlaps.isEmpty) return [candidate];

    overlaps.sort((a, b) => a.start.compareTo(b.start));

    List<DateTimeRange> result = [];
    DateTime currentStart = candidate.start;

    for (final busy in overlaps) {
      if (currentStart.isBefore(busy.start)) {
        final freeRange = DateTimeRange(start: currentStart, end: busy.start);
        // 1時間ごとのスロットなので、最低1時間の条件を削除
        result.add(freeRange);
      }
      if (currentStart.isBefore(busy.end)) {
        currentStart = busy.end;
      }
    }

    if (currentStart.isBefore(candidate.end)) {
      final freeRange = DateTimeRange(start: currentStart, end: candidate.end);
      result.add(freeRange);
    }

    return result;
  }

  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Scaffold(
      appBar: AppBar(title: const Text('候補日を貼り付け')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            const Text("候補日をテキストで貼り付けてください："),
            const SizedBox(height: 8),
            TextField(
              controller: _textController,
              maxLines: 6,
              decoration: const InputDecoration(
                hintText: '例:\n10月8日（火）16:00~17:00\n10月20日（火）16:00~17:00',
                hintStyle: TextStyle(
                  color: Colors.grey,
                  fontSize: 14,
                  fontWeight: FontWeight.normal,
                ),
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            // 追加: 分割単位選択UI
            Row(
              children: [
                const Text('分割単位:'),
                const SizedBox(width: 8),
                DropdownButton<Duration>(
                  value: _slotDuration,
                  items: const [
                    DropdownMenuItem(
                      value: Duration(minutes: 30),
                      child: Text('30分ごと'),
                    ),
                    DropdownMenuItem(
                      value: Duration(hours: 1),
                      child: Text('1時間ごと'),
                    ),
                  ],
                  onChanged: (value) {
                    if (value != null) {
                      setState(() {
                        _slotDuration = value;
                      });
                    }
                  },
                ),
              ],
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _parseAndFilter,
              child: const Text('空いている候補日を確認'),
            ),
            const SizedBox(height: 16),
            if (_availableDates.isNotEmpty)
              Expanded(
                child: Column(
                  children: [
                    Expanded(
                      child: ListView.builder(
                        itemCount: _availableDates.length,
                        itemBuilder: (context, index) {
                          final range = _availableDates[index];
                          final selected = _selectedDates.contains(range);
                          final conflictingEvents = _getConflictingEvents(
                            range,
                          );
                          final hasConflict = conflictingEvents.isNotEmpty;

                          return Card(
                            elevation: 2,
                            margin: const EdgeInsets.only(bottom: 8),
                            child: ListTile(
                              leading: Checkbox(
                                value: selected,
                                onChanged: (checked) {
                                  setState(() {
                                    if (checked == true) {
                                      _selectedDates.add(range);
                                    } else {
                                      _selectedDates.remove(range);
                                    }
                                  });
                                },
                              ),
                              title: Text(
                                '${range.start.month}月${range.start.day}日（${_weekdayLabel(range.start.weekday)}）'
                                ' ${range.start.hour}:${range.start.minute.toString().padLeft(2, '0')}~'
                                '${range.end.hour}:${range.end.minute.toString().padLeft(2, '0')}',
                              ),
                              subtitle: hasConflict
                                  ? Text(
                                      '⚠️ ${conflictingEvents.length}件の予定と重複',
                                      style: const TextStyle(color: Colors.red),
                                    )
                                  : const Text(
                                      '✅ 空いています',
                                      style: TextStyle(color: Colors.green),
                                    ),
                              trailing: ElevatedButton(
                                onPressed: () => _showScheduleDialog(range),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: hasConflict
                                      ? Colors.red.shade100
                                      : Colors.blue.shade100,
                                ),
                                child: const Text('予定を確認'),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    ElevatedButton.icon(
                      icon: const Icon(Icons.copy),
                      label: const Text('チェックした候補日をコピー'),
                      onPressed: _selectedDates.isEmpty
                          ? null
                          : () {
                              final text = _selectedDates
                                  .map(
                                    (range) =>
                                        '${range.start.month}月${range.start.day}日（${_weekdayLabel(range.start.weekday)}）'
                                        '${range.start.hour}:${range.start.minute.toString().padLeft(2, '0')}~'
                                        '${range.end.hour}:${range.end.minute.toString().padLeft(2, '0')}',
                                  )
                                  .join('\n');
                              Clipboard.setData(ClipboardData(text: text));
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('チェックした候補日をコピーしました'),
                                ),
                              );
                            },
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
