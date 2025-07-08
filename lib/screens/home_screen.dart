import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis/calendar/v3.dart' as calendar;
import 'package:http/http.dart' as http;
import 'package:table_calendar/table_calendar.dart';
import 'package:intl/intl.dart';
import 'request.dart';
import 'accept.dart';
import 'package:flutter/services.dart';

class HomeScreen extends StatefulWidget {
  final DateTime? initialFocusedDate;
  final bool returnToAcceptScreen;
  const HomeScreen({
    super.key,
    this.initialFocusedDate,
    this.returnToAcceptScreen = false,
  });
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _googleSignIn = GoogleSignIn(
    clientId:
        '16377062047-50b4rls0t69va77f5df7cafiskp7e90q.apps.googleusercontent.com',
    scopes: ['email', 'https://www.googleapis.com/auth/calendar.readonly'],
  );

  Map<DateTime, List<calendar.Event>> _eventsMap = {};
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;
  bool _isSignedIn = false;
  
  @override
  void initState() {
    super.initState();
    if (widget.initialFocusedDate != null) {
      _focusedDay = widget.initialFocusedDate!;
      _selectedDay = widget.initialFocusedDate!;
    }
  }

  List<Map<String, DateTime>> _candidates = [];
  String? _lastCandidateText;

  Future<void> _signInAndFetchEvents() async {
    await _googleSignIn.signOut();

    final account = await _googleSignIn.signIn();
    final authHeaders = await account?.authHeaders;
    if (authHeaders == null) {
      throw Exception('認証ヘッダーの取得に失敗しました');
    }

    final client = GoogleAuthClient(authHeaders);
    final calendarApi = calendar.CalendarApi(client);

    final now = DateTime.now().toUtc();
    final start = now.subtract(const Duration(days: 60));

    final events = await calendarApi.events.list(
      'primary',
      timeMin: start,
      maxResults: 100,
      singleEvents: true,
      orderBy: 'startTime',
    );

    final Map<DateTime, List<calendar.Event>> eventsMap = {};
    for (final e in events.items ?? []) {
      final dateTime = e.start?.dateTime ?? e.start?.date;
      if (dateTime == null) continue;
      final date = DateTime(dateTime.year, dateTime.month, dateTime.day);
      eventsMap[date] = [...(eventsMap[date] ?? []), e];
    }

    setState(() {
      _eventsMap = eventsMap;
      _isSignedIn = true;
    });
  }

  List<calendar.Event> _getEventsForDay(DateTime day) {
    return _eventsMap[DateTime(day.year, day.month, day.day)] ?? [];
  }

  @override
  Widget build(BuildContext context) {
    if (!_isSignedIn) {
      return Scaffold(
        body: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color(0xFF667eea),
                Color(0xFF764ba2),
              ],
            ),
          ),
          child: Row(
            children: [
              // 左：デザインエリア
              Expanded(
                flex: 1,
                child: Container(
                  padding: const EdgeInsets.all(40),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(30),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: Colors.white.withOpacity(0.3),
                            width: 1,
                          ),
                        ),
                        child: Icon(
                          Icons.calendar_month_rounded,
                          size: 120,
                          color: Colors.white.withOpacity(0.8),
                        ),
                      ),
                      const SizedBox(height: 30),
                      Text(
                        'Smart Calendar\nManagement',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.w300,
                          color: Colors.white.withOpacity(0.9),
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              // 右：ログインUI
              Expanded(
                flex: 1,
                child: Container(
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(40),
                      bottomLeft: Radius.circular(40),
                    ),
                  ),
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.all(60),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              color: const Color(0xFF667eea).withOpacity(0.1),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Icon(
                              Icons.person_rounded,
                              size: 50,
                              color: const Color(0xFF667eea),
                            ),
                          ),
                          const SizedBox(height: 30),
                          const Text(
                            'Welcome Back',
                            style: TextStyle(
                              fontSize: 32,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF2c3e50),
                            ),
                          ),
                          const SizedBox(height: 10),
                          Text(
                            'カレンダーを同期してスケジュールを管理しましょう',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 16,
                              color: Colors.grey[600],
                              height: 1.5,
                            ),
                          ),
                          const SizedBox(height: 40),
                          Container(
                            width: double.infinity,
                            height: 60,
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [Color(0xFF667eea), Color(0xFF764ba2)],
                              ),
                              borderRadius: BorderRadius.circular(30),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(0xFF667eea).withOpacity(0.3),
                                  blurRadius: 20,
                                  offset: const Offset(0, 10),
                                ),
                              ],
                            ),
                            child: ElevatedButton.icon(
                              onPressed: _signInAndFetchEvents,
                              icon: const Icon(Icons.login_rounded, size: 24),
                              label: const Text(
                                'Googleでログイン',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.transparent,
                                foregroundColor: Colors.white,
                                elevation: 0,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(30),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.transparent,
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF667eea), Color(0xFF764ba2)],
            ),
          ),
        ),
        title: const Text(
          'Calendar Management',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 22,
          ),
        ),
        leading: widget.returnToAcceptScreen
            ? IconButton(
                icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white),
                onPressed: () => Navigator.pop(context),
              )
            : null,
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 16),
            child: TextButton(
              style: ButtonStyle(
                backgroundColor: MaterialStateProperty.resolveWith<Color?>((states) {
                  if (states.contains(MaterialState.hovered)) {
                    return Colors.white.withOpacity(0.2); // ホバー時の背景
                  }
                  return Colors.transparent; // 通常時の背景
                }),
                foregroundColor: MaterialStateProperty.resolveWith<Color?>((states) {
                  if (states.contains(MaterialState.hovered)) {
                    return Colors.white; // ホバー時の文字色
                  }
                  return Colors.white; // 通常時の文字色
                }),

                padding: MaterialStateProperty.all(
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 8)
                ),
                shape: MaterialStateProperty.all(
                  RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),side: const BorderSide(
                      color: Colors.white, // フレームの色
                      width: 1.5,
                    ),
                  )
                ),
              ),
              onPressed: () async {
                final busyRanges = _eventsMap.entries.expand((entry) {
                  return entry.value.map((event) {
                    final start = event.start?.dateTime?.toLocal();
                    final end = event.end?.dateTime?.toLocal();
                    if (start != null && end != null) {
                      return DateTimeRange(start: start, end: end);
                    }
                    return null;
                  }).whereType<DateTimeRange>();
                }).toList();
                
                final allEvents = <calendar.Event>[];
                for (final eventList in _eventsMap.values) {
                  allEvents.addAll(eventList);
                }
                
                final selectedDate = await Navigator.push<DateTime>(
                  context,
                  MaterialPageRoute(
                    builder: (_) => AcceptScreen(
                      busyRanges: busyRanges,
                      allEvents: allEvents,
                    ),
                  ),
                );

                if (selectedDate != null) {
                  setState(() {
                    _focusedDay = selectedDate;
                    _selectedDay = selectedDate;
                  });
                }
              },
              child: const Text('候補日を貼り付け'),
            ),
          ),
        ],
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFFF8FAFC),
              Color(0xFFE2E8F0),
            ],
          ),
        ),
        child: SingleChildScrollView(
          child: Column(
            children: [
              // カレンダーコンテナ
              Container(
                margin: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 20,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: TableCalendar<calendar.Event>(
                    rowHeight: 100,
                    firstDay: DateTime.utc(2020, 1, 1),
                    lastDay: DateTime.utc(2030, 12, 31),
                    focusedDay: _focusedDay,
                    selectedDayPredicate: (day) =>
                        _selectedDay != null &&
                        day.year == _selectedDay!.year &&
                        day.month == _selectedDay!.month &&
                        day.day == _selectedDay!.day,
                    onDaySelected: (selectedDay, focusedDay) {
                      setState(() {
                        _selectedDay = selectedDay;
                        _focusedDay = focusedDay;
                      });
                    },
                    eventLoader: _getEventsForDay,
                    availableCalendarFormats: const {
                      CalendarFormat.month: '月表示のみ',
                    },
                    calendarFormat: CalendarFormat.month,
                    headerStyle: const HeaderStyle(
                      formatButtonVisible: false,
                      titleCentered: true,
                      titleTextStyle: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF2c3e50),
                      ),
                      leftChevronIcon: Icon(
                        Icons.chevron_left_rounded,
                        color: Color(0xFF667eea),
                        size: 28,
                      ),
                      rightChevronIcon: Icon(
                        Icons.chevron_right_rounded,
                        color: Color(0xFF667eea),
                        size: 28,
                      ),
                    ),
                    calendarBuilders: CalendarBuilders(
                      defaultBuilder: (context, day, focusedDay) {
                        final events = _getEventsForDay(day);
                        final isToday = isSameDay(day, DateTime.now());
                        final remainingCount = events.length - 2;
                        return SizedBox(
                          width: 100,
                          height: 100,
                          child: Container(
                            margin: const EdgeInsets.all(2),
                            decoration: BoxDecoration(
                              color: isToday 
                                  ? const Color(0xFF667eea).withOpacity(0.1)
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(12),
                              border: isToday
                                  ? Border.all(
                                      color: const Color(0xFF667eea),
                                      width: 2,
                                    )
                                  : null,
                            ),
                            child: Stack(
                              //crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                //左上の日付
                                Positioned(
                                  //padding: const EdgeInsets.all(6),
                                  top: 4,
                                  left: 4,
                                  child: Text(
                                    '${day.day}',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                      color: isToday
                                          ? const Color(0xFF667eea)
                                          : const Color(0xFF2c3e50),
                                    ),
                                  ),
                                ),
                                //イベント一覧
                                //...events.take(2).map((event) {
                                Positioned.fill(
                                  child: Padding(
                                    padding: const EdgeInsets.only(top: 22, left: 4, right: 4),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: events.take(2).map((event) {
                                        final start = event.start?.dateTime?.toLocal();
                                        final time = start != null
                                            ? DateFormat('HH:mm').format(start)
                                            : '';
                                        return Container(
                                          margin: const EdgeInsets.symmetric(
                                            horizontal: 4,
                                            vertical: 1,
                                          ),
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 6,
                                            vertical: 2,
                                          ),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFF667eea).withOpacity(0.1),
                                            borderRadius: BorderRadius.circular(8),
                                          ),
                                          child: Text(
                                            time.isNotEmpty ? '$time ${event.summary ?? ''}' : event.summary ?? '',
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(
                                              fontSize: 9,
                                              color: Color(0xFF667eea),
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                        );
                                      }).toList(),
                                    )
                                  )
                                  
                                ),
                                //残りのイベント数
                                if (remainingCount > 0)
                                  Positioned(
                                    bottom: 4,
                                    right: 6,
                                    child: Text(
                                      '+$remainingCount',
                                      style: const TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                        color: Color(0xFF667eea),
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        );//ここまで
                      },
                      selectedBuilder: (context, day, focusedDay) {
                        final events = _getEventsForDay(day);
                        
                        return Container(
                          margin: const EdgeInsets.all(2),
                          width: 100,
                          height: double.infinity,
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFF667eea), Color(0xFF764ba2)],
                            ),
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFF667eea).withOpacity(0.3),
                                blurRadius: 8,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Padding(
                                padding: const EdgeInsets.all(6),
                                child: Text(
                                  '${day.day}',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                              ...events.take(2).map((event) {
                                final start = event.start?.dateTime?.toLocal();
                                final time = start != null
                                    ? DateFormat('HH:mm').format(start)
                                    : '';
                                return Container(
                                  margin: const EdgeInsets.symmetric(
                                    horizontal: 4,
                                    vertical: 1,
                                  ),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 6,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.2),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    time.isNotEmpty ? '$time ${event.summary ?? ''}' : event.summary ?? '',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontSize: 9,
                                      color: Colors.white,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                );
                              }),
                            ],
                          ),
                        );
                      },
                    ),
                    calendarStyle: CalendarStyle(
                      outsideDaysVisible: false,
                      weekendTextStyle: TextStyle(
                        color: Colors.red[400],
                        fontWeight: FontWeight.w600,
                      ),
                      holidayTextStyle: TextStyle(
                        color: Colors.red[400],
                        fontWeight: FontWeight.w600,
                      ),
                      markerDecoration: const BoxDecoration(), // 黒丸を非表示
                      markersMaxCount: 0, // マーカーの最大数を0に設定
                    ),
                  ),
                ),
              ),
              
              // 選択された日付と詳細情報
              if (_selectedDay != null)
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 16),
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 20,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              DateFormat('yyyy年MM月dd日').format(_selectedDay!),
                              style: const TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF2c3e50),
                              ),
                            ),
                            Text(
                              DateFormat('EEEE', 'ja').format(_selectedDay!),
                              style: TextStyle(
                                fontSize: 16,
                                color: Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
                        Container(
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFF667eea), Color(0xFF764ba2)],
                            ),
                            borderRadius: BorderRadius.circular(50),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFF667eea).withOpacity(0.3),
                                blurRadius: 15,
                                offset: const Offset(0, 8),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),

                    const Text(
                      '予定',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF2c3e50),
                      ),
                    ),
                    const SizedBox(height: 10),
                    ..._getEventsForDay(_selectedDay!).map((e) {
                      final dateTime = e.start?.dateTime?.toLocal();
                      final isAllDay = e.start?.date != null && e.start?.dateTime == null;
                      final summary = e.summary ?? 'タイトルなし';

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
                                ],
                              ),
                            ),
                          ],
                        ),
                      );
                    }),

                    if (_getEventsForDay(_selectedDay!).isEmpty)
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.grey[100],
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.event_available_rounded,
                              color: Colors.grey[400],
                              size: 24,
                            ),
                            const SizedBox(width: 12),
                            Text(
                              '予定がありません',
                              style: TextStyle(
                                fontSize: 16,
                                color: Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
                      ),

                    const SizedBox(height: 16),
                    Align(
                      alignment: Alignment.center,
                      child: TextButton(
                        onPressed: () async {
                          final result = await Navigator.of(context).push(
                            PageRouteBuilder(
                              pageBuilder: (context, animation, secondaryAnimation) =>
                                  RequestScreen(selectedDate: _selectedDay!),
                              transitionsBuilder: (context, animation, secondaryAnimation, child) {
                                const begin = Offset(1.0, 0.0);
                                const end = Offset.zero;
                                const curve = Curves.easeInOut;
                                final tween = Tween(begin: begin, end: end)
                                    .chain(CurveTween(curve: curve));
                                return SlideTransition(
                                  position: animation.drive(tween),
                                  child: child,
                                );
                              },
                            ),
                          );
                          if (result != null && result is Map<String, DateTime>) {
                            setState(() {
                              _candidates.add(result);
                            });
                          }
                        },
                        style: ButtonStyle(
                          backgroundColor: MaterialStateProperty.resolveWith<Color?>(
                            (states) => states.contains(MaterialState.hovered)
                                ? const Color(0xFF764ba2).withOpacity(0.1)
                                : Colors.transparent,
                          ),
                          foregroundColor: MaterialStateProperty.all(const Color(0xFF764ba2)),
                          padding: MaterialStateProperty.all(
                            const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                          ),
                          textStyle: MaterialStateProperty.all(const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          )),
                          shape: MaterialStateProperty.all(
                            RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                              side: const BorderSide(color: Color(0xFF764ba2), width: 1),
                            ),
                          ),
                        ),
                        child: const Text('＋ 候補日を追加'),
                      ),
                    ),
                    const SizedBox(height: 20),
                    if (_candidates.isNotEmpty) ...[
                      const Text(
                        '追加した候補日',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF2c3e50),
                        ),
                      ),
                      const SizedBox(height: 10),
                      ..._candidates.asMap().entries.map((entry) {
                        final index = entry.key;
                        final c = entry.value;
                        return Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(0xFF764ba2).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: const Color(0xFF764ba2).withOpacity(0.3),
                              width: 1,
                            ),
                          ),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF764ba2),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Icon(
                                  Icons.schedule_rounded,
                                  color: Colors.white,
                                  size: 16,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  '${DateFormat('M月d日（E）', 'ja').format(c['start']!)}'
                                  '${DateFormat('H:mm').format(c['start']!)}~${DateFormat('H:mm').format(c['end']!)}',
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFF2c3e50),
                                  ),
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete_outline_rounded, color: Color(0xFF764ba2)),
                                tooltip: 'この候補日を削除',
                                onPressed: () {
                                  setState(() {
                                    _candidates.removeAt(index);
                                  });
                                },
                              ),
                            ],
                          ),
                        );
                      }),
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: ElevatedButton.icon(
                          icon: const Icon(Icons.copy_rounded),
                          label: const Text(
                            '候補日をコピー',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          onPressed: () {
                            final text = _candidates
                                .map((c) => '${DateFormat('M月d日（E）', 'ja').format(c['start']!)}'
                                    '${DateFormat('H:mm').format(c['start']!)}~${DateFormat('H:mm').format(c['end']!)}')
                                .join('\n');
                            Clipboard.setData(ClipboardData(text: text));
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: const Text('候補日をコピーしました'),
                                backgroundColor: const Color(0xFF667eea),
                                behavior: SnackBarBehavior.floating,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
                            );
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF667eea),
                            foregroundColor: Colors.white,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ),
                      
                    ]
                  ],
                ),
              ),//column終了
          ]),
        ),
      ),
    );
  }
}

class GoogleAuthClient extends http.BaseClient {
  final Map<String, String> _headers;
  final http.Client _client = http.Client();
  GoogleAuthClient(this._headers);

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    return _client.send(request..headers.addAll(_headers));
  }
}