import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:powerlifting_app/models/training_record.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

class RecordsScreen extends StatefulWidget {
  const RecordsScreen({super.key});

  @override
  State<RecordsScreen> createState() => _RecordsScreenState();
}

class _RecordsScreenState extends State<RecordsScreen> {
  CalendarFormat _calendarFormat = CalendarFormat.month;
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;
  
  final Map<DateTime, List<TrainingRecord>> _trainingRecords = {};
  String _selectedExercise = 'スクワット';

  TrainingRecord? _editingRecord;
  int? _editingRecordIndex;
  DateTime? _editingRecordDate;

  final TextEditingController _weightController = TextEditingController();
  final TextEditingController _repsController = TextEditingController();
  final TextEditingController _setsController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _selectedDay = _focusedDay;
    _loadRecords();
  }

  Future<void> _loadRecords() async {
    final prefs = await SharedPreferences.getInstance();
    final String? recordsJson = prefs.getString('trainingRecords');

    if (recordsJson != null) {
      final Map<String, dynamic> decodedData = json.decode(recordsJson);
      final DateTime fourWeeksAgo = DateTime.now().subtract(const Duration(days: 28));

      decodedData.forEach((key, value) {
        final DateTime date = DateTime.parse(key);
        if (date.isAfter(fourWeeksAgo) || date.isAtSameMomentAs(fourWeeksAgo)) {
          _trainingRecords[DateTime(date.year, date.month, date.day)] = 
              (value as List).map((e) => TrainingRecord.fromJson(e)).toList();
        }
      });
      setState(() {});
    }
  }

  Future<void> _saveRecords() async {
    final prefs = await SharedPreferences.getInstance();
    final Map<String, dynamic> encodedData = {};
    final DateTime fourWeeksAgo = DateTime.now().subtract(const Duration(days: 28));

    _trainingRecords.forEach((key, value) {
      if (key.isAfter(fourWeeksAgo) || key.isAtSameMomentAs(fourWeeksAgo)) {
        encodedData[key.toIso8601String()] = value.map((e) => e.toJson()).toList();
      }
    });
    await prefs.setString('trainingRecords', json.encode(encodedData));
  }

  List<TrainingRecord> _getRecordsForDay(DateTime day) {
    return _trainingRecords[DateTime(day.year, day.month, day.day)] ?? [];
  }

  void _addRecord(TrainingRecord record) {
    setState(() {
      if (_selectedDay != null) {
        final normalizedDate = DateTime(_selectedDay!.year, _selectedDay!.month, _selectedDay!.day);
        _trainingRecords.update(
          normalizedDate,
          (value) => [...value, record],
          ifAbsent: () => [record],
        );
        _saveRecords();
      }
    });
  }

  void _deleteRecord(DateTime date, int index) {
    setState(() {
      final normalizedDate = DateTime(date.year, date.month, date.day);
      if (_trainingRecords.containsKey(normalizedDate)) {
        _trainingRecords[normalizedDate]!.removeAt(index);
        if (_trainingRecords[normalizedDate]!.isEmpty) {
          _trainingRecords.remove(normalizedDate);
        }
        _saveRecords();
      }
    });
  }

  void _editRecord(DateTime date, int index, TrainingRecord record) {
    setState(() {
      _editingRecord = record;
      _editingRecordIndex = index;
      _editingRecordDate = date;
      _selectedExercise = record.exerciseName;
      _weightController.text = record.weight.toString();
      _repsController.text = record.reps.toString();
      _setsController.text = record.sets.toString();
    });
  }

  void _updateRecord(TrainingRecord newRecord) {
    setState(() {
      if (_editingRecordDate != null && _editingRecordIndex != null) {
        final normalizedDate = DateTime(_editingRecordDate!.year, _editingRecordDate!.month, _editingRecordDate!.day);
        if (_trainingRecords.containsKey(normalizedDate)) {
          _trainingRecords[normalizedDate]![_editingRecordIndex!] = newRecord;
          _saveRecords();
          _cancelEdit();
        }
      }
    });
  }

  void _cancelEdit() {
    setState(() {
      _editingRecord = null;
      _editingRecordIndex = null;
      _editingRecordDate = null;
      _selectedExercise = 'スクワット';
      _weightController.clear();
      _repsController.clear();
      _setsController.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('記録'),
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            TableCalendar(
              locale: 'ja_JP',
              firstDay: DateTime.utc(_focusedDay.year, _focusedDay.month - 1, 1),
              lastDay: DateTime.utc(_focusedDay.year, _focusedDay.month + 4, 31),
              focusedDay: _focusedDay,
              calendarFormat: _calendarFormat,
              selectedDayPredicate: (day) {
                return isSameDay(_selectedDay, day);
              },
              onDaySelected: (selectedDay, focusedDay) {
                if (!isSameDay(_selectedDay, selectedDay)) {
                  setState(() {
                    _selectedDay = selectedDay;
                    _focusedDay = focusedDay;
                    _cancelEdit();
                  });
                }
              },
              onFormatChanged: (format) {
                if (_calendarFormat != format) {
                  setState(() {
                    _calendarFormat = format;
                  });
                }
              },
              onPageChanged: (focusedDay) {
                _focusedDay = focusedDay;
              },
              headerStyle: const HeaderStyle(
                formatButtonVisible: false,
                titleCentered: true,
              ),
              calendarStyle: const CalendarStyle(
                todayDecoration: BoxDecoration(
                  color: Colors.blueAccent,
                  shape: BoxShape.circle,
                ),
                selectedDecoration: BoxDecoration(
                  color: Colors.blue,
                  shape: BoxShape.circle,
                ),
              ),
              eventLoader: (day) {
                return _getRecordsForDay(day);
              },
            ),
            const SizedBox(height: 8.0),
            _selectedDay == null
                ? const Center(child: Text('日付を選択してください'))
                : Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: Text(
                          '${_selectedDay!.toLocal().toString().split(' ')[0]} の記録',
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                      ),
                      ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: _getRecordsForDay(_selectedDay!).length,
                        itemBuilder: (context, index) {
                          final record = _getRecordsForDay(_selectedDay!)[index];
                          return Card(
                            margin: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
                            child: ListTile(
                              title: Text(record.exerciseName),
                              subtitle: Text('${record.weight}kg x ${record.reps}回 x ${record.sets}セット'),
                              leading: IconButton(
                                icon: const Icon(Icons.edit),
                                onPressed: () {
                                  _editRecord(_selectedDay!, index, record);
                                },
                              ),
                              trailing: IconButton(
                                icon: const Icon(Icons.delete),
                                onPressed: () {
                                  showDialog(
                                    context: context,
                                    builder: (BuildContext context) {
                                      return AlertDialog(
                                        title: const Text('記録の削除'),
                                        content: const Text('この記録を削除してもよろしいですか？'),
                                        actions: <Widget>[
                                          TextButton(
                                            child: const Text('キャンセル'),
                                            onPressed: () {
                                              Navigator.of(context).pop();
                                            },
                                          ),
                                          TextButton(
                                            child: const Text('削除'),
                                            onPressed: () {
                                              _deleteRecord(_selectedDay!, index);
                                              Navigator.of(context).pop();
                                            },
                                          ),
                                        ],
                                      );
                                    },
                                  );
                                },
                              ),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
            _buildAddRecordForm(),
          ],
        ),
      ),
    );
  }

  Widget _buildAddRecordForm() {
    if (_editingRecord != null) {
      _weightController.text = _editingRecord!.weight.toString();
      _repsController.text = _editingRecord!.reps.toString();
      _setsController.text = _editingRecord!.sets.toString();
    } else {
      _weightController.clear();
      _repsController.clear();
      _setsController.clear();
    }

    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Column(
          children: [
            DropdownButtonFormField<String>(
              // ignore: deprecated_member_use
              value: _selectedExercise,
              decoration: const InputDecoration(labelText: '種目名'),
              items: <String>['スクワット', 'ベンチプレス', 'デッドリフト']
                  .map<DropdownMenuItem<String>>((String value) {
                return DropdownMenuItem<String>(
                  value: value,
                  child: Text(value),
                );
              }).toList(),
              onChanged: (String? newValue) {
                setState(() {
                  _selectedExercise = newValue!;
                });
              },
            ),
            TextField(
              controller: _weightController,
              decoration: const InputDecoration(labelText: '重量 (kg)'),
              keyboardType: TextInputType.number,
            ),
            TextField(
              controller: _repsController,
              decoration: const InputDecoration(labelText: '回数'),
              keyboardType: TextInputType.number,
            ),
            TextField(
              controller: _setsController,
              decoration: const InputDecoration(labelText: 'セット数'),
              keyboardType: TextInputType.number,
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                ElevatedButton(
                  onPressed: () {
                    final String exerciseName = _selectedExercise;
                    final double? weight = double.tryParse(_weightController.text);
                    final int? reps = int.tryParse(_repsController.text);
                    final int? sets = int.tryParse(_setsController.text);

                    if (exerciseName.isNotEmpty && weight != null && reps != null && sets != null) {
                      final newRecord = TrainingRecord(
                        exerciseName: exerciseName,
                        weight: weight,
                        reps: reps,
                        sets: sets,
                      );
                      if (_editingRecord != null) {
                        _updateRecord(newRecord);
                      } else {
                        _addRecord(newRecord);
                      }
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('全ての項目を入力してください')),
                      );
                    }
                  },
                  child: Text(_editingRecord != null ? '記録を更新' : '記録を追加'),
                ),
                if (_editingRecord != null)
                  ElevatedButton(
                    onPressed: _cancelEdit,
                    child: const Text('キャンセル'),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
