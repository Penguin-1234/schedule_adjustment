import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis/calendar/v3.dart' as calendar;
import 'package:http/http.dart' as http;
import 'package:table_calendar/table_calendar.dart';
import 'package:intl/intl.dart';
import 'request.dart';
import 'accept.dart';
import 'package:flutter/services.dart'; // ← 追加

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

    // 初期フォーカス日が渡されていれば使用
    if (widget.initialFocusedDate != null) {
      _focusedDay = widget.initialFocusedDate!;
      _selectedDay = widget.initialFocusedDate!;
    }
  }

  List<Map<String, DateTime>> _candidates = []; // 候補日を保持するリスト
  String? _lastCandidateText; // 追加：候補日テキストを保持

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
    final start = now.subtract(const Duration(days: 60)); // 過去60日分

    final events = await calendarApi.events.list(
      'primary',
      timeMin: start, //取得する予定開始日(二ヶ月前から)
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
        body: Row(
          children: [
            // 左：背景画像
            Expanded(
              flex: 1,
              child: Image.asset(
                'assets/images/background.jpg',
                fit: BoxFit.cover,
                height: double.infinity,
              ),
            ),
            // 右：ログインUI
            Expanded(
              flex: 1,
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'Google Calendar App',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 30),
                    ElevatedButton.icon(
                      onPressed: _signInAndFetchEvents,
                      icon: const Icon(Icons.login),
                      label: const Text('Googleでログイン'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          vertical: 16,
                          horizontal: 24,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(30),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('月間カレンダー'),
        leading: widget.returnToAcceptScreen
            ? IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () => Navigator.pop(context),
              )
            : null,
        actions: [
          IconButton(
            icon: const Icon(Icons.note_add),
            tooltip: '候補日を貼り付け',
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
              
              // 全イベント情報を正しく取得
              final allEvents = <calendar.Event>[];
              for (final eventList in _eventsMap.values) {
                allEvents.addAll(eventList);
              }
              
              print('渡すイベント数: ${allEvents.length}'); // デバッグ用
              
              // ✅ AcceptScreen からの戻り値を await で受け取る
              final selectedDate = await Navigator.push<DateTime>(
                context,
                MaterialPageRoute(
                  builder: (_) => AcceptScreen(
                    busyRanges: busyRanges,
                    allEvents: allEvents, // 全イベント情報を渡す
                  ),
                ),
              );

              // ✅ もし戻り値が null でなければ、カレンダーの日付を更新するなどの処理を行う
              if (selectedDate != null) {
                setState(() {
                  _focusedDay = selectedDate;
                  _selectedDay = selectedDate;
                });
              }
            },
          ),
        ],
      ),
      body: Stack(
        children: [
          // 背景画像（薄く表示）
          Opacity(
            opacity: 0.2, // 画像の透明度（0.0〜1.0）
            child: Image.asset(
              'assets/images/background_calendar.jpg', //背景画像の指定
              fit: BoxFit.cover,
              width: double.infinity,
              height: double.infinity,
            ),
          ),
          // カレンダーと予定表示
          //スクロール可能に
          SingleChildScrollView(
            child: Column(
              children: [
                TableCalendar<calendar.Event>(
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
                  calendarBuilders: CalendarBuilders(
                    defaultBuilder: (context, day, focusedDay) {
                      final events = _getEventsForDay(day);
                      return Container(
                        margin: const EdgeInsets.all(4),
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey.shade300),
                          borderRadius: BorderRadius.circular(8),
                          color: Colors.white.withOpacity(0.8),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Align(
                              alignment: Alignment.topLeft,
                              child: Text(
                                '${day.day}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                            const SizedBox(height: 4),
                            ...events.take(3).map((event) {
                              final start = event.start?.dateTime?.toLocal();
                              final time = start != null
                                  ? DateFormat('HH:mm').format(start)
                                  : '終日';
                              return Text(
                                '$time ${event.summary ?? ''}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 10,
                                  color: Colors.black87,
                                ),
                              );
                            }),
                          ],
                        ),
                      );
                    },
                  ),
                  calendarStyle: const CalendarStyle(
                    todayDecoration: BoxDecoration(
                      color: Colors.blue,
                      shape: BoxShape.circle,
                    ),
                    selectedDecoration: BoxDecoration(
                      color: Colors.orange,
                      shape: BoxShape.circle,
                    ),
                    markerDecoration: BoxDecoration(),
                  ),
                ),
                // カレンダーの下に追加
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      _selectedDay != null
                          ? DateFormat('yyyy年MM月dd日').format(_selectedDay!)
                          : '',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(
                        Icons.add_circle,
                        color: Colors.blue,
                        size: 32,
                      ),
                      tooltip: '候補日を追加',
                      onPressed: _selectedDay == null
                          ? null
                          : () async {
                              final result = await Navigator.of(context).push(
                                PageRouteBuilder(
                                  pageBuilder:
                                      (
                                        context,
                                        animation,
                                        secondaryAnimation,
                                      ) => RequestScreen(
                                        selectedDate: _selectedDay!,
                                      ),
                                  transitionsBuilder:
                                      (
                                        context,
                                        animation,
                                        secondaryAnimation,
                                        child,
                                      ) {
                                        const begin = Offset(1.0, 0.0);
                                        const end = Offset.zero;
                                        const curve = Curves.ease;
                                        final tween = Tween(
                                          begin: begin,
                                          end: end,
                                        ).chain(CurveTween(curve: curve));
                                        return SlideTransition(
                                          position: animation.drive(tween),
                                          child: child,
                                        );
                                      },
                                ),
                              );
                              if (result != null &&
                                  result is Map<String, DateTime>) {
                                setState(() {
                                  _candidates.add(result);
                                });
                              } else {
                                print('result: $result');
                              }
                            },
                    ),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ..._getEventsForDay(_selectedDay ?? _focusedDay).map((e) {
                      final dateTime = e.start?.dateTime?.toLocal();
                      final isAllDay =
                          e.start?.date != null && e.start?.dateTime == null;
                      final summary = e.summary ?? 'タイトルなし';
                      String title;
                      if (dateTime != null) {
                        title =
                            '${DateFormat('HH:mm').format(dateTime)} $summary';
                      } else if (isAllDay) {
                        title = summary;
                      } else {
                        title = '時刻不明 $summary';
                      }

                      return ListTile(title: Text(title));
                    }),
                    Padding(
                      padding: const EdgeInsets.only(top: 8.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            '追加した候補日:',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                          if (_candidates.isNotEmpty)
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                ..._candidates.map(
                                  (c) => Text(
                                    '${DateFormat('M月d日（E）', 'ja').format(c['start']!)}'
                                    '${DateFormat('H:mm').format(c['start']!)}~${DateFormat('H:mm').format(c['end']!)}',
                                  ),
                                ),
                                const SizedBox(height: 8),
                                ElevatedButton.icon(
                                  icon: const Icon(Icons.copy),
                                  label: const Text('候補日をコピー'),
                                  onPressed: () {
                                    final text = _candidates
                                        .map(
                                          (c) =>
                                              '${DateFormat('M月d日（E）', 'ja').format(c['start']!)}'
                                              '${DateFormat('H:mm').format(c['start']!)}~${DateFormat('H:mm').format(c['end']!)}',
                                        )
                                        .join('\n');
                                    Clipboard.setData(
                                      ClipboardData(text: text),
                                    );
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text('候補日をコピーしました'),
                                      ),
                                    );
                                  },
                                ),
                              ],
                            )
                          else
                            const Text(
                              '候補日はありません',
                              style: TextStyle(color: Colors.grey),
                            ),
                        ],
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
