import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final TextEditingController _heightController = TextEditingController();
  final TextEditingController _weightController = TextEditingController();
  final TextEditingController _goalSquatController = TextEditingController();
  final TextEditingController _goalBenchController = TextEditingController();
  final TextEditingController _goalDeadliftController = TextEditingController();
  final TextEditingController _weightClassController = TextEditingController();
  final TextEditingController _goalSBDTotalController = TextEditingController();
  DateTime? _goalDate;

  @override
  void initState() {
    super.initState();
    _loadProfileValues();
    _goalSquatController.addListener(_calculateGoalSBDTotal);
    _goalBenchController.addListener(_calculateGoalSBDTotal);
    _goalDeadliftController.addListener(_calculateGoalSBDTotal);
  }

  Future<void> _loadProfileValues() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _heightController.text = prefs.getString('height') ?? '';
      _weightController.text = prefs.getString('weight') ?? '';
      _goalSquatController.text = prefs.getString('goalSquat') ?? '';
      _goalBenchController.text = prefs.getString('goalBench') ?? '';
      _goalDeadliftController.text = prefs.getString('goalDeadlift') ?? '';
      final goalDateString = prefs.getString('goalDate');
      if (goalDateString != null) {
        _goalDate = DateTime.tryParse(goalDateString);
      }
      _updateWeightClass(_weightController.text);
      _calculateGoalSBDTotal();
    });
  }

  Future<void> _saveProfileValues() async {
    final messenger = ScaffoldMessenger.of(context);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('height', _heightController.text);
    await prefs.setString('weight', _weightController.text);
    await prefs.setString('goalSquat', _goalSquatController.text);
    await prefs.setString('goalBench', _goalBenchController.text);
    await prefs.setString('goalDeadlift', _goalDeadliftController.text);
    if (_goalDate != null) {
      await prefs.setString('goalDate', _goalDate!.toIso8601String());
    } else {
      await prefs.remove('goalDate');
    }

    if (!mounted) return;
    messenger.showSnackBar(
      const SnackBar(content: Text('プロフィールを保存しました！')),
    );
  }

  void _updateWeightClass(String weightString) {
    final double? weight = double.tryParse(weightString);
    String weightClass = '--';
    if (weight != null) {
      // Standard Men's Powerlifting Classes
      if (weight <= 59.0) {
        weightClass = '59kg級';
      } else if (weight <= 66.0) {
        weightClass = '66kg級';
      } else if (weight <= 74.0) {
        weightClass = '74kg級';
      } else if (weight <= 83.0) {
        weightClass = '83kg級';
      } else if (weight <= 93.0) {
        weightClass = '93kg級';
      } else if (weight <= 105.0) {
        weightClass = '105kg級';
      } else if (weight <= 120.0) {
        weightClass = '120kg級';
      } else {
        weightClass = '120kg超級';
      }
    }
    setState(() {
      _weightClassController.text = weightClass;
    });
  }

  void _calculateGoalSBDTotal() {
    final double squat = double.tryParse(_goalSquatController.text) ?? 0.0;
    final double bench = double.tryParse(_goalBenchController.text) ?? 0.0;
    final double deadlift = double.tryParse(_goalDeadliftController.text) ?? 0.0;
    final double total = squat + bench + deadlift;
    setState(() {
      _goalSBDTotalController.text = total.toStringAsFixed(2);
    });
  }

  Future<void> _selectGoalDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _goalDate ?? DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime(2101),
      locale: const Locale('ja', 'JP'),
    );
    if (picked != null && picked != _goalDate) {
      setState(() {
        _goalDate = picked;
      });
    }
  }

  String get _remainingDays {
    if (_goalDate == null) {
      return 'N/A';
    }
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final difference = _goalDate!.difference(today).inDays;
    if (difference < 0) {
      return '期限切れ';
    } else {
      return '残り$difference日';
    }
  }

  @override
  void dispose() {
    _heightController.dispose();
    _weightController.dispose();
    _goalSquatController.removeListener(_calculateGoalSBDTotal);
    _goalSquatController.dispose();
    _goalBenchController.removeListener(_calculateGoalSBDTotal);
    _goalBenchController.dispose();
    _goalDeadliftController.removeListener(_calculateGoalSBDTotal);
    _goalDeadliftController.dispose();
    _weightClassController.dispose();
    _goalSBDTotalController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('個人情報'),
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildTextField('身長 (cm)', _heightController, isReadOnly: false),
              const SizedBox(height: 16.0),
              _buildTextField('体重 (kg)', _weightController, isReadOnly: false, onChanged: _updateWeightClass),
              const SizedBox(height: 16.0),
              _buildTextField('階級', _weightClassController, isReadOnly: true),
              const SizedBox(height: 24.0),
              const Text('目標設定', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 12.0),
              _buildGoalDateSelector(),
              const SizedBox(height: 16.0),
              _buildTextField('目標 スクワット (kg)', _goalSquatController, isReadOnly: false),
              const SizedBox(height: 16.0),
              _buildTextField('目標 ベンチプレス (kg)', _goalBenchController, isReadOnly: false),
              const SizedBox(height: 16.0),
              _buildTextField('目標 デッドリフト (kg)', _goalDeadliftController, isReadOnly: false),
              const SizedBox(height: 16.0),
              _buildTextField('目標 合計 (kg)', _goalSBDTotalController, isReadOnly: true),
              const SizedBox(height: 32.0),
              ElevatedButton(
                onPressed: _saveProfileValues,
                child: const Text('保存'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGoalDateSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('目標達成日', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
        const SizedBox(height: 8.0),
        InkWell(
          onTap: () => _selectGoalDate(context),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 16.0),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey),
              borderRadius: BorderRadius.circular(4.0),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  _goalDate == null
                      ? '日付を選択'
                      : DateFormat.yMMMd('ja_JP').format(_goalDate!),
                  style: const TextStyle(fontSize: 16),
                ),
                Text(
                  _goalDate == null ? '' : _remainingDays,
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.blueAccent),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTextField(String label, TextEditingController controller, {required bool isReadOnly, bool isNumeric = true, Function(String)? onChanged}) {
    return TextField(
      controller: controller,
      readOnly: isReadOnly,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
        fillColor: isReadOnly ? Colors.grey[200] : null,
        filled: isReadOnly,
      ),
      keyboardType: isNumeric ? const TextInputType.numberWithOptions(decimal: true) : TextInputType.text,
      inputFormatters: isNumeric
          ? [FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}'))]
          : [],
      onChanged: onChanged,
    );
  }
}
