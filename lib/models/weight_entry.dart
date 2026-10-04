import '../logic/dates.dart';

/// One weight reading per calendar day.
class WeightEntry {
  final DateTime date;
  final double kg;

  /// 'manual' or 'health_connect'. Manual entries are never overwritten by sync.
  final String source;

  WeightEntry({
    required DateTime date,
    required this.kg,
    this.source = 'manual',
  }) : date = dateOnly(date);

  Map<String, Object?> toMap() => {
    'date': dayKey(date),
    'kg': kg,
    'source': source,
  };

  factory WeightEntry.fromMap(Map<String, Object?> m) => WeightEntry(
    date: parseDayKey(m['date'] as String),
    kg: (m['kg'] as num).toDouble(),
    source: m['source'] as String? ?? 'manual',
  );
}
