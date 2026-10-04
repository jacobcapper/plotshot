import '../logic/dates.dart';

/// Per-day notes: food, side effects and free text.
class DayLog {
  final DateTime date;
  final int? calories;
  final double? proteinG;
  final List<String> sideEffects;
  final String? notes;

  /// Whether calories/protein came from Health Connect (sync may update them).
  final bool nutritionFromHealth;

  DayLog({
    required DateTime date,
    this.calories,
    this.proteinG,
    this.sideEffects = const [],
    this.notes,
    this.nutritionFromHealth = false,
  }) : date = dateOnly(date);

  bool get isEmpty =>
      calories == null &&
      proteinG == null &&
      sideEffects.isEmpty &&
      (notes == null || notes!.trim().isEmpty);

  DayLog copyWith({
    Object? calories = _keep,
    Object? proteinG = _keep,
    List<String>? sideEffects,
    Object? notes = _keep,
    bool? nutritionFromHealth,
  }) => DayLog(
    date: date,
    calories: identical(calories, _keep) ? this.calories : calories as int?,
    proteinG: identical(proteinG, _keep) ? this.proteinG : proteinG as double?,
    sideEffects: sideEffects ?? this.sideEffects,
    notes: identical(notes, _keep) ? this.notes : notes as String?,
    nutritionFromHealth: nutritionFromHealth ?? this.nutritionFromHealth,
  );

  Map<String, Object?> toMap() => {
    'date': dayKey(date),
    'calories': calories,
    'protein_g': proteinG,
    'side_effects': sideEffects.join('\n'),
    'notes': notes,
    'nutrition_from_health': nutritionFromHealth ? 1 : 0,
  };

  factory DayLog.fromMap(Map<String, Object?> m) => DayLog(
    date: parseDayKey(m['date'] as String),
    calories: (m['calories'] as num?)?.toInt(),
    proteinG: (m['protein_g'] as num?)?.toDouble(),
    sideEffects: ((m['side_effects'] as String?) ?? '')
        .split('\n')
        .where((s) => s.trim().isNotEmpty)
        .toList(),
    notes: m['notes'] as String?,
    nutritionFromHealth: (m['nutrition_from_health'] as num? ?? 0) == 1,
  );
}

const Object _keep = Object();

const commonSideEffects = [
  'Nausea',
  'Vomiting',
  'Diarrhoea',
  'Constipation',
  'Heartburn',
  'Burping',
  'Fatigue',
  'Headache',
  'Dizziness',
  'Injection site reaction',
  'Low appetite',
  'Bloating',
];
