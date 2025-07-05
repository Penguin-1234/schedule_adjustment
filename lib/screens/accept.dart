import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart';
import 'package:intl/intl.dart';
import 'package:googleapis/calendar/v3.dart' as calendar;
import 'home_screen.dart';

class AcceptScreen extends StatefulWidget {
  final List<DateTimeRange> busyRanges;
  final List<calendar.Event> allEvents;
  final String? initialText;

  const AcceptScreen({
    super.key,
    required this.busyRanges,
    this.allEvents = const [],
    this.initialText,
  });

  @override
  State<AcceptScreen> createState() => _AcceptScreenState();
}

class _AcceptScreenState extends State<AcceptScreen>
    with AutomaticKeepAliveClientMixin, TickerProviderStateMixin {
  late final TextEditingController _textController;
  late final AnimationController _fadeController;
  late final AnimationController _slideController;
  late final Animation<double> _fadeAnimation;
  late final Animation<Offset> _slideAnimation;

  List<DateTimeRange> _availableDates = [];
  Set<DateTimeRange> _selectedDates = {};
  Duration _slotDuration = const Duration(hours: 1);
  bool _isAnalyzing = false;

  @override
  void initState() {
    super.initState();
    _textController = TextEditingController(text: widget.initialText ?? '');

    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _slideController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _fadeController, curve: Curves.easeInOut),
    );
    _slideAnimation =
        Tween<Offset>(begin: const Offset(0, 0.3), end: Offset.zero).animate(
          CurvedAnimation(parent: _slideController, curve: Curves.easeOutQuart),
        );
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _slideController.dispose();
    super.dispose();
  }

  /// 候補日テキストを解析
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

  /// スロット生成
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
  void _parseAndFilter() async {
    setState(() {
      _isAnalyzing = true;
    });

    // アニメーション効果のために少し待機
    await Future.delayed(const Duration(milliseconds: 500));

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
      _isAnalyzing = false;
    });

    if (available.isNotEmpty) {
      _fadeController.forward();
      _slideController.forward();
    }
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

      return range.start.isBefore(eventEnd) && eventStart.isBefore(range.end);
    }).toList();
  }

  /// スタイリッシュな予定確認ダイアログ
  void _showScheduleDialog(DateTimeRange range) {
    final dayEvents = _getEventsForDay(range.start);
    final conflictingEvents = _getConflictingEvents(range);

    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        elevation: 10,
        child: Container(
          width: 450,
          height: 600,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Colors.white, Colors.grey.shade50],
            ),
          ),
          child: Column(
            children: [
              // ヘッダー部分
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(20),
                    topRight: Radius.circular(20),
                  ),
                  gradient: LinearGradient(
                    colors: [Colors.indigo.shade600, Colors.indigo.shade400],
                  ),
                ),
                child: Row(
                  children: [
                    Icon(Icons.event, color: Colors.white, size: 28),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        '${range.start.month}月${range.start.day}日（${_weekdayLabel(range.start.weekday)}）',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close, color: Colors.white),
                    ),
                  ],
                ),
              ),

              // コンテンツ部分
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 候補時間帯
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [Colors.blue.shade50, Colors.blue.shade100],
                          ),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.blue.shade200),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.access_time,
                              color: Colors.blue.shade700,
                            ),
                            const SizedBox(width: 12),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '候補時間帯',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w600,
                                    color: Colors.blue.shade700,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '${DateFormat('HH:mm').format(range.start)} ～ ${DateFormat('HH:mm').format(range.end)}',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.blue.shade800,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),

                      // 重複チェック結果
                      if (conflictingEvents.isNotEmpty) ...[
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [Colors.red.shade50, Colors.red.shade100],
                            ),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.red.shade200),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(
                                    Icons.warning_rounded,
                                    color: Colors.red.shade600,
                                    size: 24,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    '時間重複あり',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: Colors.red.shade700,
                                      fontSize: 16,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              ...conflictingEvents.map((event) {
                                final start = event.start?.dateTime?.toLocal();
                                final end = event.end?.dateTime?.toLocal();
                                final timeStr = start != null && end != null
                                    ? '${DateFormat('HH:mm').format(start)}-${DateFormat('HH:mm').format(end)}'
                                    : '終日';
                                return Container(
                                  margin: const EdgeInsets.only(bottom: 8),
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Row(
                                    children: [
                                      Container(
                                        width: 4,
                                        height: 20,
                                        decoration: BoxDecoration(
                                          color: Colors.red.shade400,
                                          borderRadius: BorderRadius.circular(
                                            2,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          '$timeStr ${event.summary ?? 'タイトルなし'}',
                                          style: TextStyle(
                                            color: Colors.red.shade700,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              }),
                            ],
                          ),
                        ),
                      ] else ...[
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                Colors.green.shade50,
                                Colors.green.shade100,
                              ],
                            ),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.green.shade200),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.check_circle_rounded,
                                color: Colors.green.shade600,
                                size: 24,
                              ),
                              const SizedBox(width: 12),
                              Text(
                                'この時間帯は空いています',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.green.shade700,
                                  fontSize: 16,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                      const SizedBox(height: 20),

                      // その日の全予定
                      Text(
                        'この日の全予定',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: Colors.grey.shade800,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Expanded(
                        child: dayEvents.isEmpty
                            ? Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.event_available,
                                      color: Colors.grey.shade400,
                                      size: 48,
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      '予定はありません',
                                      style: TextStyle(
                                        color: Colors.grey.shade600,
                                      ),
                                    ),
                                  ],
                                ),
                              )
                            : ListView.builder(
                                itemCount: dayEvents.length,
                                itemBuilder: (context, index) {
                                  final event = dayEvents[index];
                                  final start = event.start?.dateTime
                                      ?.toLocal();
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

                                  final isConflicting = conflictingEvents
                                      .contains(event);

                                  return Container(
                                    margin: const EdgeInsets.only(bottom: 8),
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: isConflicting
                                          ? Colors.red.shade50
                                          : Colors.white,
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(
                                        color: isConflicting
                                            ? Colors.red.shade200
                                            : Colors.grey.shade200,
                                      ),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.grey.withOpacity(0.1),
                                          blurRadius: 4,
                                          offset: const Offset(0, 2),
                                        ),
                                      ],
                                    ),
                                    child: Row(
                                      children: [
                                        Container(
                                          width: 4,
                                          height: 24,
                                          decoration: BoxDecoration(
                                            color: isConflicting
                                                ? Colors.red.shade400
                                                : Colors.blue.shade400,
                                            borderRadius: BorderRadius.circular(
                                              2,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        if (isConflicting) ...[
                                          Icon(
                                            Icons.warning_rounded,
                                            color: Colors.red.shade600,
                                            size: 16,
                                          ),
                                          const SizedBox(width: 4),
                                        ],
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                event.summary ?? 'タイトルなし',
                                                style: TextStyle(
                                                  fontWeight: FontWeight.w600,
                                                  color: isConflicting
                                                      ? Colors.red.shade700
                                                      : Colors.grey.shade800,
                                                ),
                                              ),
                                              Text(
                                                timeStr,
                                                style: TextStyle(
                                                  fontSize: 12,
                                                  color: isConflicting
                                                      ? Colors.red.shade600
                                                      : Colors.grey.shade600,
                                                ),
                                              ),
                                            ],
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
              ),

              // アクションボタン
              if (conflictingEvents.isEmpty)
                Container(
                  padding: const EdgeInsets.all(24),
                  child: SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () {
                        setState(() {
                          _selectedDates.add(range);
                        });
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: const Text('候補日として選択しました'),
                            backgroundColor: Colors.green.shade600,
                            behavior: SnackBarBehavior.floating,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.indigo.shade600,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 4,
                      ),
                      child: const Text(
                        'この時間で確定',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
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
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: const Text(
          '候補日を貼り付け',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.indigo.shade600,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.indigo.shade600.withOpacity(0.1), Colors.white],
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ヘッダーセクション
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.grey.withOpacity(0.1),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.content_paste,
                            color: Colors.indigo.shade600,
                            size: 24,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            "候補日をテキストで貼り付けてください",
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: Colors.grey.shade800,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.grey.shade300),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.grey.withOpacity(0.05),
                              blurRadius: 4,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: TextField(
                          controller: _textController,
                          maxLines: 5,
                          style: const TextStyle(fontSize: 14),
                          decoration: InputDecoration(
                            hintText:
                                '例:\n10月8日（火）16:00~17:00\n10月20日（火）16:00~17:00',
                            hintStyle: TextStyle(
                              color: Colors.grey.shade500,
                              fontSize: 13,
                            ),
                            border: InputBorder.none,
                            contentPadding: const EdgeInsets.all(16),
                            filled: true,
                            fillColor: Colors.grey.shade50,
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),

                      // 分割単位選択
                      Row(
                        children: [
                          Icon(
                            Icons.schedule,
                            color: Colors.indigo.shade600,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '分割単位:',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              color: Colors.grey.shade700,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.indigo.shade50,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.indigo.shade200),
                            ),
                            child: DropdownButtonHideUnderline(
                              child: DropdownButton<Duration>(
                                value: _slotDuration,
                                style: TextStyle(
                                  color: Colors.indigo.shade700,
                                  fontWeight: FontWeight.w500,
                                ),
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
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),

                      // 解析ボタン
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _isAnalyzing ? null : _parseAndFilter,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.indigo.shade600,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            elevation: 4,
                          ),
                          child: _isAnalyzing
                              ? Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        valueColor:
                                            AlwaysStoppedAnimation<Color>(
                                              Colors.white,
                                            ),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    const Text('解析中...'),
                                  ],
                                )
                              : Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    const Icon(Icons.search, size: 20),
                                    const SizedBox(width: 8),
                                    const Text(
                                      '空いている候補日を確認',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // 結果表示セクション
                if (_availableDates.isNotEmpty)
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.grey.withOpacity(0.1),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: Colors.indigo.shade50,
                            borderRadius: const BorderRadius.only(
                              topLeft: Radius.circular(16),
                              topRight: Radius.circular(16),
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.event_available,
                                color: Colors.indigo.shade600,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                '空いている候補日 (${_availableDates.length}件)',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.indigo.shade700,
                                ),
                              ),
                            ],
                          ),
                        ),
                        // ↓ Expanded/ListViewをやめてColumn＋mapで表示
                        ..._availableDates.map((range) {
                          final selected = _selectedDates.contains(range);
                          final conflictingEvents = _getConflictingEvents(
                            range,
                          );
                          final hasConflict = conflictingEvents.isNotEmpty;
                          return Container(
                            margin: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: selected
                                  ? Colors.indigo.shade50
                                  : Colors.white,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: selected
                                    ? Colors.indigo.shade300
                                    : Colors.grey.shade200,
                                width: selected ? 2 : 1,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.grey.withOpacity(0.08),
                                  blurRadius: 6,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: ListTile(
                              contentPadding: const EdgeInsets.all(16),
                              leading: Container(
                                width: 24,
                                height: 24,
                                decoration: BoxDecoration(
                                  color: selected
                                      ? Colors.indigo.shade600
                                      : Colors.transparent,
                                  border: Border.all(
                                    color: selected
                                        ? Colors.indigo.shade600
                                        : Colors.grey.shade400,
                                    width: 2,
                                  ),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: selected
                                    ? const Icon(
                                        Icons.check,
                                        color: Colors.white,
                                        size: 16,
                                      )
                                    : null,
                              ),
                              title: Text(
                                '${range.start.month}月${range.start.day}日（${_weekdayLabel(range.start.weekday)}）',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.grey.shade800,
                                  fontSize: 16,
                                ),
                              ),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const SizedBox(height: 4),
                                  Text(
                                    '${range.start.hour}:${range.start.minute.toString().padLeft(2, '0')} ～ '
                                    '${range.end.hour}:${range.end.minute.toString().padLeft(2, '0')}',
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: Colors.indigo.shade600,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color: hasConflict
                                          ? Colors.red.shade100
                                          : Colors.green.shade100,
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          hasConflict
                                              ? Icons.warning_rounded
                                              : Icons.check_circle_rounded,
                                          color: hasConflict
                                              ? Colors.red.shade600
                                              : Colors.green.shade600,
                                          size: 16,
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          hasConflict
                                              ? '${conflictingEvents.length}件の予定と重複'
                                              : '空いています',
                                          style: TextStyle(
                                            color: hasConflict
                                                ? Colors.red.shade700
                                                : Colors.green.shade700,
                                            fontSize: 12,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              trailing: Container(
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: hasConflict
                                        ? [
                                            Colors.red.shade400,
                                            Colors.red.shade600,
                                          ]
                                        : [
                                            Colors.blue.shade400,
                                            Colors.blue.shade600,
                                          ],
                                  ),
                                  borderRadius: BorderRadius.circular(8),
                                  boxShadow: [
                                    BoxShadow(
                                      color:
                                          (hasConflict
                                                  ? Colors.red
                                                  : Colors.blue)
                                              .withOpacity(0.3),
                                      blurRadius: 4,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: ElevatedButton(
                                  onPressed: () => _showScheduleDialog(range),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.transparent,
                                    foregroundColor: Colors.white,
                                    shadowColor: Colors.transparent,
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 8,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(Icons.visibility, size: 16),
                                      const SizedBox(width: 4),
                                      const Text(
                                        '確認',
                                        style: TextStyle(fontSize: 12),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              onTap: () {
                                setState(() {
                                  if (selected) {
                                    _selectedDates.remove(range);
                                  } else {
                                    _selectedDates.add(range);
                                  }
                                });
                              },
                            ),
                          );
                        }).toList(),
                        // コピーボタン
                        Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade50,
                            borderRadius: const BorderRadius.only(
                              bottomLeft: Radius.circular(16),
                              bottomRight: Radius.circular(16),
                            ),
                          ),
                          child: SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              icon: const Icon(Icons.content_copy, size: 20),
                              label: Text(
                                _selectedDates.isEmpty
                                    ? 'まず候補日を選択してください'
                                    : 'チェックした候補日をコピー (${_selectedDates.length}件)',
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
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
                                      Clipboard.setData(
                                        ClipboardData(text: text),
                                      );
                                      ScaffoldMessenger.of(
                                        context,
                                      ).showSnackBar(
                                        SnackBar(
                                          content: Row(
                                            children: [
                                              const Icon(
                                                Icons.check_circle,
                                                color: Colors.white,
                                              ),
                                              const SizedBox(width: 8),
                                              Text(
                                                '${_selectedDates.length}件の候補日をコピーしました',
                                              ),
                                            ],
                                          ),
                                          backgroundColor:
                                              Colors.green.shade600,
                                          behavior: SnackBarBehavior.floating,
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(
                                              12,
                                            ),
                                          ),
                                          margin: const EdgeInsets.all(16),
                                        ),
                                      );
                                    },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: _selectedDates.isEmpty
                                    ? Colors.grey.shade300
                                    : Colors.indigo.shade600,
                                foregroundColor: _selectedDates.isEmpty
                                    ? Colors.grey.shade600
                                    : Colors.white,
                                padding: const EdgeInsets.symmetric(
                                  vertical: 16,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                elevation: _selectedDates.isEmpty ? 0 : 4,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
