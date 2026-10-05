import '../logic/sites.dart';

/// A medication the user injects, with the pharmacokinetic parameters used
/// to estimate how much of it is in the body over time.
class Medication {
  final int? id;
  final String name;

  /// Elimination half-life in days.
  final double halfLifeDays;

  /// Time from injection to peak level, in days.
  final double timeToPeakDays;

  /// Dose steps offered when picking a strength, in mg.
  final List<double> doses;

  final bool builtIn;

  /// Dosing interval in days. Fractional values allow e.g. every 3.5 days.
  final double daysBetweenJabs;

  /// Whether this medication is currently on a schedule (next-jab card and
  /// reminders). Inactive medications still count towards levels.
  final bool active;

  /// Injection sites in rotation order for this medication.
  final List<String> sites;

  /// Dose planned for the next jab, if changed from the last one.
  final double? nextDoseMg;

  const Medication({
    this.id,
    required this.name,
    required this.halfLifeDays,
    required this.timeToPeakDays,
    required this.doses,
    this.builtIn = false,
    this.daysBetweenJabs = 7,
    this.active = true,
    this.sites = defaultRotation,
    this.nextDoseMg,
  });

  Medication copyWith({
    int? id,
    String? name,
    double? halfLifeDays,
    double? timeToPeakDays,
    List<double>? doses,
    bool? builtIn,
    double? daysBetweenJabs,
    bool? active,
    List<String>? sites,
    Object? nextDoseMg = _keep,
  }) => Medication(
    id: id ?? this.id,
    name: name ?? this.name,
    halfLifeDays: halfLifeDays ?? this.halfLifeDays,
    timeToPeakDays: timeToPeakDays ?? this.timeToPeakDays,
    doses: doses ?? this.doses,
    builtIn: builtIn ?? this.builtIn,
    daysBetweenJabs: daysBetweenJabs ?? this.daysBetweenJabs,
    active: active ?? this.active,
    sites: sites ?? this.sites,
    nextDoseMg: identical(nextDoseMg, _keep)
        ? this.nextDoseMg
        : nextDoseMg as double?,
  );

  Map<String, Object?> toMap() => {
    if (id != null) 'id': id,
    'name': name,
    'half_life_days': halfLifeDays,
    'time_to_peak_days': timeToPeakDays,
    'doses': doses.join(','),
    'built_in': builtIn ? 1 : 0,
    'days_between_jabs': daysBetweenJabs,
    'active': active ? 1 : 0,
    'sites': sites.join('\n'),
    'next_dose_mg': nextDoseMg,
  };

  factory Medication.fromMap(Map<String, Object?> m) => Medication(
    id: m['id'] as int?,
    name: m['name'] as String,
    halfLifeDays: (m['half_life_days'] as num).toDouble(),
    timeToPeakDays: (m['time_to_peak_days'] as num).toDouble(),
    doses: parseDoses(m['doses'] as String? ?? ''),
    builtIn: (m['built_in'] as num? ?? 0) == 1,
    daysBetweenJabs: (m['days_between_jabs'] as num?)?.toDouble() ?? 7,
    active: (m['active'] as num? ?? 1) == 1,
    sites: m['sites'] == null
        ? defaultRotation
        : (m['sites'] as String)
              .split('\n')
              .where((s) => s.trim().isNotEmpty)
              .toList(),
    nextDoseMg: (m['next_dose_mg'] as num?)?.toDouble(),
  );

  static List<double> parseDoses(String s) =>
      s
          .split(',')
          .map((e) => double.tryParse(e.trim()))
          .whereType<double>()
          .where((d) => d > 0)
          .toList()
        ..sort();

  /// Starting values. Built-ins start off inactive; logging a jab activates
  /// one. Half-lives are from published prescribing information
  /// and trials; time to peak is the midpoint of the reported range.
  static const defaults = [
    Medication(
      name: 'Retatrutide',
      halfLifeDays: 6,
      timeToPeakDays: 1.5,
      doses: [0.5, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12],
      builtIn: true,
      active: false,
    ),
    Medication(
      name: 'Tirzepatide',
      halfLifeDays: 5,
      timeToPeakDays: 1,
      doses: [2.5, 5, 7.5, 10, 12.5, 15],
      builtIn: true,
      active: false,
    ),
    Medication(
      name: 'Semaglutide',
      halfLifeDays: 7,
      timeToPeakDays: 2,
      doses: [0.25, 0.5, 1, 1.7, 2, 2.4],
      builtIn: true,
      active: false,
    ),
  ];
}

const Object _keep = Object();
