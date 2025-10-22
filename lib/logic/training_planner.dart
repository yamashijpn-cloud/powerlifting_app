
import 'dart:convert';
import 'dart:math';
import 'package:powerlifting_app/models/training_record.dart';
import 'package:shared_preferences/shared_preferences.dart';

class TrainingPlanner {
  Future<String> generatePlan(String exerciseName) async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // 1. ユーザーの目標値を取得
      final goalWeight = double.tryParse(prefs.getString('goal${_getExerciseKey(exerciseName)}') ?? '0') ?? 0.0;
      final goalDateString = prefs.getString('goalDate');
      if (goalWeight <= 0 || goalDateString == null) {
        return '目標が設定されていません。\nプロフィール画面から目標重量と目標日を設定してください。';
      }

      // 2. 過去のトレーニング記録を取得
      final records = await _getRecentTrainingRecords(prefs);
      final recentLifts = records.where((rec) => rec.exerciseName == exerciseName).toList();
      if (recentLifts.isEmpty) {
        return '過去4週間の$exerciseNameのトレーニング記録がありません。\nまずはBIG3画面から記録をつけましょう。';
      }

      // 3. 現在の推定1RMを計算
      final current1RM = recentLifts.map((lift) => _calculate1RM(lift.weight, lift.reps)).reduce(max);

      // 4. サイクルの週を決定
      final cycleInfo = await _getCycleInfo(prefs, exerciseName);
      final cycleWeek = cycleInfo['week'] as int;

      // 5. 週に応じたメニューを生成
      String plan;
      switch (cycleWeek) {
        case 1: // ボリューム期
          final targetWeight = current1RM * 0.75;
          plan = _generatePlanString(exerciseName, targetWeight, 8, 5, 'ボリューム期');
          break;
        case 2: // 高強度期
          final targetWeight = current1RM * 0.85;
          plan = _generatePlanString(exerciseName, targetWeight, 5, 5, '高強度期');
          break;
        case 3: // 回復期
          final targetWeight = current1RM * 0.60;
          plan = _generatePlanString(exerciseName, targetWeight, 5, 3, '回復期(ディロード)');
          break;
        case 4: // ピーク期
          final targetWeight = current1RM * 0.95;
          plan = _generatePlanString(exerciseName, targetWeight, 2, 3, 'ピーク期(PR挑戦)');
          break;
        default:
          plan = '不明なサイクル週です。';
      }

      // 6. 次のサイクルの週を保存
      await _updateCycleInfo(prefs, exerciseName, cycleWeek);

      return plan;

    } catch (e) {
      return 'プランの生成中にエラーが発生しました: $e';
    }
  }

  String _generatePlanString(String exercise, double weight, int reps, int sets, String phase) {
      final roundedWeight = (weight / 2.5).round() * 2.5; // 2.5kg単位に丸める
      return '$phase\n$exercise: \n$roundedWeight kg × $reps reps × $sets sets';
  }

  Future<Map<String, dynamic>> _getCycleInfo(SharedPreferences prefs, String exerciseName) async {
    final key = 'cycleInfo_$exerciseName';
    final String? infoJson = prefs.getString(key);
    if (infoJson == null) {
      return {'week': 1, 'lastUpdated': DateTime.now().toIso8601String()};
    }

    final info = json.decode(infoJson);
    final lastUpdated = DateTime.parse(info['lastUpdated']);
    final now = DateTime.now();

    // 最後にプランを生成してから5日以上経過していたら、次の週に進める
    if (now.difference(lastUpdated).inDays >= 5) {
      int nextWeek = (info['week'] as int) + 1;
      if (nextWeek > 4) {
        nextWeek = 1; // 4週サイクル
      }
      return {'week': nextWeek, 'lastUpdated': now.toIso8601String()};
    }

    // 5日以内なら同じ週を提案
    return {'week': info['week'], 'lastUpdated': info['lastUpdated']};
  }

  Future<void> _updateCycleInfo(SharedPreferences prefs, String exerciseName, int currentWeek) async {
    final key = 'cycleInfo_$exerciseName';
    final info = {
      'week': currentWeek,
      'lastUpdated': DateTime.now().toIso8601String(),
    };
    await prefs.setString(key, json.encode(info));
  }

  String _getExerciseKey(String exerciseName) {
    switch (exerciseName) {
      case 'スクワット':
        return 'Squat';
      case 'ベンチプレス':
        return 'Bench';
      case 'デッドリフト':
        return 'Deadlift';
      default:
        return '';
    }
  }

  Future<List<TrainingRecord>> _getRecentTrainingRecords(SharedPreferences prefs) async {
    final String? recordsJson = prefs.getString('trainingRecords');
    if (recordsJson == null) {
      return [];
    }

    final Map<String, dynamic> decodedData = json.decode(recordsJson);
    final List<TrainingRecord> allRecords = [];
    final fourWeeksAgo = DateTime.now().subtract(const Duration(days: 28));

    decodedData.forEach((key, value) {
      final DateTime date = DateTime.parse(key);
      if (date.isAfter(fourWeeksAgo)) {
        final recordsForDay = (value as List).map((e) => TrainingRecord.fromJson(e));
        allRecords.addAll(recordsForDay);
      }
    });

    return allRecords;
  }

  // Epleyフォーミュラで1RMを計算
  double _calculate1RM(double weight, int reps) {
    if (reps == 0) return 0.0;
    if (reps == 1) return weight;
    return weight * (1 + reps / 30.0);
  }
}
