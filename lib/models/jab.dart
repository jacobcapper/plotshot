class Jab {
  final int? id;
  final int medicationId;
  final double doseMg;
  final DateTime takenAt;
  final String? site;
  final String? notes;

  const Jab({
    this.id,
    required this.medicationId,
    required this.doseMg,
    required this.takenAt,
    this.site,
    this.notes,
  });

  Jab copyWith({
    int? id,
    int? medicationId,
    double? doseMg,
    DateTime? takenAt,
    String? site,
    String? notes,
  }) => Jab(
    id: id ?? this.id,
    medicationId: medicationId ?? this.medicationId,
    doseMg: doseMg ?? this.doseMg,
    takenAt: takenAt ?? this.takenAt,
    site: site ?? this.site,
    notes: notes ?? this.notes,
  );

  Map<String, Object?> toMap() => {
    if (id != null) 'id': id,
    'medication_id': medicationId,
    'dose_mg': doseMg,
    'taken_at': takenAt.millisecondsSinceEpoch,
    'site': site,
    'notes': notes,
  };

  factory Jab.fromMap(Map<String, Object?> m) => Jab(
    id: m['id'] as int?,
    medicationId: m['medication_id'] as int,
    doseMg: (m['dose_mg'] as num).toDouble(),
    takenAt: DateTime.fromMillisecondsSinceEpoch(m['taken_at'] as int),
    site: m['site'] as String?,
    notes: m['notes'] as String?,
  );
}
