import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class RequestScreen extends StatelessWidget {
  final DateTime selectedDate;
  RequestScreen({super.key, required this.selectedDate});

  @override
  Widget build(BuildContext context) {
    int? startHour;
    int? startMinute;
    int? endHour;
    int? endMinute;

    final formattedDate = DateFormat('yyyy年MM月dd日').format(selectedDate);

    return Scaffold(
      appBar: AppBar(title: Text('候補日時を追加')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: StatefulBuilder(
          builder: (context, setState) => Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '選択した日付: $formattedDate',
                style: const TextStyle(fontSize: 18),
              ),
              const SizedBox(height: 20),

              const Text('開始時刻を選択してください'),
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<int>(
                      decoration: const InputDecoration(labelText: '時間'),
                      value: startHour,
                      items: List.generate(13, (index) {
                        final hour = 9 + index;
                        return DropdownMenuItem(
                          value: hour,
                          child: Text(hour.toString().padLeft(2, '0')),
                        );
                      }),
                      onChanged: (value) {
                        setState(() {
                          startHour = value;
                        });
                      },
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: DropdownButtonFormField<int>(
                      decoration: const InputDecoration(labelText: '分'),
                      value: startMinute,
                      items: const [
                        DropdownMenuItem(value: 0, child: Text('00')),
                        DropdownMenuItem(value: 15, child: Text('15')),
                        DropdownMenuItem(value: 30, child: Text('30')),
                        DropdownMenuItem(value: 45, child: Text('45')),
                      ],
                      onChanged: (value) {
                        setState(() {
                          startMinute = value;
                        });
                      },
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 20),
              const Text('終了時刻を選択してください'),
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<int>(
                      decoration: const InputDecoration(labelText: '時間'),
                      value: endHour,
                      items: List.generate(13, (index) {
                        final hour = 9 + index;
                        return DropdownMenuItem(
                          value: hour,
                          child: Text(hour.toString().padLeft(2, '0')),
                        );
                      }),
                      onChanged: (value) {
                        setState(() {
                          endHour = value;
                        });
                      },
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: DropdownButtonFormField<int>(
                      decoration: const InputDecoration(labelText: '分'),
                      value: endMinute,
                      items: const [
                        DropdownMenuItem(value: 0, child: Text('00')),
                        DropdownMenuItem(value: 15, child: Text('15')),
                        DropdownMenuItem(value: 30, child: Text('30')),
                        DropdownMenuItem(value: 45, child: Text('45')),
                      ],
                      onChanged: (value) {
                        setState(() {
                          endMinute = value;
                        });
                      },
                    ),
                  ),
                ],
              ),

              const Spacer(),
              SizedBox(
                width: double.infinity,
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
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('終了時刻は開始時刻より後にしてください')),
                        );
                      }
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('開始・終了時刻をすべて選択してください')),
                      );
                    }
                  },
                  child: const Text('候補日として追加'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}