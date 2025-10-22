import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:math'; // For pow function

class Big3Screen extends StatefulWidget {
  const Big3Screen({super.key});

  @override
  State<Big3Screen> createState() => _Big3ScreenState();
}

class _Big3ScreenState extends State<Big3Screen> {
  // Controllers for PR(MAX) section
  final TextEditingController _squatMaxWeightController = TextEditingController();
  final TextEditingController _benchMaxWeightController = TextEditingController();
  final TextEditingController _deadliftMaxWeightController = TextEditingController();

  // State for calculated values
  double _squat1RM = 0.0;
  double _bench1RM = 0.0;
  double _deadlift1RM = 0.0;
  double _big3Total = 0.0;
  double _wilksScore = 0.0;
  double _glPoint = 0.0;
  double _bodyWeight = 0.0;
  String _big3Ratio = 'N/A';

  @override
  void initState() {
    super.initState();
    _loadAllData();
  }

  @override
  void dispose() {
    _squatMaxWeightController.dispose();
    _benchMaxWeightController.dispose();
    _deadliftMaxWeightController.dispose();
    super.dispose();
  }

  Future<void> _loadAllData() async {
    await _loadBig3Values();
    await _loadBodyWeight();
    _calculateBig3Metrics();
  }

  Future<void> _loadBig3Values() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _squatMaxWeightController.text = prefs.getString('squatMaxWeight') ?? '';
      _benchMaxWeightController.text = prefs.getString('benchMaxWeight') ?? '';
      _deadliftMaxWeightController.text = prefs.getString('deadliftMaxWeight') ?? '';
    });
  }

  Future<void> _loadBodyWeight() async {
    final prefs = await SharedPreferences.getInstance();
    final String? weightString = prefs.getString('weight');
    _bodyWeight = (weightString != null && double.tryParse(weightString) != null)
        ? double.parse(weightString)
        : 0.0;
    _calculateBig3Metrics();
  }

  Future<void> _saveMaxData() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('squatMaxWeight', _squatMaxWeightController.text);
    await prefs.setString('benchMaxWeight', _benchMaxWeightController.text);
    await prefs.setString('deadliftMaxWeight', _deadliftMaxWeightController.text);
    _calculateBig3Metrics();

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('最大重量を保存しました！')),
    );
  }

  void _calculateBig3Metrics() {
    // These values are no longer loaded from shared preferences for reps, only max weights
    final double squatMaxWeight = double.tryParse(_squatMaxWeightController.text) ?? 0.0;
    final double benchMaxWeight = double.tryParse(_benchMaxWeightController.text) ?? 0.0;
    final double deadliftMaxWeight = double.tryParse(_deadliftMaxWeightController.text) ?? 0.0;

    _squat1RM = squatMaxWeight;
    _bench1RM = benchMaxWeight;
    _deadlift1RM = deadliftMaxWeight;

    _big3Total = _squat1RM + _bench1RM + _deadlift1RM;

    if (_squat1RM > 0 && _bench1RM > 0 && _deadlift1RM > 0) {
      final double min1RM = min(_squat1RM, min(_bench1RM, _deadlift1RM));
      _big3Ratio = '${(_squat1RM / min1RM).toStringAsFixed(1)} : ${(_bench1RM / min1RM).toStringAsFixed(1)} : ${(_deadlift1RM / min1RM).toStringAsFixed(1)}';
    } else {
      _big3Ratio = 'N/A';
    }

    if (_big3Total > 0 && _bodyWeight > 0) {
      const double a = -216.04751446, b = 16.26063393, c = -0.002388645, d = -0.00113732, e = 7.01863E-06, f = -1.291E-08;
      final double bw = _bodyWeight;
      final double denominator = a + b * bw + c * pow(bw, 2) + d * pow(bw, 3) + e * pow(bw, 4) + f * pow(bw, 5);
      _wilksScore = denominator != 0 ? _big3Total * (500 / denominator) : 0.0;
    } else {
      _wilksScore = 0.0;
    }

    _glPoint = _calculateGLPoint(_big3Total, _bodyWeight);

    if (mounted) {
      setState(() {});
    }
  }

  double _calculateGLPoint(double total, double bodyWeight) {
    if (total <= 0 || bodyWeight <= 0) return 0.0;
    const double A = 1199.72839, B = 1025.18162, C = 0.00921;
    final double exponent = -C * bodyWeight;
    final double denominator = A - B * exp(exponent);
    if (denominator == 0) return 0.0;
    final double coefficient = 100 / denominator;
    return total * coefficient;
  }

  String _getWeightClass(double bodyWeight) {
    String weightClass = '--';
    if (bodyWeight > 0) {
      if (bodyWeight <= 59.0) {
        weightClass = '59kg級';
      } else if (bodyWeight <= 66.0) {
        weightClass = '66kg級';
      } else if (bodyWeight <= 74.0) {
        weightClass = '74kg級';
      } else if (bodyWeight <= 83.0) {
        weightClass = '83kg級';
      } else if (bodyWeight <= 93.0) {
        weightClass = '93kg級';
      } else if (bodyWeight <= 105.0) {
        weightClass = '105kg級';
      } else if (bodyWeight <= 120.0) {
        weightClass = '120kg級';
      } else {
        weightClass = '120kg超級';
      }
    }
    return weightClass;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('BIG3 トレーニング記録'),
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12.0),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildMaxCard(),
              const SizedBox(height: 32.0),
              _buildResults(),
              const SizedBox(height: 20.0),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMaxCard() {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('PR(MAX)の管理', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12.0),
            _buildMaxInput('スクワット', _squatMaxWeightController),
            const SizedBox(height: 12.0),
            _buildMaxInput('ベンチプレス', _benchMaxWeightController),
            const SizedBox(height: 12.0),
            _buildMaxInput('デッドリフト', _deadliftMaxWeightController),
            const SizedBox(height: 24.0),
            ElevatedButton(
              onPressed: _saveMaxData,
              child: const Text('最大重量を保存'),
            ),
            const SizedBox(height: 16.0),
            Text('BIG3 Total: ${(_big3Total).toStringAsFixed(2)} kg (${_getWeightClass(_bodyWeight)})',
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }

  Widget _buildMaxInput(String label, TextEditingController maxWeightController) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
        const SizedBox(height: 8.0),
        TextField(
          controller: maxWeightController,
          decoration: const InputDecoration(labelText: '最大重量 (1RM)', border: OutlineInputBorder()),
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}'))],
          onChanged: (value) => _calculateBig3Metrics(),
        ),
      ],
    );
  }

  Widget _buildResults() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text('各種スコア', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8.0),
        Text('ノーギアGL Point: ${(_glPoint).toStringAsFixed(2)}', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8.0),
        Text('BIG3 比率 (S:B:D): $_big3Ratio', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8.0),
        Text('Wilks Score: ${(_wilksScore).toStringAsFixed(2)}', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
      ],
    );
  }
}