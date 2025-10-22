import 'package:flutter/material.dart';
import 'package:powerlifting_app/logic/training_planner.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:powerlifting_app/models/training_record.dart';
import 'package:flutter/services.dart';

class PlanScreen extends StatefulWidget {
  const PlanScreen({super.key});

  @override
  State<PlanScreen> createState() => _PlanScreenState();
}

class _PlanScreenState extends State<PlanScreen> {
  final TrainingPlanner _planner = TrainingPlanner();
  String _selectedExercise = 'スクワット';
  String? _planResult;
  bool _isLoading = false;

  final TextEditingController _chatController = TextEditingController();
  final List<Map<String, String>> _messages = [];
  bool _isChatting = false;
  final String _geminiApiKey = 'AIzaSyAdI6eK9uGAlLeC2uPGWCXCQdP_xn96DL0'; // Replace with your actual Gemini API key

  // For Training Records
  final TextEditingController _recordWeightController = TextEditingController();
  final TextEditingController _recordRepsController = TextEditingController();
  final TextEditingController _recordSetsController = TextEditingController();
  List<TrainingRecord> _currentExerciseRecords = [];
  TrainingRecord? _editingRecord;
  int? _editingRecordIndex;

  @override
  void initState() {
    super.initState();
    _loadRecordsForSelectedExercise();
  }

  @override
  void dispose() {
    _chatController.dispose();
    _recordWeightController.dispose();
    _recordRepsController.dispose();
    _recordSetsController.dispose();
    super.dispose();
  }

  Future<void> _generatePlan() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _planResult = null;
    });

    final result = await _planner.generatePlan(_selectedExercise);

    if (!mounted) return;
    setState(() {
      _planResult = result;
      _isLoading = false;
    });
  }

  Future<void> _sendChatMessage(String message) async {
    if (!mounted) return;
    setState(() {
      _messages.add({'role': 'user', 'content': message});
      _isChatting = true;
    });
    _chatController.clear();

    try {
      final List<Map<String, dynamic>> geminiMessages = _messages.map((msg) {
        return {
          'role': msg['role'] == 'user' ? 'user' : 'model',
          'parts': [
            {'text': msg['content']}
          ],
        };
      }).toList();

      final response = await http.post(
        Uri.parse('https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-pro:generateContent'),
        headers: {
          'Content-Type': 'application/json',
          'x-goog-api-key': _geminiApiKey,
        },
        body: jsonEncode({
          'contents': geminiMessages,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(utf8.decode(response.bodyBytes));
        if (!mounted) return;
        setState(() {
          _messages.add({'role': 'model', 'content': data['candidates'][0]['content']['parts'][0]['text']});
          _isChatting = false;
        });
      } else {
        if (!mounted) return;
        setState(() {
          _messages.add({'role': 'system', 'content': 'Error: ${response.statusCode} - ${response.body}'});
          _isChatting = false;
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _messages.add({'role': 'system', 'content': 'Error: $e'});
        _isChatting = false;
      });
    }
  }

  // --- Training Record Management ---

  String _getPrefsKeyForExercise(String exercise) {
    return 'trainingRecords_${exercise.toLowerCase()}';
  }

  Future<void> _loadRecordsForSelectedExercise() async {
    final prefs = await SharedPreferences.getInstance();
    final String? recordsJson = prefs.getString(_getPrefsKeyForExercise(_selectedExercise));

    if (recordsJson != null) {
      final List<dynamic> decodedData = json.decode(recordsJson);
      setState(() {
        _currentExerciseRecords = decodedData.map((e) => TrainingRecord.fromJson(e)).toList();
      });
    } else {
      setState(() {
        _currentExerciseRecords = [];
      });
    }
  }

  Future<void> _saveRecordsForSelectedExercise() async {
    final prefs = await SharedPreferences.getInstance();
    final List<Map<String, dynamic>> encodedData = _currentExerciseRecords.map((e) => e.toJson()).toList();
    await prefs.setString(_getPrefsKeyForExercise(_selectedExercise), json.encode(encodedData));
  }

  void _addRecord(TrainingRecord record) {
    setState(() {
      _currentExerciseRecords.add(record);
      _saveRecordsForSelectedExercise();
      _cancelEdit(); // Clear form after adding
    });
  }

  void _updateRecord(TrainingRecord newRecord) {
    setState(() {
      if (_editingRecordIndex != null) {
        _currentExerciseRecords[_editingRecordIndex!] = newRecord;
        _saveRecordsForSelectedExercise();
        _cancelEdit();
      }
    });
  }

  void _cancelEdit() {
    setState(() {
      _editingRecord = null;
      _editingRecordIndex = null;
      _recordWeightController.clear();
      _recordRepsController.clear();
      _recordSetsController.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('トレーニングプラン'),
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'トレーニング内容を選択または記録してください。',
                style: TextStyle(fontSize: 16),
              ),
              const SizedBox(height: 16.0),
              DropdownButtonFormField<String>(
                initialValue: _selectedExercise,
                decoration: const InputDecoration(
                  labelText: '種目選択',
                  border: OutlineInputBorder(),
                ),
                items: ['スクワット', 'ベンチプレス', 'デッドリフト']
                    .map<DropdownMenuItem<String>>((String value) {
                  return DropdownMenuItem<String>(
                    value: value,
                    child: Text(value),
                  );
                }).toList(),
                onChanged: (String? newValue) {
                  if (!mounted) return;
                  setState(() {
                    _selectedExercise = newValue!;
                    _loadRecordsForSelectedExercise(); // Load records for the newly selected exercise
                  });
                },
              ),
              const SizedBox(height: 24.0),
              ElevatedButton(
                onPressed: _isLoading ? null : _generatePlan,
                child: _isLoading ? const CircularProgressIndicator(color: Colors.white) : const Text('プランを生成'),
              ),
              _buildSectionDivider(),
              _buildResultArea(), // Plan section
              _buildSectionDivider(),
              _buildTrainingRecordSection(), // Training Record section
              _buildSectionDivider(),
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'ボノロン(Gemini)に相談',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: _messages.length,
                    itemBuilder: (context, index) {
                      final message = _messages[index];
                      return Align(
                        alignment: message['role'] == 'user'
                            ? Alignment.centerRight
                            : Alignment.centerLeft,
                        child: Container(
                          padding: const EdgeInsets.all(10.0),
                          margin: const EdgeInsets.symmetric(vertical: 5.0, horizontal: 8.0),
                          decoration: BoxDecoration(
                            color: message['role'] == 'user'
                                ? Colors.blue[100]
                                : Colors.grey[200],
                            borderRadius: BorderRadius.circular(15.0),
                          ),
                          child: Text(message['content']!),
                        ),
                      );
                    },
                  ),
                  Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _chatController,
                            decoration: InputDecoration(
                              hintText: 'メッセージを入力...',
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(20.0),
                              ),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 15.0),
                            ),
                            onSubmitted: _isChatting ? null : (text) => _sendChatMessage(text),
                          ),
                        ),
                        const SizedBox(width: 8.0),
                        _isChatting
                            ? const CircularProgressIndicator()
                            : IconButton(
                                icon: const Icon(Icons.send),
                                onPressed: () => _sendChatMessage(_chatController.text),
                              ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildResultArea() {
    if (!mounted) return const Center(child: CircularProgressIndicator()); // Added mounted check
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_planResult == null) {
      return const Center(
        child: Text('ここに提案プランが表示されます。'),
      );
    }

    return Container(
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: Colors.blue.withAlpha(13), // 0.05 opacity
        borderRadius: BorderRadius.circular(8.0),
        border: Border.all(color: Colors.blue.withAlpha(51)), // 0.2 opacity
      ),
      child: Text(
        _planResult!,
        textAlign: TextAlign.center,
        style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget _buildTrainingRecordSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'トレーニング記録',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16.0),
        _buildRecordInputField(
          '重量 (kg)',
          _recordWeightController,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}'))],
        ),
        const SizedBox(height: 8.0),
        _buildRecordInputField(
          '回数',
          _recordRepsController,
          keyboardType: TextInputType.number,
        ),
        const SizedBox(height: 8.0),
        _buildRecordInputField(
          'セット数',
          _recordSetsController,
          keyboardType: TextInputType.number,
        ),
        const SizedBox(height: 16.0),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            ElevatedButton(
              onPressed: () {
                final double? weight = double.tryParse(_recordWeightController.text);
                final int? reps = int.tryParse(_recordRepsController.text);
                final int? sets = int.tryParse(_recordSetsController.text);

                if (weight != null && reps != null && sets != null) {
                  final newRecord = TrainingRecord(
                    exerciseName: _selectedExercise,
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
    );
  }

  Widget _buildSectionDivider() {
    return const Column(
      children: [
        SizedBox(height: 24.0),
        Divider(),
        SizedBox(height: 16.0),
      ],
    );
  }

  Widget _buildRecordInputField(String label, TextEditingController controller, {TextInputType keyboardType = TextInputType.number, List<TextInputFormatter>? inputFormatters}) {
    return TextField(
      controller: controller,
      decoration: InputDecoration(labelText: label, border: const OutlineInputBorder()),
      keyboardType: keyboardType,
      inputFormatters: inputFormatters,
    );
  }
}
