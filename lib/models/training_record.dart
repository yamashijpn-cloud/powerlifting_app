class TrainingRecord {
  final String exerciseName;
  final double weight;
  final int reps;
  final int sets;

  TrainingRecord({
    required this.exerciseName,
    required this.weight,
    required this.reps,
    required this.sets,
  });

  // Optionally, add methods for serialization/deserialization if saving to persistent storage
  Map<String, dynamic> toJson() => {
        'exerciseName': exerciseName,
        'weight': weight,
        'reps': reps,
        'sets': sets,
      };

  factory TrainingRecord.fromJson(Map<String, dynamic> json) => TrainingRecord(
        exerciseName: json['exerciseName'],
        weight: json['weight'],
        reps: json['reps'],
        sets: json['sets'],
      );
}
